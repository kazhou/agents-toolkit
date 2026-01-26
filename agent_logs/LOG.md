# Session Log

## 2026-01-26: Planning Session Logger Implementation

**Summary**: Implemented a session logging system using a shell function wrapper with `--log` flag.

**Files Created**:
- `.claude/hooks/claude-logging.sh` - Shell functions to source in bashrc/zshrc
- `agent_logs/transcripts/.gitkeep` - Directory for session transcripts
- `agent_logs/plans/.gitkeep` - Directory for plan files

**Files Modified**:
- `.gitignore` - Added optional exclusion patterns for agent_logs/
- `README.md` - Added setup and usage documentation

**Key Implementation Details**:
- Shell function wraps `claude` command, intercepts `--log`/`-l` flag
- Uses `script` command to record terminal sessions in real-time
- Transcript cleaning: Removes ANSI escape codes, control characters, deduplicates repeated lines
- Naming convention per AGENTS.md: `YYYY-MM-DD-<plan-name>.transcript.txt`
- Cross-platform compatible (Linux and macOS)
- Configurable via `CLAUDE_LOGS_DIR` env var
