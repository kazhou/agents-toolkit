#!/usr/bin/env bash
#
# cc_update_local.sh - Update a project's toolkit files from local_settings
#
# Usage: cc_update_local.sh [target_dir] [--force]
#   target_dir  defaults to current directory
#   --force     Skip prompts, apply all changes
#
# Syncs settings.json, hooks, agent_dev/CLAUDE.md, draft.sh into target project.
# Run from the agents-toolkit repo root or any location.
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=false
TARGET=""

# Parse args
for arg in "$@"; do
    if [[ "$arg" == "--force" ]]; then
        FORCE=true
    elif [[ -z "$TARGET" ]]; then
        TARGET="$arg"
    fi
done

TARGET="${TARGET:-.}"
TARGET="$(cd "$TARGET" && pwd)"

# Validate target is a toolkit project
if [[ ! -d "$TARGET/.claude" ]]; then
    echo "Error: $TARGET doesn't look like a toolkit project (no .claude/ dir)."
    echo "Run cc_startup.sh first to initialize."
    exit 1
fi

# Counters
ADDED=0; UPDATED=0; SKIPPED=0

# Colors
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

sync_file() {
    local src="$1" dst="$2" label="$3"

    if [[ ! -f "$dst" ]]; then
        echo -e "${GREEN}NEW${NC}: $label"
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        ADDED=$((ADDED + 1))
    elif diff -q "$src" "$dst" &>/dev/null; then
        SKIPPED=$((SKIPPED + 1))
    else
        echo -e "${YELLOW}CHANGED${NC}: $label"
        diff --color=always "$dst" "$src" || true
        if $FORCE; then
            cp "$src" "$dst"
            UPDATED=$((UPDATED + 1))
        else
            read -rp "  Update? [y/N] " answer
            if [[ "$answer" =~ ^[Yy] ]]; then
                cp "$src" "$dst"
                UPDATED=$((UPDATED + 1))
            else
                SKIPPED=$((SKIPPED + 1))
            fi
        fi
    fi
}

echo "Updating project toolkit files in: $TARGET"
echo ""

# 1. .claude/settings.json
sync_file "$SCRIPT_DIR/claude/settings.json" "$TARGET/.claude/settings.json" ".claude/settings.json"

# 2. Hooks (discover dynamically)
for hook_file in "$SCRIPT_DIR/claude/hooks"/*; do
    [[ -f "$hook_file" ]] || continue
    filename="$(basename "$hook_file")"
    sync_file "$hook_file" "$TARGET/.claude/hooks/$filename" ".claude/hooks/$filename"
done
# Ensure hooks are executable
chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

# 3. agent_dev/CLAUDE.md
sync_file "$SCRIPT_DIR/agent_dev/CLAUDE.md" "$TARGET/agent_dev/CLAUDE.md" "agent_dev/CLAUDE.md"

# 4. agent_dev/draft.sh
sync_file "$SCRIPT_DIR/agent_dev/draft.sh" "$TARGET/agent_dev/draft.sh" "agent_dev/draft.sh"
chmod +x "$TARGET/agent_dev/draft.sh" 2>/dev/null || true

# 5. .gitignore patterns
GITIGNORE="$TARGET/.gitignore"
touch "$GITIGNORE"
GI_ADDED=0
for pattern in "agent_dev/transcripts/" "agent_dev/archived/" "agent_dev/drafting/" "agent_dev/agent_docs/"; do
    if ! grep -qF "$pattern" "$GITIGNORE" 2>/dev/null; then
        echo "$pattern" >> "$GITIGNORE"
        GI_ADDED=$((GI_ADDED + 1))
    fi
done
if [[ $GI_ADDED -gt 0 ]]; then
    echo -e "${GREEN}ADDED${NC}: $GI_ADDED .gitignore patterns"
fi

echo ""
echo -e "${CYAN}Summary${NC}: $ADDED added, $UPDATED updated, $SKIPPED unchanged"
