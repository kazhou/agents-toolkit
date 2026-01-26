# agents-toolkit

Repo for various coding agents scripts, guidelines, and tools. To copy into/reuse in projects.

## Contents

- [AGENTS.md](AGENTS.md): guidelines/preferences for agents. Agent-agnostic (e.g., can be used w/ Claude Code, Cursor, etc.) with allowance for further user modification
  - for Claude Code: `cp AGENTS.md ~/.claude/CLAUDE.md` (for global) or `cp AGENTS.md ./CLAUDE.md` (for project)
  - for Cursor: `cp AGENTS.md ~/.cursor/rules/`
- [Planning Session Logger](#planning-session-logger): automatically saves planning mode transcripts and plan files

---

## Planning Session Logger

Automatically saves Claude Code session transcripts and plan files to `agent_logs/`.

### Setup

Add this line to your `~/.bashrc` or `~/.zshrc`:

```bash
source /path/to/project/.claude/hooks/claude-logging.sh
```

Then reload your shell or run `source ~/.bashrc`.

### Usage

```bash
# Start a logged session with a name
claude --log my-feature

# Short form
claude -l my-feature

# With additional claude args
claude --log my-feature --plan

# Auto-generate session name
claude --log

# Normal (unlogged) session
claude
```

### What It Does

1. Records the entire terminal session using `script` command
2. Cleans the transcript (removes ANSI codes, deduplicates lines)
3. Copies any plan files created during the session
4. Saves everything with proper naming conventions

### Naming Convention

Per AGENTS.md:
- **Plans**: `YYYY-MM-DD-<plan-name>.md`
- **Transcripts**: `YYYY-MM-DD-<plan-name>.transcript.txt`

### Directory Structure

```
agent_logs/
├── transcripts/     # Session transcripts as cleaned .txt files
├── plans/           # Plan .md files
└── LOG.md           # Session summaries (reverse chronological)
```

### Copying to New Projects

```bash
# 1. Copy hooks directory
cp -r .claude/hooks /path/to/your/project/.claude/

# 2. Create logs directory
mkdir -p /path/to/your/project/agent_logs/{transcripts,plans}
touch /path/to/your/project/agent_logs/{transcripts,plans}/.gitkeep

# 3. Update your shell config to source the logging script
echo 'source /path/to/your/project/.claude/hooks/claude-logging.sh' >> ~/.bashrc

# 4. (Optional) Update .gitignore
cat >> /path/to/your/project/.gitignore << 'EOF'

# Planning/Agent Logs (uncomment to exclude from version control)
# agent_logs/transcripts/
# agent_logs/plans/
EOF
```

### Configuration

- **CLAUDE_LOGS_DIR**: Set this env var to change the logs directory (default: `./agent_logs`)
- **Exclude from Git**: Uncomment the patterns in `.gitignore`
- **Retention**: Manually delete old logs from `agent_logs/` as needed
