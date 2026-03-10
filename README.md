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
    skills/              ← global skills (/brainstorm, /debug, /audit-plan, /sync-docs, /handoff, /review-insights, /data-analysis, /jupyter-notebook, /plotting)
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
```

---

## Workflow

- **Brainstorm** (`/brainstorm`) — explore the WHAT and WHY. User + CC whiteboard freely in `drafting/` docs (`draft.sh [name]` to create). No code, only frameworks, trade-offs, and decisions. On approval, creates active doc and transitions to Plan Mode. A single brainstorm may produce multiple active plans.
  - Surface broader goals/decisions to `agent_dev/README.md # Insights`
- **Plan** — turn a solid draft into one or more active plans in `active/`. Each active plan covers a single shippable scope — if something can ship independently, it gets its own plan. Tasks are tagged for parallelism (`[parallel]`, `[depends: X]`) and scoped to specific files/dirs. Plans include boundaries (what not to touch) and a blocked section for unresolved questions.
  - CC enters Plan Mode based on these finalized docs
  - Claude Code plans saved in `proj/.claude/plans`
  - Transcripts auto-copied to `agent_dev/transcripts/` on ExitPlanMode
- **Execute** — run `/audit-plan` before first code edit. Agents work off the plan. Parallel tasks run in separate worktrees for isolation. When an agent hits ambiguity, it documents the question in `# Blocked` and moves on to other tasks instead of guessing or stalling.
  - **Handoff** — `/handoff` when context runs low. Checks off completed todos, summarizes remaining work. Can also be triggered as a manual pre-compaction by user.
- **Complete** — one PR per active plan. Agent writes the PR description (what was built, key decisions, what was not touched). Run `/sync-docs` to update READMEs and CLAUDE.md files, archive completed plans. Agent updates `agent_dev/LOG.md`.
  - **Review** — `/review-insights` surfaces `# Insights` across CLAUDE.md files.

```
agent_dev/
  README.md              ← vision, priorities, # Insights
  CLAUDE.md              ← workflow instructions (machine-readable task format)
  LOG.md                 ← agent summaries after task completion
  draft.sh               ← create drafting docs from terminal
  drafting/
    YY-MM-DD_{name}.md
  active/
    YY-MM-DD_{name}.md   ← plan, # Boundaries, # Tasks, # Blocked, # Plans
  transcripts/
    YY-MM-DD_{name}.md
  archived/
```

### Automation

**Hooks**
- `save-transcript.sh` — copies + cleans session transcript to `agent_dev/transcripts/` on ExitPlanMode
- **`/audit-plan` reminder** — on ExitPlanMode, reminds agent to run `/audit-plan` before coding
- **`/handoff` reminder** — on PreCompact, reminds agent to run `/handoff` before context compaction
- **Python format+lint** — runs `ruff format` + `ruff check --fix` on `.py` files after Write/Edit (via `uv run`)
- **JS/TS format** — runs `prettier --write` on `.js/.ts/.jsx/.tsx` files after Write/Edit
- **JS/TS lint** — runs `eslint --fix` on `.js/.ts/.jsx/.tsx` files after Write/Edit

> **Dev dependencies for target projects:** Python projects need `uv add --dev ruff`; TS/React projects need `npm install --save-dev eslint`. Hooks use `|| true` so missing tools never block Claude.

**Skills** (global — `~/.claude/skills/`)

| Skill | Phase | Description |
|-------|-------|-------------|
| `/brainstorm` | Brainstorm | Before features/behavior changes — explore intent, propose approaches, get approval |
| `/audit-plan` | Plan → Execute | After Plan Mode, before coding — scope check + simplicity audit |
| `/debug` | Execute | On bugs, test failures, unexpected behavior — systematic root cause analysis |
| `/handoff [active-doc]` | Execute | Manual pre-compaction — check off completed todos, summarize remaining |
| `/sync-docs [path]` | Complete | Update all README.md and CLAUDE.md files, archive completed plans |
| `/review-insights` | Review | Scan all `# Insights` sections for review |
| `/data-analysis` | Execute | Guidelines for data analysis workflows |
| `/jupyter-notebook` | Execute | Guidelines for Jupyter notebook workflows |
| `/plotting` | Execute | Guidelines for plotting and visualization |

Skills marked with \* are adapted from [superpowers](https://github.com/anthropics/claude-plugins-official) v5.0.0: `/brainstorm` (from `brainstorming`), `/debug` (from `systematic-debugging`).

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
