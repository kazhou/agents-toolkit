# CLAUDE.md

When talking to the user, be CONCISE. Only elaborate or explain when the user asks.

## Python
- `uv` only. `uv run` for all commands. Never pip/conda directly.
- Install: `uv add <pkg>`. Dev: `uv add --dev <pkg>`. Sync: `uv sync`.

## Git
- **Default base branch: `dev`** (NOT `main`)
- New branch off `dev` per major refactor or update: `git worktree add <path> -b <branch> dev`. New venv per worktree: run `uv venv && uv sync`
- Commit after each step, with short descriptive messages.
- PRs always target `dev`: `gh pr create --base dev ...`

## Code
- Always search the web for real API documentation.
- Refactor redundant code (3+ callsites) and create data structures (if 3+ concrete subclasses already exist) to keep code modular and clean. Avoid excess redundancy, and reuse existing utils.
- If you're adding something "for future use," don't (YAGNI)
- When writing scripts that process data iteratively, save outputs incrementally (e.g., append to JSONL) so progress can be resumed if the script is cancelled and re-run.
- Only use `try/except` when there is a specific reason to handle them. Let unexpected errors surface.

## Brainstorming
- Before building features or modifying behavior, run `/brainstorm`.

## Testing (TDD)
- Skip tests unless the function has real edge cases, error paths, or integration risk. Default is no test.
- Before writing a test, ask: what specific bug does this catch? If you can't answer, skip it.
- Each test verifies exactly one behavior. Name it after the behavior, not the function.
-  Write tests first (RED), commit them, confirm they fail (show failing test output), then implement (GREEN), then refactor.
- No mocks for unwritten code — use fixtures based on real inputs/outputs.

## Debugging
- No quick fixes. Always diagnose to the root cause and devise proper solutions. Never apply patches or workarounds unless the user explicitly asks.
- For systematic debugging methodology, run `/debug`.

## Documentation
- Use pointers/links over duplication. Keep a single source of truth without redundancy.
- Keep READMEs concise. Maintain markdown files for subdirectories and distinct features, with pointers to/from the main README

## Plan Mode
- Prefer simple, direct solutions. Add complexity only when simpler approaches genuinely won't work.
- Plans should point to location of existing code (`file:line`) instead of copying said code into the plan document.
- After Plan Mode produces a session plan, run `/audit-plan` before execution begins.

## On Compaction
- Preserve: modified files list, current task, next steps, failing tests

## On Completion
- Update `agent_dev/LOG.md` with concise summary.
- if there are tests, re-run tests and ensure they pass.
- Before claiming work is complete, run the verification command (tests, build, linter) and show the output. No completion claims without fresh evidence.
- When receiving code review feedback, verify each suggestion against the codebase before implementing. Push back with technical reasoning if a suggestion is wrong or violates YAGNI.
- run `/sync-docs` to update project README and CLAUDE.md files
