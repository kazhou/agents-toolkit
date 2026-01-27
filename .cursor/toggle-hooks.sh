#!/usr/bin/env bash
#
# toggle-hooks.sh - Enable/disable Cursor hooks
#
# Usage:
#   ./toggle-hooks.sh        # Toggle current state
#   ./toggle-hooks.sh on     # Enable hooks
#   ./toggle-hooks.sh off    # Disable hooks
#   ./toggle-hooks.sh status # Show current state
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_FILE="$SCRIPT_DIR/hooks.json"
DISABLED_FILE="$SCRIPT_DIR/hooks.json.disabled"

show_status() {
    if [[ -f "$HOOKS_FILE" ]]; then
        echo "Cursor hooks: ENABLED"
        return 0
    elif [[ -f "$DISABLED_FILE" ]]; then
        echo "Cursor hooks: DISABLED"
        return 1
    else
        echo "Cursor hooks: NOT FOUND (no hooks.json)"
        return 2
    fi
}

enable_hooks() {
    if [[ -f "$HOOKS_FILE" ]]; then
        echo "Cursor hooks already enabled"
    elif [[ -f "$DISABLED_FILE" ]]; then
        mv "$DISABLED_FILE" "$HOOKS_FILE"
        echo "Cursor hooks: ENABLED"
    else
        echo "Error: No hooks configuration found"
        exit 1
    fi
}

disable_hooks() {
    if [[ -f "$DISABLED_FILE" ]]; then
        echo "Cursor hooks already disabled"
    elif [[ -f "$HOOKS_FILE" ]]; then
        mv "$HOOKS_FILE" "$DISABLED_FILE"
        echo "Cursor hooks: DISABLED"
    else
        echo "Error: No hooks configuration found"
        exit 1
    fi
}

toggle_hooks() {
    if [[ -f "$HOOKS_FILE" ]]; then
        disable_hooks
    elif [[ -f "$DISABLED_FILE" ]]; then
        enable_hooks
    else
        echo "Error: No hooks configuration found"
        exit 1
    fi
}

case "${1:-toggle}" in
    on|enable)
        enable_hooks
        ;;
    off|disable)
        disable_hooks
        ;;
    status)
        show_status
        ;;
    toggle|*)
        toggle_hooks
        ;;
esac
