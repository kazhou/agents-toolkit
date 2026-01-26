# Portable Planning Session Logger

## Goal
Create a self-contained planning session logger that can be copied to any project repo. When Claude Code exits plan mode, automatically save:
- Plan file → `agent_logs/plans/YYYY-MM-DD-<plan-name>.md`
- Transcript → `agent_logs/transcripts/YYYY-MM-DD-<plan-name>.transcript.txt`

## Files to Create/Modify

### 1. `.claude/settings.local.json` (modify)
Set `plansDirectory` so plans write directly to project:
```json
{
  "plansDirectory": "./agent_logs/plans"
}
```
This means plans are already in the right folder with Claude's random names (e.g., `curious-twirling-cocoa.md`).

### 2. `.claude/hooks/save-planning-logs.sh` (create)
Bash script with embedded Python:
- Triggered by `PostToolUse` hook on `ExitPlanMode`
- Renames plan file from random name → `YYYY-MM-DD-<heading-name>.md`
- Cleans JSONL transcript to readable text → `agent_logs/transcripts/`
- Auto-commits both files with message: `chore: save planning session - <plan-name>`

### 3. `.claude/settings.json` (modify)
Add hook configuration:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/save-planning-logs.sh"
          }
        ]
      }
    ]
  }
}
```

### 4. `agent_logs/` structure (ensure exists)
```
agent_logs/
├── plans/.gitkeep
├── transcripts/.gitkeep
└── LOG.md
```

## Portability Design
- Uses `$CLAUDE_PROJECT_DIR` (set by Claude Code) for all paths
- `plansDirectory` is relative (`./agent_logs/plans`)
- Self-contained Python in heredoc (no external dependencies beyond Python 3)
- Auto-creates directories if missing

## To Copy to New Project
```bash
cp -r .claude/ /path/to/new-project/
mkdir -p /path/to/new-project/agent_logs/{plans,transcripts}
```

## Implementation Details

### Handling Multiple Plan Mode Sessions
If plan mode is re-entered in the same session:
- Each `ExitPlanMode` triggers the hook independently
- Each plan mode creates a new plan file (different random name in `~/.claude/plans/`)
- If same heading name on same day, append short ID: `YYYY-MM-DD-<name>-abc123.md`
- Transcript: save the full session transcript each time (later plans include earlier context)

### Plan Discovery
Since `plansDirectory` points to `./agent_logs/plans`, the plan is already there:
1. **From hook input**: Check `tool_input` for plan file path
2. **Fallback**: Most recently modified `.md` file in `agent_logs/plans/` (last 5 min)

The hook renames the file in place (no copy needed).

### Name Extraction
1. Parse first `# Heading` from plan content
2. Convert to kebab-case (lowercase, hyphens)
3. Fallback to original filename or `session-{id}`
4. If file exists, append `-{short_session_id}` to make unique

### Transcript Cleaning
- Parse JSONL line by line
- Extract role (user/assistant) and content
- Handle content blocks (text, tool_use)
- Remove ANSI codes and control characters
- Format as `User: ...` / `Assistant: ...`

### Git Auto-Commit
After saving plan and transcript:
```bash
git add agent_logs/plans/<plan>.md agent_logs/transcripts/<plan>.transcript.txt
git commit -m "chore: save planning session - <plan-name>"
```
- Uses `--no-verify` to skip hooks (avoid recursion)
- Only commits if there are staged changes
- Silent fail if not in a git repo

## Verification
1. Enter plan mode with `\plan`
2. Create a simple plan
3. Exit plan mode
4. Check `agent_logs/plans/` and `agent_logs/transcripts/` for new files
5. Verify plan name derived from heading
6. Verify transcript is clean readable text

## Future: Cursor Compatibility
- Cursor uses different hook system / plan mode structure
- Could add detection logic to support both
- For now, Claude Code only
