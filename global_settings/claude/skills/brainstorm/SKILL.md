---
name: brainstorm
description: "Use before any creative work — creating features, building components, adding functionality, or modifying behavior. Explores intent, requirements, and design before implementation."
---

# Brainstorm Ideas Into Designs

Help turn ideas into fully formed designs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.

<HARD-GATE>
Do NOT write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function utility, a config change — all of them. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for truly simple projects), but you MUST present it and get approval.

## Checklist

Complete these in order:

1. **Explore project context** — check files, docs, recent commits
2. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
3. **Propose 2-3 approaches** — search the web for standard approaches, then present them with trade-offs and your recommendation
4. **Present design** — in sections scaled to complexity, get user approval after each section
5. **On approval** — create active doc and transition to Plan Mode (see below)

## The Process

**Understanding the idea:**
- Check out the current project state first (files, docs, recent commits)
- Before asking detailed questions, assess scope: if the request describes multiple independent subsystems, flag this immediately. Don't spend questions refining details of a project that needs to be decomposed first.
- If the project is too large for a single spec, help the user decompose into sub-projects
- For appropriately-scoped projects, ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible
- Only one question per message
- Focus on understanding: purpose, constraints, success criteria
- Invoke Codex (via MCP) for co-brainstorming when exploring approaches — get a second model's perspective on trade-offs

**Exploring approaches:**
- Search the web to see if there are already framework, libraries, or approaches that we can re-use. If there are multiple, consider trade-offs.
- Propose 2-3 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why

**Presenting the design:**
- Scale each section to its complexity: a few sentences if straightforward, up to 200-300 words if nuanced
- Ask after each section whether it looks right so far
- Cover: architecture, components, data flow, error handling, testing

**Design for isolation and clarity:**
- Break the system into smaller units each with one clear purpose
- Communicate through well-defined interfaces
- Can someone understand what a unit does without reading its internals?

**Working in existing codebases:**
- Explore the current structure before proposing changes. Follow existing patterns.
- Where existing code has problems that affect the work, include targeted improvements as part of the design
- Don't propose unrelated refactoring

## On Approval

When the user signals approval ("approved", "ship this", "looks good", "let's do it", etc.):

1. **Create active doc** at `agent_dev/active/YY-MM-DD_{name}.md` with this structure:
   ```
   # {Name}

   ## Summary
   [1-2 sentences: what and why, from final design decisions]

   ## Boundaries
   [What NOT to touch — dirs, files, patterns that are out of scope]

   ## Tasks
   [Concrete task list from the design. Tag with [parallel]/[depends: X] and scope: per task]

   ## Blocked
   [Empty initially — agents append questions here during execution]

   ## Plans
   [Empty initially — Plan Mode filenames appended here]
   ```
   - Link back to drafting doc if one exists
   - Keep it high-level — implementation details belong in Plan Mode, not here

2. **Transition to Plan Mode** — CC enters Plan Mode to write implementation details to `.claude/plans/`

**Do not** auto-create the active doc during exploratory back-and-forth. Only on explicit approval.

## Key Principles
- **One question at a time**
- **Multiple choice preferred**
- **YAGNI ruthlessly**
- **Explore alternatives** — always propose 2-3 approaches
- **Incremental validation**
- **Be flexible**
- **Active docs are WHAT, not HOW** — keep them concise
