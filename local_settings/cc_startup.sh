#!/usr/bin/env bash
#
# cc_startup.sh - Initialize Claude Code project structure
#
# Usage: cc_startup.sh [target_dir]
#   target_dir defaults to current directory
#
# Copies local_settings/claude/ and agent_dev/ into a target project.
# Run from the agents-toolkit repo root.
#

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(dirname "$SCRIPT_DIR")"
LOCAL_SETTINGS="$SCRIPT_DIR"
TARGET="${1:-.}"

# Resolve to absolute path
TARGET="$(cd "$TARGET" && pwd)"

echo "Setting up Claude Code project in: $TARGET"

# 1. Copy .claude/ configuration (settings, hooks, skills)
echo "Copying .claude/ config..."
mkdir -p "$TARGET/.claude/hooks" "$TARGET/.claude/skills"
cp "$LOCAL_SETTINGS/claude/settings.json" "$TARGET/.claude/settings.json"
cp -r "$LOCAL_SETTINGS/claude/hooks/"* "$TARGET/.claude/hooks/" 2>/dev/null || true
chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

# 2. Copy agent_dev/ structure
echo "Copying agent_dev/ structure..."
cp -r "$LOCAL_SETTINGS/agent_dev" "$TARGET/agent_dev"

# 3. Copy CLAUDE.md
echo "Copying CLAUDE.md..."
cp "$LOCAL_SETTINGS/CLAUDE.md" "$TARGET/CLAUDE.md"

# 4. Append to .gitignore
echo "Updating .gitignore..."
GITIGNORE="$TARGET/.gitignore"
touch "$GITIGNORE"

# Ensure file ends with a newline before appending
if [[ -s "$GITIGNORE" ]] && [[ "$(tail -c 1 "$GITIGNORE")" != "" ]]; then
    echo "" >> "$GITIGNORE"
fi

# Only append if not already present
for pattern in "agent_dev/transcripts/" "agent_dev/archived/" "agent_dev/drafting/" "agent_dev/agent_docs/"; do
    if ! grep -qF "$pattern" "$GITIGNORE" 2>/dev/null; then
        echo "$pattern" >> "$GITIGNORE"
    fi
done

echo "Done! Project initialized at $TARGET"
echo ""
echo "Next steps:"
echo "  - Edit agent_dev/README.md with project vision and priorities"
echo "  - Copy global skills to ~/.claude/skills/ if not already there"
