# agents-toolkit

Repo for various coding agents scripts, guidelines, and tools. To copy into/reuse in projects.

## Contents

- [AGENTS.md](AGENTS.md): guidelines/preferences for agents. Agent-agnostic (e.g., can be used w/ Claude Code, Cursor, etc.) with allowance for further user modification
  - for Claude Code: `cp AGENTS.md ~/.claude/CLAUDE.md` (for global) or `cp AGENTS.md ./CLAUDE.md` (for project)
  - for Cursor: `cp AGENTS.md ~/.cursor/rules/`
- [Planning Session Logger](#planning-session-logger): automatically saves planning mode transcripts and plan files

---

## Planning Session Logger

Automatically saves Claude Code planning session transcripts and plan files to `agent_logs/` using Claude Code's native hooks.

### How It Works

1. When you exit plan mode (`ExitPlanMode`), the hook triggers
2. The hook script finds the plan file using (in order):
   - Hook input fields (most reliable)
   - Searching the transcript for `.claude/plans/*.md` paths (session-specific)
   - Recently modified files (30 min window, fallback)
3. Extracts the plan name from the plan file's first `#` heading
4. Converts the JSONL transcript to clean readable text
5. Saves transcript as `YYYY-MM-DD-<plan-name>.transcript.txt`
6. Saves plan as `YYYY-MM-DD-<plan-name>.md`
7. Git commits the saved files
8. If you re-enter plan mode and exit again, the same files are updated and committed

### Naming Convention

Per AGENTS.md:
- **Plans**: `YYYY-MM-DD-<plan-name>.md`
- **Transcripts**: `YYYY-MM-DD-<plan-name>.transcript.txt`

### Directory Structure

```
agent_logs/
├── transcripts/     # YYYY-MM-DD-<plan-name>.transcript.txt
├── plans/           # YYYY-MM-DD-<plan-name>.md
└── LOG.md           # Session summaries (reverse chronological)
```

### Setup

The hook is configured in `.claude/settings.json`. No additional setup required for this project.

To enable in other projects:

```bash
# 1. Copy the hooks directory and settings
cp -r .claude/hooks /path/to/your/project/.claude/
cp .claude/settings.json /path/to/your/project/.claude/

# 2. Create the logs directory structure
mkdir -p /path/to/your/project/agent_logs/{transcripts,plans}
touch /path/to/your/project/agent_logs/{transcripts,plans}/.gitkeep

# 3. (Optional) Update .gitignore
cat >> /path/to/your/project/.gitignore << 'EOF'

# Planning/Agent Logs (uncomment to exclude from version control)
# agent_logs/transcripts/
# agent_logs/plans/
EOF
```

### Configuration

- **AGENT_LOGS_DIR**: Set this env var to change the logs directory (default: `$CLAUDE_PROJECT_DIR/agent_logs`)
- **Exclude from Git**: Uncomment the patterns in `.gitignore`

### Requirements

- Claude Code with hooks support
- `python3` for transcript cleaning and JSON parsing (jq used as fallback for JSON)

### Files

- `.claude/settings.json` - Hook configuration (triggers on `ExitPlanMode`)
- `.claude/hooks/save-planning-logs.sh` - Main hook script
