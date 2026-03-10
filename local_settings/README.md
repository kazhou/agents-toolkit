# Local Settings

Per-project template — maps to `<project>/.claude/` and project root.

Use `cc_startup.sh` to copy into a new project.

## Contents

```
local_settings/
  CLAUDE.md              ← project-level agent guidelines template
  cc_startup.sh          ← setup script: copies config into target project
  cc_update_local.sh     ← pull toolkit updates into existing project
  claude/
    settings.json        ← project Claude Code settings + hook config
    hooks/
      save-transcript.sh ← auto-save session transcripts on session end
  agent_dev/             ← development workflow structure (see ../README.md)
```

## Setup

```bash
./cc_startup.sh /path/to/project
```

This copies `.claude/` config, `agent_dev/` structure, and `CLAUDE.md` into the target project.

## Update

Pull toolkit changes into an existing project:

```bash
./cc_update_local.sh /path/to/project                        # single project
./cc_update_local.sh /path/to/proj1 /path/to/proj2           # multiple projects
./cc_update_local.sh --force /path/to/proj1 /path/to/proj2   # skip prompts
```

Updates settings, hooks, `agent_dev/CLAUDE.md`, and `draft.sh`. Does **not** touch project-specific files (`CLAUDE.md`, `agent_dev/README.md`, `LOG.md`).

See [root README](../README.md) for full setup instructions.
