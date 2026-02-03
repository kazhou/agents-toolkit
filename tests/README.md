# Tests

This directory contains tests for the agents-toolkit project.

## Test Suite

### Planning Session Tests (`test_planning_session.py`)

Tests the Claude Code planning session workflow, verifying that:

1. **Plan Creation**: Claude can create a plan in `permission_mode="plan"`
2. **ExitPlanMode Hook**: The `save-planning-logs.sh` hook triggers correctly
3. **File Naming**: Plan files follow `YYYY-MM-DD-claude-<heading>.md` convention
4. **Transcript Cleaning**: JSONL transcripts are converted to readable text
5. **Directory Structure**: Files are saved to correct locations

#### Test Classes

| Class | Description |
|-------|-------------|
| `TestPlanningSession` | End-to-end tests for planning workflow |
| `TestHookConfiguration` | Verifies hook setup and configuration |

#### Key Test Cases

- `test_planning_session_creates_files` - Full workflow test
- `test_plan_file_naming_convention` - Naming pattern verification
- `test_settings_json_exists` - Hook configuration check (Stop + SessionEnd)
- `test_hook_script_exists` - Script existence and permissions
- `test_hook_script_checks_for_exitplanmode` - Verifies ExitPlanMode detection
- `test_agent_logs_directories_exist` - Directory structure validation
- `test_claude_cli_available` - Verify Claude CLI is installed

## Running Tests

```bash
# Run configuration tests only (no API needed)
uv run pytest tests/test_planning_session.py::TestHookConfiguration -v

# Run all tests (requires ANTHROPIC_API_KEY)
uv run pytest tests/test_planning_session.py -v

# Run with verbose output and print statements
uv run pytest tests/test_planning_session.py -v -s

# Run a specific test
uv run pytest tests/test_planning_session.py::TestPlanningSession::test_planning_session_creates_files -v -s
```

## Test Dependencies

- `pytest` - Test framework

Install with:
```bash
uv add --dev pytest
```

## File Verification Patterns

The tests verify files are created in these locations:

| File Type | Location | Pattern |
|-----------|----------|---------|
| Active Plan | `~/.claude/plans/` | `<random-name>.md` |
| Saved Plan | `agent_logs/plans/` | `YYYY-MM-DD-claude-<plan-heading>.md` |
| Raw Transcript | `~/.claude/projects/<proj>/` | `<uuid>.jsonl` |
| Cleaned Transcript | `agent_logs/transcripts/` | `YYYY-MM-DD-claude-<plan-heading>.transcript.txt` |

## How It Works

### Subprocess Approach

The tests use `subprocess.run()` to invoke the Claude CLI directly with:

- `--permission-mode plan` - Start in plan mode
- `--dangerously-skip-permissions` - Auto-accept ALL permission prompts
- `--output-format stream-json` - Structured JSONL output for parsing
- `-p <prompt>` - Pass prompt directly on command line

This approach is simpler than the SDK:
- No async/streaming complexity
- No callback functions needed
- Uses CLI exactly as intended
- Full stdout/stderr capture for debugging

### Hook Architecture

The `save-planning-logs.sh` hook is triggered by two events to handle different approval types:

| Event | Trigger | Use Case |
|-------|---------|----------|
| `Stop` | Claude finishes responding | "Accept edits" approval |
| `SessionEnd` (matcher: `"clear"`) | Session ends with clear | "Clear context" approval |

The hook checks the transcript for `ExitPlanMode` tool call (not `permission_mode`, which changes before hooks fire).

The tests verify:
1. Both Stop and SessionEnd hooks are configured in `.claude/settings.json`
2. SessionEnd hook has `"clear"` matcher
3. Hook script exists and is executable
4. Hook script checks for ExitPlanMode in transcript
5. Output files are created in expected locations
6. File content matches expected format

### Example Test Output

```
$ uv run pytest tests/test_planning_session.py::TestPlanningSession::test_planning_session_creates_files -v -s

tests/test_planning_session.py::TestPlanningSession::test_planning_session_creates_files

=== Claude CLI Result ===
Exit code: 0
Session ID: abc12345-6789-...
Tool calls: ['Write', 'ExitPlanMode']
ExitPlanMode called: True
Recent Claude plans: [PosixPath('/home/user/.claude/plans/abc123.md')]
Saved plans in agent_logs: [PosixPath('agent_logs/plans/2026-02-03-claude-hello-world-plan.md')]
Saved transcripts: [PosixPath('agent_logs/transcripts/2026-02-03-claude-hello-world-plan.transcript.txt')]

=== All verifications passed ===
Plan saved to: agent_logs/plans/2026-02-03-claude-hello-world-plan.md
Transcript saved to: agent_logs/transcripts/2026-02-03-claude-hello-world-plan.transcript.txt
PASSED
```

## Troubleshooting

### Tests Skipped: API Unavailable

If you see `SKIPPED (API unavailable: ...)`, check:
- `ANTHROPIC_API_KEY` environment variable is set
- API key has sufficient credits
- No rate limiting is in effect

The tests automatically skip when API billing/auth issues are detected.

### Tests Fail: Claude CLI Not Found

Run the configuration tests first:
```bash
uv run pytest tests/test_planning_session.py::TestHookConfiguration::test_claude_cli_available -v
```

Ensure Claude CLI is installed and in your PATH:
```bash
claude --version
```

### Tests Fail: No Plan Created

- Verify `ANTHROPIC_API_KEY` is set and has credits
- Check Claude CLI is installed: `claude --version`
- Ensure `.claude/settings.json` exists with hook configuration

### Tests Fail: No Saved Files

- Check hook script is executable: `chmod +x .claude/hooks/save-planning-logs.sh`
- Verify `agent_logs/plans/` and `agent_logs/transcripts/` directories exist
- Check hook script for errors: run manually with test input

### Timeout Issues

- The default timeout is 180 seconds (3 minutes)
- Increase if your API responses are slow
- Check network connectivity for API calls
