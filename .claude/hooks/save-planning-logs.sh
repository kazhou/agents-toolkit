#!/usr/bin/env bash
#
# save-planning-logs.sh
# Claude Code PostToolUse hook for saving planning session data when plan mode exits.
#
# Triggered by ExitPlanMode tool use.
# Saves transcripts and plan files to agent_logs/, then commits them.
#
# Naming convention (per AGENTS.md):
#   Plans: YYYY-MM-DD-<plan-name>.md
#   Transcripts: YYYY-MM-DD-<plan-name>.transcript.txt
#

set -euo pipefail

# Configuration
AGENT_LOGS_DIR="${AGENT_LOGS_DIR:-$CLAUDE_PROJECT_DIR/agent_logs}"
TRANSCRIPTS_DIR="$AGENT_LOGS_DIR/transcripts"
PLANS_DIR="$AGENT_LOGS_DIR/plans"

# Ensure directories exist
mkdir -p "$TRANSCRIPTS_DIR" "$PLANS_DIR"

# Read JSON from stdin
INPUT=$(cat)

# Portable JSON parsing function (uses jq if available, Python fallback)
json_get() {
    local json="$1"
    local key="$2"

    if command -v jq &>/dev/null; then
        echo "$json" | jq -r ".$key // empty" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
try:
    data = json.loads('''$json''')
    # Support nested keys like 'tool_input.plan_path'
    keys = '$key'.split('.')
    val = data
    for k in keys:
        val = val.get(k, '') if isinstance(val, dict) else ''
    print(val if val else '')
except:
    print('')
"
    else
        echo ""
    fi
}

# Extract session info
SESSION_ID=$(json_get "$INPUT" "session_id")
TRANSCRIPT_PATH=$(json_get "$INPUT" "transcript_path")

# Exit if no session ID
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

DATE_PREFIX=$(date +"%Y-%m-%d")
SHORT_ID="${SESSION_ID:0:8}"

# Track saved files for git commit
SAVED_FILES=()

# Try to find plan file from hook input (tool_input or tool_response)
find_plan_from_hook_input() {
    local plan_path=""

    # Try common field names that might contain the plan path
    for field in "tool_input.plan_path" "tool_input.planPath" "tool_input.file" \
                 "tool_response.plan_path" "tool_response.planPath"; do
        plan_path=$(json_get "$INPUT" "$field")
        if [[ -n "$plan_path" && -f "$plan_path" ]]; then
            echo "$plan_path"
            return
        fi
    done
}

# Find plan file referenced in transcript (searches for .claude/plans paths)
find_plan_from_transcript() {
    local transcript="$1"

    if [[ ! -f "$transcript" ]] || ! command -v python3 &>/dev/null; then
        return
    fi

    python3 - "$transcript" "$SESSION_ID" << 'PYEOF'
import json
import sys
import re
from pathlib import Path

def find_plan_in_transcript(transcript_path, session_id):
    transcript = Path(transcript_path)
    if not transcript.exists():
        return

    plan_paths = set()

    for line in transcript.read_text(errors='replace').splitlines():
        if not line.strip():
            continue

        # Look for .claude/plans/*.md paths
        matches = re.findall(r'[^\s"\']+/\.claude/plans/[^\s"\']+\.md', line)
        plan_paths.update(matches)

        # Also check JSON content
        try:
            data = json.loads(line)
            content = str(data)
            matches = re.findall(r'[^\s"\']+/\.claude/plans/[^\s"\']+\.md', content)
            plan_paths.update(matches)
        except:
            pass

    # Return most recently modified plan that exists
    valid_plans = [(p, Path(p).stat().st_mtime) for p in plan_paths if Path(p).exists()]
    if valid_plans:
        valid_plans.sort(key=lambda x: x[1], reverse=True)
        print(valid_plans[0][0])

if len(sys.argv) >= 3:
    find_plan_in_transcript(sys.argv[1], sys.argv[2])
PYEOF
}

# Fallback: find recently modified plan files (only for this project if possible)
find_recent_plans() {
    local plans_source="${HOME}/.claude/plans"

    if [[ ! -d "$plans_source" ]]; then
        return
    fi

    # Find .md files modified in the last 30 minutes (shorter window = safer)
    find "$plans_source" -name "*.md" -mmin -30 -type f 2>/dev/null | head -1
}

# Extract plan name from plan file (first # heading or filename)
extract_plan_name() {
    local plan_file="$1"
    local plan_name=""

    # Try to extract from first markdown heading
    if [[ -f "$plan_file" ]]; then
        plan_name=$(grep -m1 '^# ' "$plan_file" 2>/dev/null | sed 's/^# //' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    fi

    # Fallback to filename without extension
    if [[ -z "$plan_name" ]]; then
        plan_name=$(basename "$plan_file" .md | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    fi

    # Final fallback to session ID
    if [[ -z "$plan_name" ]]; then
        plan_name="session-$SHORT_ID"
    fi

    echo "$plan_name"
}

# Convert JSONL transcript to clean readable text
clean_transcript() {
    local src="$1"
    local dest="$2"

    if command -v python3 &>/dev/null; then
        python3 - "$src" "$dest" << 'PYEOF'
import json
import sys
import re
from pathlib import Path

def clean_transcript(src_path, dest_path):
    src = Path(src_path)
    dest = Path(dest_path)

    if not src.exists():
        return

    lines = []
    for line in src.read_text(errors='replace').splitlines():
        if not line.strip():
            continue
        try:
            data = json.loads(line)
            # Extract message content
            if 'message' in data:
                msg = data['message']
                role = msg.get('role', '')
                content = msg.get('content', '')

                if isinstance(content, list):
                    # Handle content blocks
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

                if content:
                    prefix = "User: " if role == "user" else "Assistant: " if role == "assistant" else ""
                    lines.append(f"{prefix}{content}\n")
        except json.JSONDecodeError:
            # Keep non-JSON lines as-is
            lines.append(line + '\n')

    # Remove ANSI codes
    text = ''.join(lines)
    text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', text)

    dest.write_text(text)

if len(sys.argv) >= 3:
    clean_transcript(sys.argv[1], sys.argv[2])
PYEOF
    else
        # Fallback: just copy the file
        cp "$src" "$dest"
    fi
}

# Save transcript
save_transcript() {
    local src="$1"
    local plan_name="$2"
    local dest="$TRANSCRIPTS_DIR/${DATE_PREFIX}-${plan_name}.transcript.txt"

    if [[ -f "$src" ]]; then
        clean_transcript "$src" "$dest"
        SAVED_FILES+=("$dest")
        echo "Saved transcript: $dest"
    fi
}

# Save plan file
save_plan() {
    local src="$1"
    local plan_name="$2"
    local dest="$PLANS_DIR/${DATE_PREFIX}-${plan_name}.md"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        SAVED_FILES+=("$dest")
        echo "Saved plan: $dest"
    fi
}

# Git commit the saved files
git_commit() {
    if [[ ${#SAVED_FILES[@]} -eq 0 ]]; then
        return
    fi

    # Check if we're in a git repo
    if ! git -C "$CLAUDE_PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
        echo "Not a git repository, skipping commit"
        return
    fi

    # Stage the saved files
    for file in "${SAVED_FILES[@]}"; do
        git -C "$CLAUDE_PROJECT_DIR" add "$file" 2>/dev/null || true
    done

    # Check if there are changes to commit
    if git -C "$CLAUDE_PROJECT_DIR" diff --cached --quiet; then
        echo "No changes to commit"
        return
    fi

    # Commit with a descriptive message
    local commit_msg="chore: update planning session logs"
    git -C "$CLAUDE_PROJECT_DIR" commit -m "$commit_msg" --no-verify 2>/dev/null || true
    echo "Committed planning session logs"
}

# Main logic
main() {
    local plan_name=""
    local plan_file=""

    # Method 1: Try to get plan from hook input (most reliable)
    plan_file=$(find_plan_from_hook_input)

    # Method 2: Search transcript for plan file references
    if [[ -z "$plan_file" && -n "$TRANSCRIPT_PATH" ]]; then
        plan_file=$(find_plan_from_transcript "$TRANSCRIPT_PATH")
    fi

    # Method 3: Fallback to recently modified (least reliable)
    if [[ -z "$plan_file" ]]; then
        plan_file=$(find_recent_plans)
    fi

    # Extract plan name
    if [[ -n "$plan_file" && -f "$plan_file" ]]; then
        plan_name=$(extract_plan_name "$plan_file")
    else
        plan_name="session-$SHORT_ID"
    fi

    # Save transcript
    if [[ -n "$TRANSCRIPT_PATH" ]]; then
        save_transcript "$TRANSCRIPT_PATH" "$plan_name"
    fi

    # Save plan file
    if [[ -n "$plan_file" && -f "$plan_file" ]]; then
        save_plan "$plan_file" "$plan_name"
    fi

    # Commit the changes
    git_commit

    echo "Planning session logs saved to: $AGENT_LOGS_DIR"
}

main
