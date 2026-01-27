# Modify Logging to Preserve Plan Editing

## Problem
Current hook renames plan files on `ExitPlanMode`, which breaks Claude Code's ability to edit existing plans when re-entering plan mode.

## Solution: Copy Instead of Rename

Keep CC's default plan directory/file intact. On ExitPlanMode, **copy** (not move) the plan to `agent_logs/plans/` with dated naming.

### Behavior
1. CC creates/edits plan in its default location (e.g., `agent_logs/plans/random-name.md`)
2. On ExitPlanMode → copy to `agent_logs/plans/YYYY-MM-DD-heading-name.md`
3. Re-enter plan mode → CC finds and edits the original `random-name.md`
4. Exit again → overwrites the dated copy (if same day + heading)
5. Transcripts saved every time (with incrementing suffix if needed)

### Key Change
- **Before:** `Path(plan_file).rename(new_plan_path)` (moves file)
- **After:** `shutil.copy2(plan_file, new_plan_path)` (copies file)

## Files to Modify
- `.claude/hooks/save-planning-logs.sh` - Change rename to copy (~line 254)

## Implementation

In the Python section, change:
```python
# Line ~253-256, replace:
if plan_file != str(new_plan_path):
    Path(plan_file).rename(new_plan_path)
    print(f"Saved plan: {new_plan_path}")
    files_to_commit.append(str(new_plan_path))

# With:
import shutil
if plan_file != str(new_plan_path):
    shutil.copy2(plan_file, new_plan_path)
    print(f"Copied plan to: {new_plan_path}")
    files_to_commit.append(str(new_plan_path))
```

Also add `import shutil` at the top of the Python block.

## Verification
1. Enter plan mode, create a plan
2. Exit plan mode → check both original AND dated copy exist
3. Re-enter plan mode → verify CC edits the original file
4. Make changes, exit again → verify dated copy is updated
5. Verify transcripts saved with unique names
6. Verify git commits include copies
