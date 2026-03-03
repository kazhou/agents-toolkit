# CLAUDE.md

## Python
- `uv` only. `uv run` for all commands. Never pip/conda directly.
- Install: `uv add <pkg>`. Dev: `uv add --dev <pkg>`. Sync: `uv sync`.

## Git
- Work in `dev` branch, NEVER work directly in `main`.
- New branch off `dev` per major refactor or update. Commit after each step, with short descriptive messages.
- When a task is done, tell the user which branch to make a PR for.

## Code
- Refactor common code and create data structures to keep code modular and clean. Avoid redundancy, and reuse existing utils. 
- Always search the web for real API documentation. No need to ask for permission to search the web.
- When writing scripts that process data iteratively, save outputs incrementally (e.g., append to JSONL) so progress can be resumed if the script is cancelled and re-run.

## Debugging
- No quick fixes. Always diagnose to the root cause and devise proper solutions. Never apply patches or workarounds unless the user explicitly asks.

## Documentation
- Use pointers/links over duplication. Keep a single source of truth without redundancy.
- Keep READMEs concise. Maintain markdown files for subdirectories and distinct features, with pointers to/from the main README

## Plan Mode
- Plans should point to location of existing code (`file:line`) instead of copying said code into the plan document.
- Prefer simple, direct solutions. Add complexity only when simpler approaches genuinely won't work.

## 

## On Compaction
Preserve: modified files list, current task, next steps, failing tests

## On Completion
- Update `agent_dev/LOG.md` with concise summary.
- if there are tests, re-run tests and ensure they pass. 
- run skill `/update-docs` to update project README files and skill `/update-claudes` to update project CLAUDE.md files