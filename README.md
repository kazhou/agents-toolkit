# agents-toolkit

Repo for various coding agents scripts, guidelines, and tools. To copy into/reuse in projects.

## Contents

- [AGENTS.md](AGENTS.md): guidelines/preferences for agents. Agent-agnostic (e.g., can be used w/ Claude Code, Cursor, etc.) with allowance for further user modification
  - for Claude Code: `cp AGENTS.md ~/.claude/CLAUDE.md` (for global) or `cp AGENTS.md ./CLAUDE.md` (for project)
  - for Cursor: `cp AGENTS.md ~/.cursor/rules/`
- [Planning Session Logger](#planning-session-logger): automatically saves planning mode transcripts and plan files

---

## Planning Session Logger

Automatically saves Claude Code planning session transcripts and plan files to `agent_logs/` when exiting plan mode.

### Directory Structure

```
agent_logs/
├── transcripts/     # YYYY-MM-DD-<plan-name>.transcript.txt
├── plans/           # YYYY-MM-DD-<plan-name>.md
└── LOG.md           # Session summaries (reverse chronological)
```

