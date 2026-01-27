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

### Features

- Plan files copied to `agent_logs/plans/YYYY-MM-DD-<heading-name>.md`
- Original plan stays in CC's default location (`~/.claude/plans/`) for re-editing
- JSONL transcripts cleaned to readable text
- Auto-commits saved files to git
- Re-entering plan mode allows editing the same plan

### Setup for New Projects

Copy the `.claude/` directory and create the agent_logs structure:

```bash
cp -r .claude/ /path/to/new-project/
mkdir -p /path/to/new-project/agent_logs/{plans,transcripts}
touch /path/to/new-project/agent_logs/{plans,transcripts}/.gitkeep
```

### Directory Structure

```
~/.claude/plans/             # CC's default location (editable originals)
    └── random-name.md

.claude/
├── settings.json            # Hook config
└── hooks/
    └── save-planning-logs.sh

agent_logs/
├── plans/           # YYYY-MM-DD-<plan-name>.md (archived copies)
├── transcripts/     # YYYY-MM-DD-<plan-name>.transcript.txt
└── LOG.md           # Session summaries (reverse chronological)
```

### How It Works

1. CC creates/edits plans in its default location (`~/.claude/plans/`)
2. When you exit plan mode (`ExitPlanMode`), the hook triggers
3. Hook **copies** plan file to `agent_logs/plans/` with dated name (using first `# Heading`)
4. Hook cleans the JSONL transcript to readable text
5. Both files are auto-committed to git
6. Re-entering plan mode finds and edits the original file
7. Exiting again updates the archived copy

