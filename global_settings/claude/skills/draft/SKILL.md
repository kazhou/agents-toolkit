---
name: draft
description: Create a new drafting doc in agent_dev/drafting/ and start brainstorming
argument-hint: [name]
disable-model-invocation: true
allowed-tools: Bash(bash *create-draft.sh*)
---

# Draft

Create a new brainstorming doc and start the brainstorm phase.

## Steps

1. **Create the file**
   - Run: `bash !`echo $SKILL_DIR`/create-draft.sh $ARGUMENTS`
   - This creates `agent_dev/drafting/{date}_{slug}.md` with the brainstorm template
   - Handles slug normalization and filename collisions automatically

2. **Start brainstorming**
   - Tell the user the file is created and its path. Await further instruction.
