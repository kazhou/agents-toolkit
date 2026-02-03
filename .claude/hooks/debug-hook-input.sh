#!/usr/bin/env bash
#
# debug-hook-input.sh - Debug what input a hook receives
#
# Logs the raw input and environment to a file for inspection
#

INPUT=$(cat)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DEBUG_FILE="${CLAUDE_PROJECT_DIR:-/data/karen/checklist_repos/agents-toolkit}/agent_logs/hook-debug-${TIMESTAMP}.json"

# Create a combined debug output with env vars and input
{
  echo "=== Environment ==="
  echo "CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR:-<not set>}"
  echo "PWD=$(pwd)"
  echo ""
  echo "=== Hook Input ==="
  echo "$INPUT" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin), indent=2))" 2>/dev/null || echo "$INPUT"
} > "$DEBUG_FILE"

echo "Hook debug saved to: $DEBUG_FILE" >&2
echo "CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR:-<not set>}" >&2
