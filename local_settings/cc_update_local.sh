#!/usr/bin/env bash
#
# cc_update_local.sh - Update project toolkit files from local_settings
#
# Usage: cc_update_local.sh [--force] [target_dir ...]
#   target_dir  defaults to current directory (accepts multiple)
#   --force     Skip prompts, apply all changes
#
# Syncs settings.json, hooks, agent_dev/CLAUDE.md, draft.sh into target project(s).
# Run from the agents-toolkit repo root or any location.
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=false
TARGETS=()

# Parse args
for arg in "$@"; do
    if [[ "$arg" == "--force" ]]; then
        FORCE=true
    else
        TARGETS+=("$arg")
    fi
done

# Default to current directory if no targets given
if [[ ${#TARGETS[@]} -eq 0 ]]; then
    TARGETS=(".")
fi

# Colors
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

sync_file() {
    local src="$1" dst="$2" label="$3"

    if [[ ! -f "$dst" ]]; then
        echo -e "  ${GREEN}NEW${NC}: $label"
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        ADDED=$((ADDED + 1))
    elif diff -q "$src" "$dst" &>/dev/null; then
        SKIPPED=$((SKIPPED + 1))
    else
        echo -e "  ${YELLOW}CHANGED${NC}: $label"
        diff --color=always "$dst" "$src" || true
        if $FORCE; then
            cp "$src" "$dst"
            UPDATED=$((UPDATED + 1))
        else
            read -rp "    Update? [y/N] " answer
            if [[ "$answer" =~ ^[Yy] ]]; then
                cp "$src" "$dst"
                UPDATED=$((UPDATED + 1))
            else
                SKIPPED=$((SKIPPED + 1))
            fi
        fi
    fi
}

update_project() {
    local target="$1"
    target="$(cd "$target" && pwd)"

    # Validate target is a toolkit project
    if [[ ! -d "$target/.claude" ]]; then
        echo -e "${RED}SKIP${NC}: $target (no .claude/ dir — run cc_startup.sh first)"
        return 1
    fi

    echo -e "${CYAN}Updating${NC}: $target"

    # Counters (per project)
    ADDED=0; UPDATED=0; SKIPPED=0

    # 1. .claude/settings.json
    sync_file "$SCRIPT_DIR/claude/settings.json" "$target/.claude/settings.json" ".claude/settings.json"

    # 2. Hooks (discover dynamically)
    for hook_file in "$SCRIPT_DIR/claude/hooks"/*; do
        [[ -f "$hook_file" ]] || continue
        filename="$(basename "$hook_file")"
        sync_file "$hook_file" "$target/.claude/hooks/$filename" ".claude/hooks/$filename"
    done
    chmod +x "$target/.claude/hooks/"*.sh 2>/dev/null || true

    # 3. agent_dev/CLAUDE.md
    sync_file "$SCRIPT_DIR/agent_dev/CLAUDE.md" "$target/agent_dev/CLAUDE.md" "agent_dev/CLAUDE.md"

    # 4. agent_dev/draft.sh
    sync_file "$SCRIPT_DIR/agent_dev/draft.sh" "$target/agent_dev/draft.sh" "agent_dev/draft.sh"
    chmod +x "$target/agent_dev/draft.sh" 2>/dev/null || true

    # 5. .gitignore patterns
    local gitignore="$target/.gitignore"
    touch "$gitignore"
    local gi_added=0
    for pattern in "agent_dev/transcripts/" "agent_dev/archived/" "agent_dev/drafting/" "agent_dev/agent_docs/"; do
        if ! grep -qF "$pattern" "$gitignore" 2>/dev/null; then
            echo "$pattern" >> "$gitignore"
            gi_added=$((gi_added + 1))
        fi
    done
    if [[ $gi_added -gt 0 ]]; then
        echo -e "  ${GREEN}ADDED${NC}: $gi_added .gitignore patterns"
    fi

    echo -e "  ${CYAN}Summary${NC}: $ADDED added, $UPDATED updated, $SKIPPED unchanged"
    echo ""
}

for target in "${TARGETS[@]}"; do
    update_project "$target"
done
