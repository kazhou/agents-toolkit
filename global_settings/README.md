# Global Settings

Shared across all projects — e.g., lives in `~/.claude/`.

## Contents

```
global_settings/
  CLAUDE.md              ← global agent guidelines
  claude/
    settings.json        ← global Claude Code settings
    skills/              ← global skills
      draft/             ← /draft [name]
      handoff/           ← /handoff [active-doc]
      review-insights/   ← /review-insights
      update-docs/       ← /update-docs [path]
      update-claudes/    ← /update-claudes [path]
  codex/
    codex_prompt.json    ← Codex system prompt saved for future reference, not related to setup
```

## Codex MCP Server

The global settings include a [Codex CLI](https://developers.openai.com/codex/cli/) MCP server, letting Claude Code call Codex for co-brainstorming, co-planning, or independent code review.

- **Transport:** stdio (spawns `codex mcp-server` as a subprocess)
- **Sandbox:** read-only (`disk-full-read-access`) — Codex can read files but not edit or run commands
- **Requires:** `codex` CLI installed (`npm i -g @openai/codex`) and authenticated (`codex login`)

To register manually without copying settings.json:
```bash
claude mcp add -s user codex -- codex mcp-server -c 'sandbox_permissions=["disk-full-read-access"]'
```

### Usage

Once registered, ask Claude Code to use Codex in natural language. Examples:

- `ask codex to review my implementation plan`
- `use codex to brainstorm approaches for [feature]`
- `have codex review the changes in this branch`
- `ask codex what it thinks about the architecture in src/`

Claude Code will call Codex via the MCP tool, passing your prompt and repo context. Codex runs in read-only mode so it can analyze code but won't make edits.

## Setup

```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
cp claude/settings.json ~/.claude/settings.json
cp -r claude/skills/* ~/.claude/skills/
```

See [root README](../README.md) for full setup instructions.
