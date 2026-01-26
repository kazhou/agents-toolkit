# agents-toolkit

Repo for various coding agents scripts, guidelines, and tools. To copy into/reuse in projects.

## Contents

- [AGENTS.md](AGENTS.md): guidelines/preferences for agents. Agent-agnostic (e.g., can be used w/ Claude Code, Cursor, etc.) with allowance for further user modification
  - e.g., for Claude Code: `cp AGENTS.md ~/.claude/CLAUDE.md` (for global) or `cp AGENTS.md ./CLAUDE.md` (for project)
- [Planning Session Logger](#planning-session-logger): automatically saves planning mode transcripts and plan files

---

## Planning Session Logger

Automatically saves Claude Code planning session logs (full transcripts + plan files) to `agent_logs/` when sessions end.

### How It Works

Uses Claude Code's native `SessionEnd` hook to:
1. Detect if the session involved planning mode (by checking transcript for plan mode indicators)
2. Convert and save the session transcript to `agent_logs/transcripts/` as readable text
3. Copy any recently modified plan files to `agent_logs/plans/`

### Naming Convention

Per AGENTS.md:
- **Plans**: `YYYY-MM-DD-<plan-name>.md`
- **Transcripts**: `YYYY-MM-DD-<plan-name>.transcript.txt`

### Directory Structure

```
agent_logs/
├── transcripts/     # Session transcripts as readable .txt files
├── plans/           # Plan .md files (e.g., 2026-01-26-planning-session-logger.md)
└── LOG.md           # Session summaries (reverse chronological)
```

### Copying to New Projects

To add the planning session logger to another project:

```bash
# 1. Copy hook script and settings
cp -r .claude/hooks /path/to/your/project/.claude/
cp .claude/settings.json /path/to/your/project/.claude/

# 2. Create logs directory
mkdir -p /path/to/your/project/agent_logs/{transcripts,plans}
touch /path/to/your/project/agent_logs/{transcripts,plans}/.gitkeep

# 3. Make script executable
chmod +x /path/to/your/project/.claude/hooks/save-planning-logs.sh

# 4. (Optional) Update .gitignore to exclude logs
cat >> /path/to/your/project/.gitignore << 'EOF'

# Planning/Agent Logs (uncomment to exclude from version control)
# agent_logs/transcripts/
# agent_logs/plans/
EOF
```

### Configuration

- **Enable/Disable**: Remove or comment out the hook in `.claude/settings.json`
- **Exclude from Git**: Uncomment the patterns in `.gitignore`
- **Retention**: Manually delete old logs from `agent_logs/` as needed
  