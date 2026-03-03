---
name: draft
description: Create a new drafting doc in agent_dev/drafting/ and start brainstorming
argument-hint: [name]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Bash(ls *)
---

# Draft

Create a new brainstorming doc and start the brainstorm phase.

Today's date: !`date +%y-%m-%d`

## Steps

1. **Determine the name**
   - If `$ARGUMENTS` is provided, use it as the slug (lowercase, hyphens or underscores)
   - Otherwise, slug is `draft`

2. **Check for collisions**
   - Glob `agent_dev/drafting/*` to see existing docs
   - If a file with the same date + slug already exists, append a suffix (`_2`, `_3`, etc.)

3. **Create the file**
   - Path: `agent_dev/drafting/{date}_{slug}.md` (e.g., `agent_dev/drafting/25-03-02_api_design.md`)
   - Template:

   ```markdown
   # {slug}
   <!-- Brainstorm: WHAT and WHY. No code beyond frameworks/architectures. -->


   ```

4. **Start brainstorming**
   - Tell the user the file is created. Await further instruction.
