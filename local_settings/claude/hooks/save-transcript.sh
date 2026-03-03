#!/usr/bin/env bash
#
# save-transcript.sh - Save session transcript as cleaned text
#
# Triggered by SessionEnd hook
# Reads transcript path from hook stdin JSON
# Converts JSONL transcript to readable text with tool call annotations
# Saves to agent_dev/transcripts/YY-MM-DD_{name}.txt
#
# Naming: plan slug from Write tool calls to .claude/plans/, else session_id[:8]
# Portable: uses $CLAUDE_PROJECT_DIR for all paths
#

set -eo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Get transcript path
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('transcript_path', ''))" 2>/dev/null || echo "")

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    exit 0
fi

# Configuration
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TRANSCRIPTS_DIR="${PROJECT_DIR}/agent_dev/transcripts"
mkdir -p "$TRANSCRIPTS_DIR"

# Export for Python
export HOOK_TRANSCRIPT_PATH="$TRANSCRIPT_PATH"
export HOOK_TRANSCRIPTS_DIR="$TRANSCRIPTS_DIR"
export HOOK_INPUT="$INPUT"

python3 << 'PYEOF'
import json
import re
import os
import sys
from pathlib import Path
from datetime import datetime

# Patterns for cleaning
ANSI_RE = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]')
CTRL_RE = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')

# Pattern for extracting plan slug from .claude/plans/ paths
PLAN_PATH_RE = re.compile(r'\.claude/plans/([^/]+?)(?:\.\w+)?$')


def clean_string(s):
    """Strip ANSI escape codes and control characters from a string."""
    s = ANSI_RE.sub('', s)
    s = CTRL_RE.sub('', s)
    return s


def extract_plan_slug(lines):
    """Find a Write tool call targeting .claude/plans/ and extract the slug."""
    for line in lines:
        try:
            data = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue
        msg = data.get('message', {})
        content = msg.get('content', [])
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get('type') != 'tool_use' or block.get('name') != 'Write':
                continue
            file_path = block.get('input', {}).get('file_path', '')
            m = PLAN_PATH_RE.search(file_path)
            if m:
                return m.group(1)
    return None


def get_name(raw_lines, hook_data):
    """Determine transcript name: plan slug or session_id[:8]."""
    slug = extract_plan_slug(raw_lines)
    if slug:
        return slug
    session_id = hook_data.get('session_id', '')
    if session_id:
        return session_id[:8]
    return datetime.now().strftime('%H%M%S')


def format_tool_use(block):
    """Format a tool_use block as a readable annotation."""
    name = block.get('name', 'unknown')
    inp = block.get('input', {})
    # Show key details depending on tool type
    if name in ('Read', 'Write', 'Edit', 'Glob', 'Grep'):
        path = inp.get('file_path', inp.get('path', inp.get('pattern', '')))
        return f"[Tool: {name} → {path}]" if path else f"[Tool: {name}]"
    if name == 'Bash':
        cmd = inp.get('command', '')
        if len(cmd) > 120:
            cmd = cmd[:120] + '...'
        return f"[Tool: {name} → {cmd}]"
    if name == 'Agent':
        desc = inp.get('description', '')
        return f"[Tool: {name} → {desc}]" if desc else f"[Tool: {name}]"
    return f"[Tool: {name}]"


def format_tool_result(block):
    """Format a tool_result block as a readable annotation."""
    content = block.get('content', '')
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get('type') == 'text':
                parts.append(item.get('text', ''))
        content = '\n'.join(parts)
    if isinstance(content, str):
        content = clean_string(content)
        if len(content) > 300:
            content = content[:300] + '...'
        return f"[Result: {content}]"
    return '[Result]'


def clean_transcript(src_path, dest_path):
    """Convert JSONL transcript to readable text."""
    src = Path(src_path)
    if not src.exists():
        return False

    lines = []
    for line in src.read_text(errors='replace').splitlines():
        if not line.strip():
            continue
        try:
            data = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue

        msg = data.get('message', {})
        role = msg.get('role', '')
        content = msg.get('content', '')

        if isinstance(content, list):
            text_parts = []
            for block in content:
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'text':
                        text_parts.append(block.get('text', ''))
                    elif btype == 'tool_use':
                        text_parts.append(format_tool_use(block))
                    elif btype == 'tool_result':
                        text_parts.append(format_tool_result(block))
                elif isinstance(block, str):
                    text_parts.append(block)
            content = '\n'.join(text_parts)

        if content and role in ('user', 'assistant'):
            content = clean_string(content)
            prefix = 'User: ' if role == 'user' else 'Assistant: '
            lines.append(f"{prefix}{content}\n")

    if not lines:
        return False

    Path(dest_path).write_text(''.join(lines))
    return True


def main():
    transcript_path = os.environ.get('HOOK_TRANSCRIPT_PATH', '')
    transcripts_dir = os.environ.get('HOOK_TRANSCRIPTS_DIR', '')
    input_json = os.environ.get('HOOK_INPUT', '{}')

    if not transcript_path or not transcripts_dir:
        sys.exit(0)

    hook_data = {}
    try:
        hook_data = json.loads(input_json)
    except Exception:
        pass

    raw_lines = Path(transcript_path).read_text(errors='replace').splitlines()

    date_prefix = datetime.now().strftime('%y-%m-%d')
    name = get_name(raw_lines, hook_data)
    dest_path = Path(transcripts_dir) / f"{date_prefix}_{name}.txt"

    if clean_transcript(transcript_path, dest_path):
        print(f"Saved transcript: {dest_path}")
    else:
        print("No transcript content to save")


if __name__ == '__main__':
    main()
PYEOF
