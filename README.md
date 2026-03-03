# agents-toolkit

Toolkit for coding agent workflows — scripts, guidelines, skills, and hooks. Copy into or reuse across projects.

Work in progress!

## Contents

```
global_settings/         ← shared across all projects
  CLAUDE.md              ← global agent guidelines
  cc_update_global.sh    ← pull toolkit updates into ~/.claude/
  claude/                ← copy into ~/.claude/
    settings.json        ← global Claude Code settings
    skills/              ← global skills (/handoff, /review-insights, /update-docs, /update-claudes)
  codex/
    codex_prompt.json    ← Codex agent prompt config

local_settings/          ← per-project template
  CLAUDE.md              ← project-level agent guidelines
  cc_startup.sh          ← setup script for new projects
  cc_update_local.sh     ← pull toolkit updates into existing projects
  claude/                ← copy into proj/.claude/
    settings.json        ← project settings + hooks
    hooks/
      save-transcript.sh ← auto-save session transcripts
  agent_dev/             ← development workflow structure (see below)
  notebooks/             ← notebook-specific agent guidelines
  tests/                 ← test-specific agent guidelines
```

---

## Workflow

- **Brainstorm** — the WHAT and WHY. No code beyond discussion of frameworks/architectures, trade-offs, and final decisions. Start in `drafting/` (create docs with `agent_dev/draft.sh [name]`), user and CC whiteboard together. When something solidifies, CC appends a dated note to `agent_dev/README.md # Insights`.
  - use `draft.sh [name]` to create `YY-MM-DD_name.md`
- **Plan** — when draft is solid, CC (+user) writes the HOW in `active/YY-MM-DD_{name}.md` (structured, high-level impl, no code samples, todo list at bottom). CC then enters Plan Mode to write implementation details. Plan filename gets appended to active doc's `# Plans` section.
  - Claude Code plans are saved in `proj/.claude/plans` instead of `~/.claude/plans` 
  - Transcript auto-copied to `agent_dev/transcripts/` on ExitPlanMode
- **Execute** — CC works off the plan, TDD, frequent commits. 
  - **Handoff** — manual precompaction, `/handoff` when context runs low. Checks off completed todos in active doc, enters Plan Mode to summarize done and remaining TODOs. User accepts and runs `/clear`.
- **Complete** — commit and PR, update `agent_dev/LOG.md` with concise summary.
  - **Review** — `/review-insights` surfaces all `# Insights` sections across CLAUDE.md files for human review. Completed active docs manually moved to `archived/`.

```
agent_dev/
  README.md              ← vision, priorities, # Insights
  CLAUDE.md              ← workflow instructions
  LOG.md                 ← agent summaries after task completion
  draft.sh               ← create drafting docs from terminal
  agent_docs/            ← optional guidelines (gitignored, include in CLAUDE.md per project need)
  drafting/
    YY-MM-DD_{name}.md
  active/
    YY-MM-DD_{name}.md   ← plan + # Plans + todo
  transcripts/
    YY-MM-DD_{name}.md
  archived/
```

### Automation

**Hooks**
- `save-transcript.sh` — copies + cleans session transcript to `agent_dev/transcripts/` on session end
- **Python format+lint** — runs `ruff format` + `ruff check --fix` on `.py` files after Write/Edit (via `uv run`)
- **JS/TS format** — runs `prettier --write` on `.js/.ts/.jsx/.tsx` files after Write/Edit
- **JS/TS lint** — runs `eslint --fix` on `.js/.ts/.jsx/.tsx` files after Write/Edit

> **Dev dependencies for target projects:** Python projects need `uv add --dev ruff`; TS/React projects need `npm install --save-dev eslint`. Hooks use `|| true` so missing tools never block Claude.

**Skills** (global — `~/.claude/skills/`)

| Skill | Description |
|-------|-------------|
| `/handoff [active-doc]` | Manual pre-compaction. Check off completed todos, summarize remaining in Plan Mode, prompt user to `/clear` |
| `/review-insights` | Scan all CLAUDE.md + agent_dev/README.md `# Insights` sections for review |
| `/update-docs [path]` | Recursively update all README.md files to reflect current codebase state |
| `/update-claudes [path]` | Recursively update all CLAUDE.md files for accuracy (preserves `# Insights`) |

### Codex MCP Server

The global settings include a [Codex CLI](https://developers.openai.com/codex/cli/) MCP server, letting Claude Code call Codex for co-brainstorming, co-planning, or independent code review.

- **Transport:** stdio (spawns `codex mcp-server` as a subprocess)
- **Sandbox:** read-only (`disk-full-read-access`) — Codex can read files but not edit or run commands
- **Requires:** `codex` CLI installed (`npm i -g @openai/codex`) and authenticated (`codex login`)

To register manually without copying settings.json:
```bash
claude mcp add -s user codex -- codex mcp-server -c 'sandbox_permissions=["disk-full-read-access"]'
```

Once registered, ask Claude Code to use Codex in natural language. Examples:

- `ask codex to review my implementation plan`
- `use codex to brainstorm approaches for [feature]`
- `have codex review the changes in this branch`
- `ask codex what it thinks about the architecture in src/`

Claude Code will call Codex via the MCP tool, passing your prompt and repo context. Codex runs in read-only mode so it can analyze code but won't make edits.

---

## Setup for New Projects

1. Copy global settings (once):
   ```bash
   cp global_settings/CLAUDE.md ~/.claude/CLAUDE.md
   cp global_settings/claude/settings.json ~/.claude/settings.json
   cp -r global_settings/claude/skills/* ~/.claude/skills/
   ```

2. Initialize a project:
   ```bash
   ./local_settings/cc_startup.sh /path/to/project
   ```
   This copies `.claude/` config, `agent_dev/` structure, and `CLAUDE.md` into the target project.

3. Update existing installs after pulling toolkit changes:
   ```bash
   ./global_settings/cc_update_global.sh           # update ~/.claude/
   ./local_settings/cc_update_local.sh /path/to/proj1 /path/to/proj2  # update project(s)
   ```
   Both show diffs and prompt before overwriting. Use `--force` to skip prompts.

---

# Misc

`uv activate` shortcut for `source .venv/bin/activate` in a project.

Add to `~/.{bash,zsh}rc`:

```shell
uv() {
    if [ "$1" = "activate" ]; then
        dir="$PWD"
        while [ "$dir" != "/" ]; do
            if [ -d "$dir/.venv" ]; then
                source "$dir/.venv/bin/activate"
                echo "Activated .venv in $dir"
                return
            fi
            dir=$(dirname "$dir")
        done
        echo "No .venv folder found in current or parent directories."
    else
        command uv "$@"
    fi
}
```

---

# Agent-specific Resources

## Claude Code
- [How Anthropic Uses Claude Code](https://www-cdn.anthropic.com/58284b19e702b49db9302d5b6f135ad8871e7658.pdf)
  - Always save checkpoints (start in clean git state, commit changes, revert if necessary)
  - Starting over often has a higher success rate than trying to fix Claude's mistakes
- UI design plugin: https://github.com/Dammyjay93/interface-design
- Security Review for Web Apps Skill: https://github.com/BehiSecc/VibeSec-Skill
- https://impeccable.style/ - Design fluency for AI coding tools

## Cursor
- [Cursor agents best practices](https://cursor.com/blog/agent-best-practices)
  - Start with plans
  - Sometimes the agent builds something that doesn't match what you wanted. Instead of trying to fix it through follow-up prompts, go back to the plan.
  - Let the agent find context
  - Long conversations can cause the agent to lose focus. After many turns and summarizations, the context accumulates noise and the agent can get distracted or switch to unrelated tasks. If you notice the effectiveness of the agent decreasing, it's time to start a new conversation.
  - When you start a new conversation, use @Past Chats to reference previous work rather than copy-pasting the whole conversation.
  - Create rules as markdown files in `.cursor/rules/`
    - Keep rules focused on the essentials: the commands to run, the patterns to follow, and pointers to canonical examples in your codebase. Reference files instead of copying their contents; this keeps rules short and prevents them from becoming stale as code changes.
