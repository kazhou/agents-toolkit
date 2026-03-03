## Branch Strategy
- **Default base branch: `dev`** (NOT `main`)
- All PRs must target `dev` branch
- Never create PRs targeting `main` directly

## Worktrees
- Always create worktrees from `dev`: `git worktree add <path> -b <branch> dev`
- New venv per worktree: run `uv venv && uv sync`

## PR Creation
When creating a PR, always use:
```
gh pr create --base dev ...
```
