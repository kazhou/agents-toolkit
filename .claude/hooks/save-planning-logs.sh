#!/usr/bin/env bash
#
# save-planning-logs.sh - Save planning session logs when plan mode session ends
#
# Triggered by Stop hook (fires when Claude finishes responding)
# Checks permission_mode to only process plan mode sessions
# Parses transcript to find ExitPlanMode tool call with plan file path
#
# - Copies plan file from ~/.claude/plans/ to agent_logs/plans/
# - Renames to YYYY-MM-DD-claude-<heading-name>.md
# - Cleans JSONL transcript to readable text
# - Auto-commits plan file
#
# Portable: uses $CLAUDE_PROJECT_DIR for all paths
#

set -eo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Get transcript path to check for ExitPlanMode
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('transcript_path', ''))" 2>/dev/null || echo "")

# Fast filter: only process if transcript contains ExitPlanMode
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    exit 0
fi

if ! grep -q '"name":"ExitPlanMode"' "$TRANSCRIPT_PATH" 2>/dev/null; then
    exit 0
fi

# Configuration
# Use CLAUDE_PROJECT_DIR if set, otherwise fall back to cwd from input, then pwd
CWD_FROM_INPUT=$(echo "$INPUT" | python3 -c "import sys, json; d = json.load(sys.stdin); print(d.get('cwd', ''))" 2>/dev/null || echo "")
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CWD_FROM_INPUT:-$(pwd)}}"
AGENT_LOGS_DIR="${PROJECT_DIR}/agent_logs"
PLANS_DIR="$AGENT_LOGS_DIR/plans"
TRANSCRIPTS_DIR="$AGENT_LOGS_DIR/transcripts"

# Create directories if needed
mkdir -p "$PLANS_DIR" "$TRANSCRIPTS_DIR"

# Date prefix for file naming
DATE_PREFIX=$(date +"%Y-%m-%d")

# Export variables for Python
export HOOK_INPUT="$INPUT"
export HOOK_PLANS_DIR="$PLANS_DIR"
export HOOK_TRANSCRIPTS_DIR="$TRANSCRIPTS_DIR"
export HOOK_DATE_PREFIX="$DATE_PREFIX"
export HOOK_PROJECT_DIR="$PROJECT_DIR"

# Python script for all processing
python3 << 'PYEOF'
import json
import re
import sys
import os
import subprocess
import shutil
from pathlib import Path

AGENT_NAME = "claude"

def extract_plan_name(plan_content_or_path):
    """Extract plan name from first heading in content or file."""
    content = ""

    # If it's a path, read the file
    if isinstance(plan_content_or_path, str):
        path = Path(plan_content_or_path)
        if path.exists() and path.is_file():
            content = path.read_text(errors='replace')
        else:
            # It might be the content itself
            content = plan_content_or_path

    # Find first # heading
    match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    if match:
        name = match.group(1).strip()
        # Convert to kebab-case
        name = re.sub(r'[^a-zA-Z0-9\s-]', '', name)
        name = re.sub(r'\s+', '-', name.strip())
        name = name.lower()
        name = re.sub(r'-+', '-', name)
        name = name.strip('-')
        if name:
            return name

    return "plan"

def get_transcript_path(hook_data):
    """Get transcript path from hook input or fallback to timestamp search."""
    # Method 1: From hook input (session-specific)
    transcript_path = hook_data.get('transcript_path')
    if transcript_path and Path(transcript_path).exists():
        print(f"[get_transcript] From hook input: {transcript_path}")
        return transcript_path

    session_id = hook_data.get('session_id')
    if session_id:
        # Try to find transcript by session_id
        claude_dir = Path.home() / '.claude' / 'projects'
        if claude_dir.exists():
            for proj_dir in claude_dir.iterdir():
                if not proj_dir.is_dir():
                    continue
                transcript_file = proj_dir / f"{session_id}.jsonl"
                if transcript_file.exists():
                    print(f"[get_transcript] From session_id: {transcript_file}")
                    return str(transcript_file)

    # Method 2: Fallback - search by recent modification time
    print("[get_transcript] Falling back to timestamp search")
    claude_dir = Path.home() / '.claude' / 'projects'
    if not claude_dir.exists():
        return None

    import time
    recent = []
    for proj_dir in claude_dir.iterdir():
        if not proj_dir.is_dir():
            continue
        for f in proj_dir.glob('*.jsonl'):
            if time.time() - f.stat().st_mtime < 300:
                recent.append((f, f.stat().st_mtime))

    if recent:
        recent.sort(key=lambda x: x[1], reverse=True)
        return str(recent[0][0])

    return None

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

            if content and role in ('user', 'assistant'):
                prefix = 'User: ' if role == 'user' else 'Assistant: '
                lines.append(f"{prefix}{content}\n")
        except:
            pass

    text = ''.join(lines)
    # Remove ANSI codes
    text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', text)

    Path(dest_path).write_text(text)
    return True

def git_commit(project_dir, files, message):
    """Commit files to git."""
    try:
        # Check if in a git repo
        result = subprocess.run(
            ['git', 'rev-parse', '--git-dir'],
            cwd=project_dir,
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            return False

        # Add files
        subprocess.run(
            ['git', 'add'] + files,
            cwd=project_dir,
            capture_output=True
        )

        # Check if there are staged changes
        result = subprocess.run(
            ['git', 'diff', '--cached', '--quiet'],
            cwd=project_dir,
            capture_output=True
        )
        if result.returncode == 0:
            # No changes staged
            return True

        # Commit
        subprocess.run(
            ['git', 'commit', '--no-verify', '-m', message],
            cwd=project_dir,
            capture_output=True
        )
        return True
    except:
        return False

def find_plan_from_transcript(transcript_path):
    """Parse transcript to find ExitPlanMode or Write to ~/.claude/plans/."""
    if not transcript_path or not Path(transcript_path).exists():
        return None, None

    plan_content = None
    plan_file_path = None

    for line in Path(transcript_path).read_text(errors='replace').splitlines():
        if not line.strip():
            continue
        try:
            data = json.loads(line)
            msg = data.get('message', {})
            content = msg.get('content', [])

            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get('type') == 'tool_use':
                        tool_name = block.get('name', '')
                        tool_input = block.get('input', {})

                        # ExitPlanMode has the plan content directly
                        if tool_name == 'ExitPlanMode':
                            if tool_input.get('plan'):
                                plan_content = tool_input['plan']
                            # Also check for filePath in allowedPrompts (some versions)
                            prompts = tool_input.get('allowedPrompts', [])
                            # Just use content if we have it

                        # Write to ~/.claude/plans/ also works
                        if tool_name == 'Write':
                            file_path = tool_input.get('file_path', '')
                            if '/.claude/plans/' in file_path:
                                plan_file_path = file_path
                                if tool_input.get('content'):
                                    plan_content = tool_input['content']
        except:
            pass

    return plan_content, plan_file_path

def main():
    # Get variables from environment
    input_json = os.environ.get('HOOK_INPUT', '{}')
    plans_dir = os.environ.get('HOOK_PLANS_DIR', '')
    transcripts_dir = os.environ.get('HOOK_TRANSCRIPTS_DIR', '')
    date_prefix = os.environ.get('HOOK_DATE_PREFIX', '')
    project_dir = os.environ.get('HOOK_PROJECT_DIR', '')

    if not plans_dir or not transcripts_dir:
        print("Missing required environment variables", file=sys.stderr)
        sys.exit(1)

    # Parse hook input
    hook_data = {}
    try:
        hook_data = json.loads(input_json)
        print(f"[hook] session_id: {hook_data.get('session_id', 'N/A')}")
        print(f"[hook] permission_mode: {hook_data.get('permission_mode', 'N/A')}")
    except Exception as e:
        print(f"[hook] Failed to parse input: {e}")

    # Get transcript path from hook input
    transcript_path = get_transcript_path(hook_data)
    if not transcript_path:
        print("No transcript found", file=sys.stderr)
        sys.exit(0)

    # Parse transcript to find plan content
    plan_content, plan_file_path = find_plan_from_transcript(transcript_path)
    print(f"[hook] Found plan_content: {bool(plan_content)}, plan_file_path: {plan_file_path}")

    # If we have a file path but no content, read from file
    if not plan_content and plan_file_path and Path(plan_file_path).exists():
        plan_content = Path(plan_file_path).read_text(errors='replace')
        print(f"[hook] Read plan from file: {plan_file_path}")

    if not plan_content:
        print("No plan content found", file=sys.stderr)
        sys.exit(0)

    # Extract plan name from content
    plan_name = extract_plan_name(plan_content)
    print(f"[hook] Extracted plan name: {plan_name}")

    # Determine new filenames with agent name prefix
    base_name = f"{date_prefix}-{AGENT_NAME}-{plan_name}"
    new_plan_path = Path(plans_dir) / f"{base_name}.md"
    dest_transcript_path = Path(transcripts_dir) / f"{base_name}.transcript.txt"

    plan_saved = False

    # Write plan content to destination
    new_plan_path.write_text(plan_content)
    print(f"Saved plan to: {new_plan_path}")
    plan_saved = True

    # Get transcript path and clean it
    src_transcript = get_transcript_path(hook_data)
    if src_transcript and clean_transcript(src_transcript, dest_transcript_path):
        print(f"Saved transcript (local only): {dest_transcript_path}")

    # Auto-commit plan only (transcripts are gitignored)
    if plan_saved:
        if git_commit(project_dir, [str(new_plan_path)], f"chore: save plan - {AGENT_NAME}-{plan_name}"):
            print(f"Committed plan file")

if __name__ == '__main__':
    main()
PYEOF
