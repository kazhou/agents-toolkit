# Global Settings

Shared across all projects — e.g., lives in `~/.claude/`.

## Contents

```
global_settings/
  CLAUDE.md              ← global agent guidelines
  cc_update_global.sh    ← pull toolkit updates into ~/.claude/
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

## Update

Pull toolkit changes into `~/.claude/` without manual copying:

```bash
./cc_update_global.sh          # interactive — shows diffs, prompts before overwriting
./cc_update_global.sh --force  # apply all changes without prompting
```

See [root README](../README.md) for full setup instructions.
