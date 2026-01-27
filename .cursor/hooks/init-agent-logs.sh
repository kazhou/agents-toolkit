#!/usr/bin/env bash
#
# init-agent-logs.sh - Create agent_logs directories at session start
#
# Portable: uses $CURSOR_PROJECT_DIR for paths
#

set -euo pipefail

PROJECT_DIR="${CURSOR_PROJECT_DIR:-$(pwd)}"
AGENT_LOGS_DIR="${PROJECT_DIR}/agent_logs"

mkdir -p "$AGENT_LOGS_DIR/plans" "$AGENT_LOGS_DIR/transcripts"
