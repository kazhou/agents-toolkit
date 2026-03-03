# CLAUDE.md

## Python
- `uv` only. `uv run` for all commands. Never pip/conda directly.
- Install: `uv add <pkg>`. Dev: `uv add --dev <pkg>`. Sync: `uv sync`.

## Git
- **Default base branch: `dev`** (NOT `main`)
- New branch off `dev` per major refactor or update: `git worktree add <path> -b <branch> dev`. New venv per worktree: run `uv venv && uv sync`
- Commit after each step, with short descriptive messages.
- PRs always target `dev`: `gh pr create --base dev ...`

## Code
- Refactor common code and create data structures to keep code modular and clean. Avoid redundancy, and reuse existing utils. 
- Always search the web for real API documentation. 
- When writing scripts that process data iteratively, save outputs incrementally (e.g., append to JSONL) so progress can be resumed if the script is cancelled and re-run.
- Only use `try/except` when there is a specific reason to handle them. Let unexpected errors surface.

## Testing (TDD)
- Before writing a test, ask: what specific bug does this catch? If you can't answer, skip it.
- Prioritize edge cases, error handling, and integration points. Skip happy-path tests for trivial functions.
- Each test verifies exactly one behavior. Name it after the behavior, not the function.
- Write tests first (RED), commit them, confirm they fail (show failing test output), then implement (GREEN), then refactor.
- No mocks for unwritten code — use fixtures based on real inputs/outputs.

## Debugging
- No quick fixes. Always diagnose to the root cause and devise proper solutions. Never apply patches or workarounds unless the user explicitly asks.

## Documentation
- Use pointers/links over duplication. Keep a single source of truth without redundancy.
- Keep READMEs concise. Maintain markdown files for subdirectories and distinct features, with pointers to/from the main README

## Plan Mode
- Prefer simple, direct solutions. Add complexity only when simpler approaches genuinely won't work.
- Plans should point to location of existing code (`file:line`) instead of copying said code into the plan document.

## On Compaction
Preserve: modified files list, current task, next steps, failing tests

## On Completion
- Update `agent_dev/LOG.md` with concise summary.
- if there are tests, re-run tests and ensure they pass. 
- run skill `/update-docs` to update project README files and skill `/update-claudes` to update project CLAUDE.md files