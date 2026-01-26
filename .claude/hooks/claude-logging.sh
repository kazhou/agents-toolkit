#!/usr/bin/env bash
#
# claude-logging.sh
# Shell configuration for Claude Code session logging.
# Source this file in your ~/.bashrc or ~/.zshrc:
#
#   source /path/to/project/.claude/hooks/claude-logging.sh
#
# Then use:
#   claude --log [session-name] [other-args...]   # Start logged session
#   claude -l [session-name] [other-args...]      # Short form
#   claude [args...]                              # Normal (unlogged) session
#

# Configure these paths as needed
CLAUDE_LOGS_DIR="${CLAUDE_LOGS_DIR:-./agent_logs}"

claude() {
    local log_session=false
    local session_name=""
    local claude_args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --log|-l)
                log_session=true
                shift
                # Next arg might be session name (if not a flag)
                if [[ $# -gt 0 && "$1" != -* ]]; then
                    session_name="$1"
                    shift
                fi
                ;;
            *)
                claude_args+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$log_session" == true ]]; then
        _claude_logged_session "$session_name" "${claude_args[@]}"
    else
        command claude "${claude_args[@]}"
    fi
}

_claude_logged_session() {
    local session_name="$1"
    shift
    local claude_args=("$@")

    local logs_dir="$CLAUDE_LOGS_DIR"
    local transcripts_dir="$logs_dir/transcripts"
    local plans_dir="$logs_dir/plans"

    # Ensure directories exist
    mkdir -p "$transcripts_dir" "$plans_dir"

    # Generate session name if not provided
    if [[ -z "$session_name" ]]; then
        session_name="session-$(date +%H%M%S)"
    fi

    # Generate filenames with date prefix
    local date_prefix
    date_prefix=$(date +"%Y-%m-%d")
    local transcript_file="$transcripts_dir/${date_prefix}-${session_name}.transcript.txt"

    echo "Starting Claude Code session: $session_name"
    echo "Transcript: $transcript_file"
    echo ""

    # Set NO_COLOR for cleaner output
    export NO_COLOR=1

    # Use script to record the terminal session
    if [[ "$(uname)" == "Linux" ]]; then
        script -q "$transcript_file" -c "command claude ${claude_args[*]}"
    else
        # macOS syntax
        script -q "$transcript_file" command claude "${claude_args[@]}"
    fi

    echo ""
    echo "Session ended. Cleaning transcript..."

    # Clean the transcript
    _claude_clean_transcript "$transcript_file"
    echo "Transcript saved: $transcript_file"

    # Copy any plan files created during the session
    _claude_copy_plans "$plans_dir" "$date_prefix" "$session_name"

    echo "Done!"
}

_claude_clean_transcript() {
    local transcript_path="$1"

    [[ ! -f "$transcript_path" ]] && return

    if command -v python3 &>/dev/null; then
        python3 - "$transcript_path" << 'PYEOF'
import sys
import re
from pathlib import Path

def clean_transcript(filepath):
    path = Path(filepath)
    if not path.exists():
        return

    content = path.read_text(errors='replace')

    # Remove ANSI escape codes (colors, cursor movement, etc.)
    ansi_pattern = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]|\x1b\].*?\x07|\x1b[PX^_].*?\x1b\\')
    content = ansi_pattern.sub('', content)

    # Remove other control characters except newlines and tabs
    content = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', content)

    # Deduplicate repeated neighboring lines
    lines = content.split('\n')
    deduped = []
    prev_line = None
    for line in lines:
        stripped = line.rstrip()
        if stripped != prev_line:
            deduped.append(line)
            prev_line = stripped

    path.write_text('\n'.join(deduped))

if len(sys.argv) > 1:
    clean_transcript(sys.argv[1])
PYEOF
    fi
}

_claude_copy_plans() {
    local plans_dir="$1"
    local date_prefix="$2"
    local session_name="$3"
    local claude_plans_dir="$HOME/.claude/plans"

    [[ ! -d "$claude_plans_dir" ]] && return

    # Find plan files modified in last 60 minutes
    while IFS= read -r -d '' plan_file; do
        if [[ -f "$plan_file" ]]; then
            local plan_basename
            plan_basename=$(basename "$plan_file" .md)
            local dest="$plans_dir/${date_prefix}-${session_name}-${plan_basename}.md"
            cp "$plan_file" "$dest"
            echo "Plan saved: $dest"
        fi
    done < <(find "$claude_plans_dir" -name "*.md" -mmin -60 -print0 2>/dev/null)
}
