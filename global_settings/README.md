# Global Settings

Shared across all projects — maps to `~/.claude/`.

## Contents

```
global_settings/
  CLAUDE.md              ← global agent guidelines
  claude/
    settings.json        ← global Claude Code settings
    skills/              ← global skills
      handoff/           ← /handoff
      review-insights/   ← /review-insights
      update-docs/       ← /update-docs
      update-claudes/    ← /update-claudes
  codex/
    codex_prompt.json    ← Codex agent prompt config
```

## Setup

```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
cp claude/settings.json ~/.claude/settings.json
cp -r claude/skills/* ~/.claude/skills/
```

See [root README](../README.md) for full setup instructions.
