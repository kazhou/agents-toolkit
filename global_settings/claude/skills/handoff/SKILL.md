---
name: handoff
description: Prepare context handoff when running low. Checks off completed todos in active doc, summarizes remaining work in Plan Mode, and prompts user to /clear.
argument-hint: [active-doc-name]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash(git *), Bash(find *), Glob, Grep
---

# Handoff

Prepare a clean context handoff for the next session.

## Steps

1. **Find the current active doc**
   - If `$ARGUMENTS` is provided, find the matching doc in `agent_dev/active/` (match by name substring)
   - Otherwise, look in `agent_dev/active/` for `.md` files
   - If multiple exist and no argument was given, ask the user which one to update
   - Read it to understand the todo list and plans

2. **Check off completed todos**
   - Run `git log --oneline -20` and `git diff HEAD~5 --stat` to see what was done
   - Update the todo checkboxes in the active doc (`[ ]` → `[x]`) for completed items

3. **Commit progress**
   ```bash
   git add agent_dev/active/
   git commit -m "chore: handoff - update progress"
   ```

4. **Enter Plan Mode**
   - Write a plan doc summarizing:
     - What was completed this session
     - What remains to be done
     - Any blockers or decisions needed
   - Use ExitPlanMode when done

5. **Instruct the user**
   - Tell the user: "Accept the plan, then run `/clear` to start a fresh session."
