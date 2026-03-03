# Global Settings

Shared across all projects — e.g., lives in `~/.claude/`.

## Contents

```
global_settings/
  CLAUDE.md              ← global agent guidelines
  claude/
    settings.json        ← global Claude Code settings
    skills/              ← global skills
      handoff/           ← /handoff [active-doc]
      review-insights/   ← /review-insights
      update-docs/       ← /update-docs [path]
      update-claudes/    ← /update-claudes [path]
  codex/
    codex_prompt.json    ← Codex system prompt saved for future reference, not related to setup
```

## Codex MCP Server

See [Codex MCP Server](../README.md#codex-mcp-server) in the root README.

## Setup

```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
cp claude/settings.json ~/.claude/settings.json
cp -r claude/skills/* ~/.claude/skills/
```

See [root README](../README.md) for full setup instructions.
