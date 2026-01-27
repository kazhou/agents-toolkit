# Plan: Cursor Plan Mode Logging Support

## Research Findings

### Cursor's Hook System

Cursor (v1.7+) has a hooks system similar to Claude Code with these lifecycle events:

| Hook | Description |
|------|-------------|
| `sessionStart` / `sessionEnd` | Session lifecycle |
| `preToolUse` / `postToolUse` | Tool execution |
| `beforeShellExecution` / `afterShellExecution` | Shell commands |
| `afterFileEdit` | After file modifications |
| `stop` | Agent completion |

**Configuration location:** `.cursor/hooks.json` (project) or `~/.cursor/hooks.json` (user)

### Key Limitation: No Plan-Specific Hooks

**Critical finding:** Cursor has NO plan-specific hooks in its documented API.

- No `ExitPlanMode` equivalent tool/event
- No `afterPlanComplete` or similar hook
- Plan mode is an internal UI state, not exposed to hooks

### Plan File Storage in Cursor

- **Default**: `~/.cursor/plans/` (global, user-level)
- **Workspace**: `.cursor/plans/` (requires manual "Save to workspace" click)
- Plans are Markdown files, similar to Claude Code

### Comparison with Claude Code

| Feature | Claude Code | Cursor |
|---------|-------------|--------|
| Plan mode hook | `PostToolUse` + `ExitPlanMode` matcher | **None** |
| Plan file location | `~/.claude/plans/` | `~/.cursor/plans/` |
| Transcript access | Via `~/.claude/projects/` | Via `transcript_path` in hook input |
| Hook config | `.claude/settings.json` | `.cursor/hooks.json` |

---

## Proposed Approaches

### Option A: `sessionEnd` Hook (Recommended)

**Approach:** Trigger logging on every session end, then check if a plan file was recently modified.

```json
// .cursor/hooks.json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      {
        "command": "./.cursor/hooks/save-planning-logs-cursor.sh",
        "timeout": 30
      }
    ]
  }
}
```

**Pros:**
- Works with Cursor's existing hook system
- Most reliable detection of planning sessions
- Gets `transcript_path` in hook input

**Cons:**
- Triggers on ALL sessions (not just plan mode)
- Script must detect if planning actually occurred

**Detection logic:**
1. Check `~/.cursor/plans/` for recently modified files (< 5 min)
2. If found, copy to `agent_logs/plans/` with dated name
3. Use `transcript_path` from hook input to save transcript

### Option B: `afterFileEdit` Hook

**Approach:** Watch for file edits in the plans directory.

```json
{
  "version": 1,
  "hooks": {
    "afterFileEdit": [
      {
        "command": "./.cursor/hooks/save-planning-logs-cursor.sh",
        "matcher": "*.cursor/plans/*"
      }
    ]
  }
}
```

**Pros:**
- Only triggers when plans directory is touched
- More targeted than sessionEnd

**Cons:**
- May not trigger for plan creation (only edits)
- Path matching behavior needs testing
- May miss plans saved to `~/.cursor/plans/`

### Option C: Manual Script

**Approach:** User runs a command after planning.

```bash
# After planning session:
./scripts/save-cursor-plan.sh
```

**Pros:**
- Most reliable - user controls when to save
- Works regardless of Cursor's hook system

**Cons:**
- Requires manual intervention
- Easy to forget

---

## Recommended Implementation

**Selected: Option B (afterFileEdit hook)** with auto-commit

### Implementation Steps

1. **Create `.cursor/hooks.json`** with afterFileEdit hook:
   ```json
   {
     "version": 1,
     "hooks": {
       "afterFileEdit": [
         {
           "command": "./.cursor/hooks/save-planning-logs-cursor.sh",
           "matcher": "**/plans/*.md"
         }
       ]
     }
   }
   ```

2. **Create `.cursor/hooks/save-planning-logs-cursor.sh`** that:
   - Reads hook input from stdin (includes edited file path, `transcript_path`)
   - Extracts the plan file path from hook input
   - Extracts plan name from first markdown heading
   - Copies plan to `agent_logs/plans/YYYY-MM-DD-cursor-<name>.md`
   - Cleans transcript using `transcript_path` and saves to `agent_logs/transcripts/YYYY-MM-DD-cursor-<name>.transcript.txt`
   - Auto-commits both files to git

3. **Handle edge cases**:
   - Skip files that already have dated prefix (avoid re-processing archived plans)
   - Skip `.gitkeep` and other non-plan files
   - Exit gracefully if plan file doesn't match expected patterns

### File Naming Convention

**New format with agent name prefix:**
- Plans: `YYYY-MM-DD-<agent>-<plan-name>.md`
- Transcripts: `YYYY-MM-DD-<agent>-<plan-name>.transcript.txt`

**Examples:**
- `2026-01-27-cursor-add-authentication.md`
- `2026-01-27-claude-refactor-logging.md`
- `2026-01-27-cursor-add-authentication.transcript.txt`

### Files to Create/Modify

| File | Action |
|------|--------|
| `.cursor/hooks.json` | Create - hook configuration for Cursor |
| `.cursor/hooks/save-planning-logs-cursor.sh` | Create - main script for Cursor |
| `.claude/hooks/save-planning-logs.sh` | Update - add "claude" prefix to filenames |
| `README.md` | Update - document Cursor support and naming convention |

---

## Verification Plan

### Test Cursor logging:
1. Start Cursor in the project
2. Enter plan mode (Shift+Tab)
3. Create a test plan, click "Save to workspace"
4. Exit plan mode / end session
5. Verify:
   - Plan copied to `agent_logs/plans/YYYY-MM-DD-cursor-<name>.md`
   - Transcript saved to `agent_logs/transcripts/YYYY-MM-DD-cursor-<name>.transcript.txt`
   - Git commit created automatically

### Test Claude Code logging (regression):
1. Start Claude Code in the project
2. Enter plan mode (`\plan`)
3. Create a test plan
4. Exit plan mode
5. Verify:
   - Plan copied to `agent_logs/plans/YYYY-MM-DD-claude-<name>.md`
   - Transcript saved to `agent_logs/transcripts/YYYY-MM-DD-claude-<name>.transcript.txt`
   - Git commit created automatically

---

## Notes

- **Detection method**: `afterFileEdit` hook - only triggers when plan files are created/edited
- **Auto-commit**: Enabled - will commit plans and transcripts automatically
- **Limitation**: If Cursor writes plans to `~/.cursor/plans/` (global) instead of `.cursor/plans/` (workspace), the hook may not trigger. User should click "Save to workspace" when creating plans, or we can add a fallback check for the global directory.
