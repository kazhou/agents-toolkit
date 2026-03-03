#!/usr/bin/env bash
#
# save-transcript.sh - Save session transcript to agent_dev/transcripts/
#
# Triggered by SessionEnd hook
# Reads transcript path from hook stdin JSON
# Cleans JSONL transcript to readable text
# Saves to agent_dev/transcripts/YY-MM-DD_{session_id_short}.md
#
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

def get_session_id_short(hook_data):
    """Get a short session identifier."""
    session_id = hook_data.get('session_id', '')
    if session_id:
        return session_id[:8]
    return datetime.now().strftime('%H%M%S')

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
            msg = data.get('message', {})
            role = msg.get('role', '')
            content = msg.get('content', '')

            if isinstance(content, list):
                text_parts = []
                for block in content:
                    if isinstance(block, dict):
                        if block.get('type') == 'text':
                            text_parts.append(block.get('text', ''))
                        elif block.get('type') == 'tool_use':
                            text_parts.append(f"[Tool: {block.get('name', 'unknown')}]")
                    elif isinstance(block, str):
                        text_parts.append(block)
                content = '\n'.join(text_parts)

            if content and role in ('user', 'assistant'):
                prefix = 'User: ' if role == 'user' else 'Assistant: '
                lines.append(f"{prefix}{content}\n")
        except Exception:
            pass

    if not lines:
        return False

    text = ''.join(lines)
    # Remove ANSI codes and control characters
    text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', text)

    Path(dest_path).write_text(text)
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

    date_prefix = datetime.now().strftime('%y-%m-%d')
    session_short = get_session_id_short(hook_data)
    dest_path = Path(transcripts_dir) / f"{date_prefix}_{session_short}.md"

    if clean_transcript(transcript_path, dest_path):
        print(f"Saved transcript: {dest_path}")
    else:
        print("No transcript content to save")

if __name__ == '__main__':
    main()
PYEOF
