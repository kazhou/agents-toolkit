#!/usr/bin/env bash
#
# save-planning-logs.sh - Save planning session logs when plan mode exits
#
# Triggered by PostToolUse hook on ExitPlanMode
# - Renames plan file from random name to YYYY-MM-DD-<heading-name>.md
# - Cleans JSONL transcript to readable text
# - Auto-commits both files
#
# Portable: uses $CLAUDE_PROJECT_DIR for all paths
#

set -eo pipefail

# Configuration
# Use CLAUDE_PROJECT_DIR if set, otherwise fall back to current working directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AGENT_LOGS_DIR="${PROJECT_DIR}/agent_logs"
PLANS_DIR="$AGENT_LOGS_DIR/plans"
TRANSCRIPTS_DIR="$AGENT_LOGS_DIR/transcripts"

# Create directories if needed
mkdir -p "$PLANS_DIR" "$TRANSCRIPTS_DIR"

# Read hook input from stdin
INPUT=$(cat)

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

def extract_plan_name(plan_path):
    """Extract plan name from first heading or filename."""
    if not plan_path or not Path(plan_path).exists():
        return None

    content = Path(plan_path).read_text(errors='replace')

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

    # Fallback to filename (without .md)
    return Path(plan_path).stem

def find_plan_from_transcript(transcript_path):
    """Parse transcript to find plan file that was written in this session."""
    if not transcript_path or not Path(transcript_path).exists():
        return None

    plans_dir = Path.home() / '.claude' / 'plans'
    plan_files = []

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

                        # Look for Write/Edit to ~/.claude/plans/
                        if tool_name in ('Write', 'Edit'):
                            file_path = tool_input.get('file_path', '')
                            if file_path and str(plans_dir) in file_path and file_path.endswith('.md'):
                                plan_files.append(file_path)
        except:
            pass

    if plan_files:
        # Return the last plan file written (most recent in transcript)
        return plan_files[-1]
    return None

def find_plan_file(plans_dir, tool_input, transcript_path=None):
    """Find the plan file that was just written."""
    plans_dir = Path(plans_dir)

    # Method 1: From tool input (preferred - session-specific)
    if tool_input:
        for key in ['plan_path', 'planPath', 'file_path', 'filePath', 'file']:
            if key in tool_input:
                path = tool_input[key]
                if path and Path(path).exists():
                    print(f"[find_plan_file] Method 1 (tool_input): Found plan from '{key}': {path}")
                    return path
        print(f"[find_plan_file] Method 1: No valid path in tool_input. Keys: {list(tool_input.keys())}")

    # Method 2: Parse transcript for Write/Edit to ~/.claude/plans/ (session-specific)
    if transcript_path:
        plan_from_transcript = find_plan_from_transcript(transcript_path)
        if plan_from_transcript and Path(plan_from_transcript).exists():
            print(f"[find_plan_file] Method 2 (transcript): Found plan: {plan_from_transcript}")
            return plan_from_transcript
        print(f"[find_plan_file] Method 2: No plan file found in transcript")

    # Method 3: Fallback - search by recent modification time (NOT concurrent-safe)
    import time
    cc_plans_dir = Path.home() / '.claude' / 'plans'
    search_dirs = [cc_plans_dir, plans_dir]

    recent_plans = []
    for search_dir in search_dirs:
        if not search_dir.exists():
            continue
        for p in search_dir.glob('*.md'):
            # Skip already-dated files (YYYY-MM-DD pattern)
            if re.match(r'^\d{4}-\d{2}-\d{2}', p.name):
                continue
            # Skip .gitkeep
            if p.name == '.gitkeep':
                continue
            # Check if modified in last 5 minutes
            if time.time() - p.stat().st_mtime < 300:
                recent_plans.append((p, p.stat().st_mtime))

    if recent_plans:
        recent_plans.sort(key=lambda x: x[1], reverse=True)
        selected = str(recent_plans[0][0])
        print(f"[find_plan_file] Method 3 (timestamp): Found {len(recent_plans)} recent plan(s), selected: {selected}")
        return selected

    print("[find_plan_file] Method 3: No recent plans found")
    return None

def get_transcript_path(hook_data):
    """Get transcript path from hook input (preferred) or fallback to timestamp search."""
    # Method 1: From hook input (session-specific)
    transcript_path = hook_data.get('transcript_path')
    if transcript_path and Path(transcript_path).exists():
        print(f"[get_transcript] From hook input: {transcript_path}")
        return transcript_path

    # Method 2: Fallback - search by recent modification time (NOT concurrent-safe)
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
    tool_input = {}
    try:
        hook_data = json.loads(input_json)
        tool_input = hook_data.get('tool_input', {})
        print(f"[hook] session_id: {hook_data.get('session_id', 'N/A')}")
        print(f"[hook] transcript_path: {hook_data.get('transcript_path', 'N/A')}")
        print(f"[hook] tool_input keys: {list(tool_input.keys())}")
    except Exception as e:
        print(f"[hook] Failed to parse input: {e}")

    # Get transcript path from hook input (session-specific)
    src_transcript = get_transcript_path(hook_data)

    # Find plan file (using transcript to find Write operations)
    plan_file = find_plan_file(plans_dir, tool_input, src_transcript)
    if not plan_file:
        print("No plan file found", file=sys.stderr)
        sys.exit(0)  # Exit gracefully - maybe plan mode was cancelled

    # Extract plan name
    plan_name = extract_plan_name(plan_file)
    if not plan_name:
        plan_name = Path(plan_file).stem

    # Determine new filenames with agent name prefix
    base_name = f"{date_prefix}-{AGENT_NAME}-{plan_name}"
    new_plan_path = Path(plans_dir) / f"{base_name}.md"
    dest_transcript_path = Path(transcripts_dir) / f"{base_name}.transcript.txt"

    plan_saved = False

    # Copy plan file (keep original for CC to edit on re-entry)
    if plan_file != str(new_plan_path):
        shutil.copy2(plan_file, new_plan_path)
        print(f"Copied plan to: {new_plan_path}")
        plan_saved = True

    # Clean and save transcript (saved locally, not committed)
    if src_transcript and clean_transcript(src_transcript, dest_transcript_path):
        print(f"Saved transcript (local only): {dest_transcript_path}")

    # Auto-commit plan only (transcripts are gitignored)
    if plan_saved:
        if git_commit(project_dir, [str(new_plan_path)], f"chore: save plan - {AGENT_NAME}-{plan_name}"):
            print(f"Committed plan file")

if __name__ == '__main__':
    main()
PYEOF
