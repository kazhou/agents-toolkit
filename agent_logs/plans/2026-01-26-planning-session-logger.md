# Plan: Planning Session Logger

## Goal
Create a Claude Code hook that automatically saves planning mode transcripts and plan files to `agent_logs/` when plan mode exits.

## Solution: Claude Code Hooks

Use Claude Code's native `PostToolUse` hook with `ExitPlanMode` matcher to automatically capture and save planning session data.

## Files to Create/Modify

### 1. `.claude/settings.json` - Hook Configuration
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/save-planning-logs.sh"
          }
        ]
      }
    ]
  }
}
```

### 2. `.claude/hooks/save-planning-logs.sh` - Main Logger Script

Receives JSON via stdin:
```json
{
  "session_id": "abc123",
  "transcript_path": "/home/user/.claude/projects/.../session.jsonl",
  "cwd": "/path/to/project"
}
```

Script will:
1. Parse JSON input (jq or python fallback)
2. Find plan file using (in order of reliability):
   - Hook input fields (`tool_input.plan_path`, etc.) - most reliable
   - Search transcript for `.claude/plans/*.md` references - session-specific
   - Recently modified files in `~/.claude/plans/` (30 min window) - fallback
3. Extract plan name from plan file's first `#` heading
4. Clean transcript (convert JSONL to readable text)
5. Save transcript as `YYYY-MM-DD-<plan-name>.transcript.txt`
6. Copy plan file as `YYYY-MM-DD-<plan-name>.md`
7. Git commit the saved files

### 3. Directory Structure
```
agent_logs/
├── transcripts/     # YYYY-MM-DD-<plan-name>.transcript.txt
├── plans/           # YYYY-MM-DD-<plan-name>.md
└── LOG.md           # Session summaries (reverse chronological)
```

## Naming Convention (per AGENTS.md)

- **Plans**: `YYYY-MM-DD-<plan-name>.md`
- **Transcripts**: `YYYY-MM-DD-<plan-name>.transcript.txt`

## Behavior

1. On exiting plan mode: save transcript + plan, git commit
2. On re-entering plan mode (same session): update same files, commit changes

## Verification

1. Start Claude Code session
2. Enter plan mode (`/plan`)
3. Create/approve a plan
4. Exit plan mode
5. Check `agent_logs/transcripts/` for `YYYY-MM-DD-<plan-name>.transcript.txt`
6. Check `agent_logs/plans/` for `YYYY-MM-DD-<plan-name>.md`
7. Verify git commit was created
