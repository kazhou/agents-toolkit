---
name: update-docs
description: Update documentation after completing work. Use when finishing a coding session or when asked to update docs.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash(git *)
---

# Documentation Update

Update README.md and agent_logs/LOG.md after completing work.

## Steps

1. Run `git diff HEAD~5 --stat` to see recent changes

2. Prepend to agent_logs/LOG.md with this format:
   ```
   ## [YYYY-MM-DD] - Session Summary
   ### Changes Made
   - List each significant change
   ### Files Modified
   - path/to/file.py - description of changes
   ### Next Steps
   - Any pending work or follow-ups
   ```

3. Update README.md if:
   - New features were added
   - Setup/installation changed
   - New dependencies were added
   - File structure changed

4. Commit documentation:
   ```bash
   git add README.md agent_logs/LOG.md && git commit -m "docs: update documentation"
   ```
