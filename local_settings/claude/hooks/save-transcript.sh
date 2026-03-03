#!/usr/bin/env bash
#
# save-transcript.sh - Save session transcript as cleaned JSONL
#
# Triggered by SessionEnd hook
# Reads transcript path from hook stdin JSON
# Cleans JSONL: strips ANSI/control chars from all string values
# Saves to agent_dev/transcripts/YY-MM-DD_{name}.jsonl
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

# Patterns for cleaning string values
ANSI_RE = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]')
CTRL_RE = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')

# Pattern for extracting plan slug from .claude/plans/ paths
PLAN_PATH_RE = re.compile(r'\.claude/plans/([^/]+?)(?:\.\w+)?$')


def clean_string(s):
    """Strip ANSI escape codes and control characters from a string."""
    s = ANSI_RE.sub('', s)
    s = CTRL_RE.sub('', s)
    return s


def clean_value(obj):
    """Recursively clean all string values in a JSON-compatible structure."""
    if isinstance(obj, str):
        return clean_string(obj)
    if isinstance(obj, list):
        return [clean_value(item) for item in obj]
    if isinstance(obj, dict):
        return {k: clean_value(v) for k, v in obj.items()}
    return obj


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


def clean_transcript(src_path, dest_path):
    """Read JSONL, clean all string values, write cleaned JSONL."""
    src = Path(src_path)
    if not src.exists():
        return False

    raw_lines = src.read_text(errors='replace').splitlines()
    cleaned = []
    for line in raw_lines:
        stripped = line.strip()
        if not stripped:
            continue
        try:
            data = json.loads(stripped)
        except (json.JSONDecodeError, ValueError):
            continue
        cleaned_data = clean_value(data)
        cleaned.append(json.dumps(cleaned_data, ensure_ascii=False))

    if not cleaned:
        return False

    Path(dest_path).write_text('\n'.join(cleaned) + '\n')
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

    # Read raw lines for plan slug extraction before cleaning
    raw_lines = Path(transcript_path).read_text(errors='replace').splitlines()

    date_prefix = datetime.now().strftime('%y-%m-%d')
    name = get_name(raw_lines, hook_data)
    dest_path = Path(transcripts_dir) / f"{date_prefix}_{name}.jsonl"

    if clean_transcript(transcript_path, dest_path):
        print(f"Saved transcript: {dest_path}")
    else:
        print("No transcript content to save")


if __name__ == '__main__':
    main()
PYEOF
