---
name: fix-issue
description: Implement a GitHub issue using TDD workflow
argument-hint: [issue-number]
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(gh *), Bash(uv *), Read, Write, Edit
---

# Fix GitHub Issue

Implement GitHub issue #$ARGUMENTS using Test-Driven Development.

## Steps

1. **Get issue details**
   ```bash
   gh issue view $ARGUMENTS
   ```

2. **Create feature branch**
   ```bash
   git checkout -b feature/$ARGUMENTS
   ```

3. **Write tests first (TDD)**
   - Create test file in `tests/`
   - Define expected inputs and outputs
   - Run tests to confirm they fail:
     ```bash
     uv run pytest tests/ -v
     ```

4. **Implement the fix**
   - Write code to pass the tests
   - Keep iterating until all tests pass
   - Do NOT modify the tests

5. **Update documentation**
   - Update README.md if functionality changed
   - Prepend session summary to agent_logs/LOG.md

6. **Commit and create PR**
   ```bash
   git add -A
   git commit -m "feat: implement issue #$ARGUMENTS"
   gh pr create --fill
   ```
