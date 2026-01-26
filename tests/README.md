# Tests

## Planning Session Logger

### `test-planning-logger.sh`

Tests the planning session logger hook by simulating `ExitPlanMode` being triggered.

**What it tests:**
1. Creates a mock plan file in `~/.claude/plans/`
2. Creates a mock JSONL transcript
3. Runs the hook script with simulated input
4. Verifies:
   - Transcript is converted to clean `.txt` format
   - Plan is copied with correct naming (`YYYY-MM-DD-<plan-name>.md`)
   - Files are git committed

**Run:**
```bash
./tests/test-planning-logger.sh
```

**Expected output:**
- Creates `agent_logs/transcripts/YYYY-MM-DD-<plan-name>.transcript.txt`
- Creates `agent_logs/plans/YYYY-MM-DD-<plan-name>.md`
- Commits changes with message "chore: update planning session logs"
