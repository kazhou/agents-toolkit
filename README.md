# agents-toolkit

Repo for various coding agents scripts, guidelines, and tools. To copy into/reuse in projects.

This is a work in progress!

# Contents
- global_settings - shared workflow
- local_settings - for each project


- **Claude Code Skills** (see [Skills section](#claude-code-skills))
  - `/update-docs` - Update README and LOG.md after completing work
  - `/fix-issue [number]` - Implement a GitHub issue using TD

- **Claude Code Notifications** - get notified when Claude needs input

---

## Workflow

- **Brainstorm** — the WHAT and WHY. No code beyond discussion of frameworks/architectures, trade offs, and final decisions. Start in `drafting/`, user and CC whiteboard together. No code. When something solidifies, CC appends a dated note to `agent_dev/README.md # Insights` for you to review later.
- **Plan** — when draft is solid, CC (+user) writes the HOW in `active/YY-MM-DD_{name}.md` (structured, high-level impl, no code samples, todo list at bottom). CC then enters Plan Mode to write implementation details. Plan filename gets appended to active doc's `# Plans` section. 
- **Execute** — CC works off the plan, TDD, frequent commits. Cleaned transcript copied to `agent_dev/transcripts/` on completion.
- **Handoff** — `/handoff` when context runs low. Checks off completed todos in active doc, then enters Plan Mode, summarizes done and remaining TODOs, /clear and accepts plan.
- **Complete** - commit and PR, update `agent_dev/LOG.md` with concise summary
  - **Review** — `/review-insights` surfaces all `# Insights` sections across CLAUDE.md files for human review. Completed active docs manually moved to archived/.

```
agent_dev/
  README.md              ← vision, priorities, # Insights
  CLAUDE.md              ← workflow instructions
  LOG.md                 ← agent summaries after task completion
  drafting/
    YY-MM-DD_{name}.md
  active/
    YY-MM-DD_{name}.md   ← plan + # Plans + todo
  transcripts/
    YY-MM-DD_{name}.md
  archived/

Root + subdir CLAUDE.md files:
  # Insights             ← CC appends, dated, reviewed via /review-insights
```

Automation
```
Hooks
  - transcript copy + rename → agent_dev/transcripts/ on session end
  - append plan filename → active doc # Plans section after plan created

Skills
  - /handoff   → check off todos, summarize remaining, /clear
  - /review-insights  → scan all CLAUDE.md + agent_dev/README.md # Insights, output for review
```

Rules in agent_dev/CLAUDE.md:
```
- drafting/    → freeform, no restrictions
- active/      → high-level only, no code samples
- README.md    → # Notes append-only, dated
- CLAUDE.md    → # Insights append-only, dated
- LOG.md       → reverse-chronological/prepended agent session updates
- splitting    → when scope is too big, make a new named active file
                 README.md shows how they relate
```
---

## Claude Code Skills

Custom skills for Claude Code workflows. Skills are invoked with `/skill-name` in the chat.

### Available Skills

| Skill | Description | Usage |
|-------|-------------|-------|
| `/update-docs` | Update documentation after completing work | `/update-docs` |
| `/fix-issue` | Implement a GitHub issue using TDD | `/fix-issue 123` |

### Setup for New Projects

Copy the skills directory to your project:

```bash
cp -r .claude/skills/ /path/to/new-project/.claude/skills/
```

Or copy to personal directory for use across all projects:

```bash
cp -r .claude/skills/* ~/.claude/skills/
```

### Skill Details

#### `/update-docs`

Updates README.md and agent_logs/LOG.md after completing work:
1. Shows recent git changes (`git diff HEAD~5 --stat`)
2. Prepends session summary to agent_logs/LOG.md
3. Updates README.md if functionality changed
4. Commits documentation changes

#### `/fix-issue [number]`

Implements a GitHub issue using Test-Driven Development:
1. Fetches issue details from GitHub (`gh issue view`)
2. Creates feature branch (`feature/<issue-number>`)
3. Writes tests first (TDD) - confirms they fail
4. Implements the fix to pass tests
5. Updates documentation
6. Creates PR (`gh pr create --fill`)

### Creating Custom Skills

Skills live in `.claude/skills/<name>/SKILL.md`:

```yaml
---
name: my-skill
description: What it does and when to use it
disable-model-invocation: true  # Only manual /my-skill invocation
allowed-tools: Read, Write, Edit, Bash(git *)
---

# Instructions for Claude to follow...
```

Key frontmatter options:
- `disable-model-invocation: true` - Prevents auto-invocation; requires `/skill-name`
- `allowed-tools` - Tools Claude can use without permission prompts
- `argument-hint` - Shows in autocomplete (e.g., `[issue-number]`)

See [Claude Code Skills Docs](https://code.claude.com/docs/en/skills) for full reference.





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
        # Pass all other commands to the real uv
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

## Cursor
- [Cursor agents best practices](https://cursor.com/blog/agent-best-practices)
  - Start with plans
  - Sometimes the agent builds something that doesn't match what you wanted. Instead of trying to fix it through follow-up prompts, go back to the plan.
  - Let the agent find context
  - Long conversations can cause the agent to lose focus. After many turns and summarizations, the context accumulates noise and the agent can get distracted or switch to unrelated tasks. If you notice the effectiveness of the agent decreasing, it's time to start a new conversation.
  - When you start a new conversation, use @Past Chats to reference previous work rather than copy-pasting the whole conversation.
  - Create rules as markdown files in `.cursor/rules/`
    - Keep rules focused on the essentials: the commands to run, the patterns to follow, and pointers to canonical examples in your codebase. Reference files instead of copying their contents; this keeps rules short and prevents them from becoming stale as code changes.
  - Skills are defined in SKILL.md files and can include:
    - Custom commands: Reusable workflows triggered with / in the agent input
    - Hooks: Scripts that run before or after agent actions
    - Domain knowledge: Instructions for specific tasks the agent can pull in on demand
  - The agent can process images directly from your prompts. Paste screenshots, drag in design files, or reference image paths.
