#!/usr/bin/env bash
#
# save-planning-logs.sh
# Automatically saves planning mode session logs when Claude Code sessions end.
# Triggered by the SessionEnd hook configured in .claude/settings.json
#
# Naming convention (per AGENTS.md):
#   Plans:       YYYY-MM-DD-<plan-name>.md
#   Transcripts: YYYY-MM-DD-<plan-name>.transcript.txt
#

set -euo pipefail

# Determine project root (two levels up from this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

LOGS_DIR="$PROJECT_DIR/agent_logs"
TRANSCRIPTS_DIR="$LOGS_DIR/transcripts"
PLANS_DIR="$LOGS_DIR/plans"

# Ensure output directories exist
mkdir -p "$TRANSCRIPTS_DIR" "$PLANS_DIR"

# Read session info from stdin (JSON with session_id, transcript_path, etc.)
SESSION_JSON=$(cat)

# Parse JSON - try jq first, fall back to Python
parse_json() {
    local json="$1"
    local key="$2"

    if command -v jq &>/dev/null; then
        echo "$json" | jq -r ".$key // empty"
    elif command -v python3 &>/dev/null; then
        echo "$json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('$key', ''))"
    elif command -v python &>/dev/null; then
        echo "$json" | python -c "import sys, json; data=json.load(sys.stdin); print(data.get('$key', ''))"
    else
        echo ""
    fi
}

# Convert JSONL transcript to readable text
convert_transcript_to_text() {
    local jsonl_file="$1"

    if command -v python3 &>/dev/null; then
        python3 - "$jsonl_file" << 'PYEOF'
import sys
import json

def extract_text(jsonl_path):
    with open(jsonl_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                role = entry.get('role', '')
                content = entry.get('content', '')

                # Handle different content formats
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    # Extract text from content blocks
                    texts = []
                    for block in content:
                        if isinstance(block, dict):
                            if block.get('type') == 'text':
                                texts.append(block.get('text', ''))
                            elif block.get('type') == 'tool_use':
                                texts.append(f"[Tool: {block.get('name', 'unknown')}]")
                            elif block.get('type') == 'tool_result':
                                texts.append(f"[Tool Result]")
                        elif isinstance(block, str):
                            texts.append(block)
                    text = '\n'.join(texts)
                else:
                    text = str(content) if content else ''

                if text.strip():
                    if role == 'user':
                        print(f"\n{'='*60}\nUSER:\n{'='*60}\n{text}\n")
                    elif role == 'assistant':
                        print(f"\n{'-'*60}\nASSISTANT:\n{'-'*60}\n{text}\n")
                    else:
                        print(f"\n[{role.upper()}]: {text}\n")
            except json.JSONDecodeError:
                continue

if len(sys.argv) > 1:
    extract_text(sys.argv[1])
PYEOF
    elif command -v python &>/dev/null; then
        python -c "
import sys
import json

with open('$jsonl_file', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            role = entry.get('role', '')
            content = entry.get('content', '')
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                text = ' '.join(str(b.get('text', '')) if isinstance(b, dict) else str(b) for b in content)
            else:
                text = str(content) if content else ''
            if text.strip():
                print(f'[{role.upper()}]: {text}')
        except:
            continue
"
    else
        # Fallback: just copy raw content
        cat "$jsonl_file"
    fi
}

SESSION_ID=$(parse_json "$SESSION_JSON" "session_id")
TRANSCRIPT_PATH=$(parse_json "$SESSION_JSON" "transcript_path")

# Exit if we couldn't parse session info
if [[ -z "$SESSION_ID" || -z "$TRANSCRIPT_PATH" ]]; then
    exit 0
fi

# Check if this was a planning session by examining transcript for plan mode indicators
is_planning_session() {
    local transcript="$1"

    if [[ ! -f "$transcript" ]]; then
        return 1
    fi

    # Look for plan mode indicators in the transcript
    if grep -q -E '"type":\s*"plan"|EnterPlanMode|ExitPlanMode|/plan' "$transcript" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Generate date prefix for filenames (YYYY-MM-DD format per AGENTS.md)
DATE_PREFIX=$(date +"%Y-%m-%d")

# Check if this was a planning session
if is_planning_session "$TRANSCRIPT_PATH"; then

    # Look for recently modified plan files in .claude/plans/
    CLAUDE_PLANS_DIR="$HOME/.claude/plans"
    PLAN_NAME="session"  # Default name if no plan file found

    if [[ -d "$CLAUDE_PLANS_DIR" ]]; then
        # Find the most recently modified plan file (likely from this session)
        LATEST_PLAN=$(find "$CLAUDE_PLANS_DIR" -name "*.md" -mmin -60 -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

        if [[ -n "$LATEST_PLAN" && -f "$LATEST_PLAN" ]]; then
            # Extract plan name from filename (remove .md extension)
            PLAN_NAME=$(basename "$LATEST_PLAN" .md)

            # Copy plan file with proper naming
            PLAN_DEST="$PLANS_DIR/${DATE_PREFIX}-${PLAN_NAME}.md"
            cp "$LATEST_PLAN" "$PLAN_DEST"
        fi
    fi

    # Convert and save transcript as text file
    if [[ -f "$TRANSCRIPT_PATH" ]]; then
        TRANSCRIPT_DEST="$TRANSCRIPTS_DIR/${DATE_PREFIX}-${PLAN_NAME}.transcript.txt"
        convert_transcript_to_text "$TRANSCRIPT_PATH" > "$TRANSCRIPT_DEST"
    fi
fi

exit 0
