# Local Settings

Per-project template — maps to `<project>/.claude/` and project root.

Use `cc_startup.sh` to copy into a new project.

## Contents

```
local_settings/
  CLAUDE.md              ← project-level agent guidelines template
  cc_startup.sh          ← setup script: copies config into target project
  claude/
    settings.json        ← project Claude Code settings + hook config
    hooks/
      save-transcript.sh ← auto-save session transcripts on session end
  agent_dev/             ← development workflow structure (see agent_dev/README.md)
  notebooks/
    CLAUDE.md            ← notebook-specific agent guidelines
  tests/
    CLAUDE.md            ← test-specific agent guidelines
```

## Setup

```bash
./cc_startup.sh /path/to/project
```

This copies `.claude/` config, `agent_dev/` structure, and `CLAUDE.md` into the target project.

See [root README](../README.md) for full setup instructions.
