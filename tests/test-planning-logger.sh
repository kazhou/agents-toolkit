#!/usr/bin/env bash
#
# Test script for save-planning-logs.sh
# Simulates the PostToolUse hook being triggered by ExitPlanMode
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Testing Planning Session Logger ==="
echo "Project dir: $PROJECT_DIR"

# Create a mock plan file in ~/.claude/plans/
MOCK_PLAN_DIR="$HOME/.claude/plans"
mkdir -p "$MOCK_PLAN_DIR"

MOCK_PLAN_FILE="$MOCK_PLAN_DIR/test-plan-$(date +%s).md"
cat > "$MOCK_PLAN_FILE" << 'EOF'
# Test Plan for Logger

## Goal
Test that the planning session logger works correctly.

## Steps
1. Create mock plan file
2. Create mock transcript
3. Run the hook script
4. Verify output files
EOF

echo "Created mock plan: $MOCK_PLAN_FILE"

# Create a mock transcript file
MOCK_TRANSCRIPT="/tmp/mock-transcript-$(date +%s).jsonl"
cat > "$MOCK_TRANSCRIPT" << EOF
{"type":"message","message":{"role":"user","content":"Please help me test the logger"}}
{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"I'll help you test the planning session logger."}]}}
{"type":"message","message":{"role":"user","content":"The plan file is at $MOCK_PLAN_FILE"}}
{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"Great, I can see the plan file reference."}]}}
EOF

echo "Created mock transcript: $MOCK_TRANSCRIPT"

# Create mock hook input JSON
MOCK_SESSION_ID="test-$(date +%s)"
MOCK_INPUT=$(cat << EOF
{
  "session_id": "$MOCK_SESSION_ID",
  "transcript_path": "$MOCK_TRANSCRIPT",
  "cwd": "$PROJECT_DIR",
  "hook_event_name": "PostToolUse",
  "tool_name": "ExitPlanMode"
}
EOF
)

echo "Mock session ID: $MOCK_SESSION_ID"
echo ""
echo "=== Running hook script ==="

# Run the hook script
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
echo "$MOCK_INPUT" | "$PROJECT_DIR/.claude/hooks/save-planning-logs.sh"

echo ""
echo "=== Checking results ==="

# Check for output files
echo "Checking transcripts directory:"
ls -la "$PROJECT_DIR/agent_logs/transcripts/" | tail -5

echo ""
echo "Checking plans directory:"
ls -la "$PROJECT_DIR/agent_logs/plans/" | tail -5

echo ""
echo "=== Git status ==="
git -C "$PROJECT_DIR" status --short

echo ""
echo "=== Git log (last 3 commits) ==="
git -C "$PROJECT_DIR" log --oneline -3

# Cleanup mock files
rm -f "$MOCK_PLAN_FILE" "$MOCK_TRANSCRIPT"
echo ""
echo "Cleaned up mock files"
echo "=== Test complete ==="
