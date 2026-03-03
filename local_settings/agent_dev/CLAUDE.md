# agent_dev Workflow

## Phases
- **Brainstorm** — the WHAT and WHY. No code beyond discussion of frameworks/architectures, trade-offs, and final decisions. Start in `drafting/`, user and CC whiteboard together. When something solidifies, CC appends a dated note to `README.md # Insights`.
  - Avoid deleting lines the user added -- append instead. 
- **Plan** — when draft is solid, CC (+user) writes the HOW in `active/YY-MM-DD_{name}.md` (structured, high-level impl, no code samples, todo list at bottom). CC then enters Plan Mode to write implementation details. **After plan is created, append the plan filename to active doc's `# Plans` section.**
- **Execute** — CC works off the plan, TDD, frequent commits. Transcript auto-copied to `transcripts/` on session end.
- **Handoff** — `/handoff` when context runs low. Checks off completed todos in active doc, enters Plan Mode to summarize done and remaining TODOs. User accepts and runs `/clear`.
- **Review** — `/review-insights` surfaces all `# Insights` sections across CLAUDE.md files for human review. Completed active docs manually moved to `archived/`.

## Directory Rules

```
agent_dev/
  README.md              ← vision, priorities, # Insights
  CLAUDE.md              ← workflow instructions (this file)
  LOG.md                 ← reverse-chronological agent session updates
  drafting/              → freeform, no restrictions
    YY-MM-DD_{name}.md
  active/                → high-level only, no code samples
    YY-MM-DD_{name}.md   ← plan, # Plans links to .claude/plans, todo
  transcripts/           → auto-saved, gitignored
    YY-MM-DD_{name}.txt
  archived/              → completed active docs
```

## File Rules
- `drafting/` — freeform, no restrictions, treat like whiteboard/notepad
- `active/` — high-level only, no code samples
  - Each active plan should cover a single, related scope. "Can this ship independently?", if so, it should split into its own active plan
- `README.md # Insights` — append-only, dated
- `CLAUDE.md # Insights` — append-only, dated
- `LOG.md` — reverse-chronological, prepend session summaries


# Insights
<!-- CC appends workflow learnings here. Append-only, dated. -->
