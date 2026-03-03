#!/usr/bin/env bash
#
# cc_update_global.sh - Update global Claude Code settings from toolkit
#
# Usage: cc_update_global.sh [--force]
#   --force  Skip prompts, apply all changes
#
# Syncs global_settings/ → ~/.claude/ (CLAUDE.md, settings.json, skills)
# Run from the agents-toolkit repo root or any location.
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude"
FORCE=false

[[ "${1:-}" == "--force" ]] && FORCE=true

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

echo "Updating ~/.claude/ from toolkit..."
echo ""

# 1. CLAUDE.md
sync_file "$SCRIPT_DIR/CLAUDE.md" "$TARGET/CLAUDE.md" "CLAUDE.md"

# 2. settings.json
sync_file "$SCRIPT_DIR/claude/settings.json" "$TARGET/settings.json" "settings.json"

# 3. Skills (discover dynamically)
for skill_dir in "$SCRIPT_DIR/claude/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    for skill_file in "$skill_dir"*; do
        [[ -f "$skill_file" ]] || continue
        filename="$(basename "$skill_file")"
        sync_file "$skill_file" "$TARGET/skills/$skill_name/$filename" "skills/$skill_name/$filename"
    done
done

echo ""
echo -e "${CYAN}Summary${NC}: $ADDED added, $UPDATED updated, $SKIPPED unchanged"
