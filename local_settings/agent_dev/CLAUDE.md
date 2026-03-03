# agent_dev Workflow

## Phases
- **Brainstorm** — the WHAT and WHY. No code beyond discussion of frameworks/architectures, trade-offs, and final decisions. Start in `drafting/` (create docs with `agent_dev/draft.sh [name]`), user and CC whiteboard together. When something solidifies, CC appends a dated note to `README.md # Insights`.
  - Avoid deleting lines the user added -- append instead.
- **Plan** — when draft is solid, CC (with user input) writes the HOW in `active/YY-MM-DD_{name}.md` (structured, high-level impl, no code samples, todo list at bottom). CC then enters Plan Mode to write implementation details. **After plan is created, append the plan filename to active doc's `# Plans` section.**
  - Task format in active plans:
    - `[parallel]` — can run concurrently with other `[parallel]` tasks
    - `[depends: X]` — must wait for named task(s) to complete
    - `scope:` per task — dirs/files this task is allowed to touch
  - Active plans must include: `# Boundaries` (plan-level do-not-touch), `# Tasks`, `# Blocked`, `# Plans`
- **Execute** — CC works off the plan, TDD, frequent commits. Update `LOG.md`
  - Parallel agents: each gets its own worktree, scoped to task's `scope:` line. Never run parallel agents on the same working directory.
  - If two tasks would edit overlapping files, they can't be `[parallel]` — sequence them with `[depends:]`.
  - After parallel agents complete, merge worktrees sequentially.
  - When blocked mid-task: append question + context to active plan's `# Blocked`, skip that task, continue with others.
  - At session start: check `# Blocked` for items resolved since last session.
  - When all tasks complete: merge worktrees into feature branch, create one PR per active plan.
  - Agent writes the PR description: what was built, key decisions, what was NOT touched.

## Directory Rules

```
agent_dev/
  README.md              ← vision, priorities, # Insights
  LOG.md                 ← reverse-chronological agent session updates
  drafting/              → freeform, no restrictions
    YY-MM-DD_{name}.md
  active/                → high-level only, no code samples
    YY-MM-DD_{name}.md   ← plan, # Boundaries, # Tasks, # Blocked, # Plans
```

## File Rules
- `drafting/` — freeform, no restrictions, treat like whiteboard/notepad
- `active/` — high-level only, no code samples
  - Each active plan should cover a single, related scope. "Can this ship independently?" — if so, split into its own active plan. A single brainstorm/draft may produce multiple active plans.
  - One active plan = one PR. 
- `README.md # Insights` — append-only, dated
- `CLAUDE.md # Insights` — append-only, dated
- `LOG.md` — reverse-chronological, prepend session summaries


# Insights
<!-- CC appends workflow learnings here. Append-only, dated. -->
