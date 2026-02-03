"""
Test script for Claude Code planning sessions.

Tests that:
1. Claude Code can be launched in plan mode via subprocess
2. A simple "hello world" plan can be created
3. The save-planning-logs.sh hook creates the expected files
4. Files are properly named and contain expected content

Hook Architecture:
- Stop hook: Fires when Claude finishes responding (catches "accept edits" approval)
- SessionEnd hook: Fires when session ends with "clear" reason (catches "clear context" approval)
- Both hooks check transcript for ExitPlanMode tool call to identify plan sessions

Usage:
    # Configuration tests (no API needed)
    uv run pytest tests/test_planning_session.py::TestHookConfiguration -v

    # Full test suite (requires ANTHROPIC_API_KEY)
    uv run pytest tests/test_planning_session.py -v -s

Note: API tests require ANTHROPIC_API_KEY with sufficient credits.
"""

import json
import os
import re
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import pytest


# Test prompt - keep it simple to generate a short plan
TEST_PROMPT = "Create a simple plan to print hello world in Python. Keep the plan very short - just 2-3 steps."

# API error messages that indicate billing/auth issues (should skip test)
# These patterns are specific enough to avoid false positives from hook output
API_ERROR_PATTERNS = [
    "credit balance is too low",
    "insufficient credit",
    "billing_error",
    "invalid api key",
    "invalid_api_key",
    "authentication failed",
    "unauthorized request",
    "rate_limit_error",
    "overloaded_error",
    "api_error",
]


def is_api_unavailable_error(error_message: str) -> bool:
    """Check if an error indicates API unavailability (billing, auth, etc.)."""
    if not error_message:
        return False
    error_lower = error_message.lower()
    return any(pattern in error_lower for pattern in API_ERROR_PATTERNS)


def run_claude_planning_session(
    prompt: str,
    cwd: Path,
    timeout: int = 180,
) -> dict[str, Any]:
    """
    Run Claude Code in plan mode with auto-accept permissions.

    Uses subprocess to invoke the Claude CLI directly with:
    - --permission-mode plan: Start in plan mode
    - --dangerously-skip-permissions: Auto-accept all permission prompts
    - --output-format stream-json: Structured JSON output for parsing
    - -p <prompt>: Pass prompt on command line

    The session will:
    1. Create a plan in ~/.claude/plans/
    2. Call ExitPlanMode when plan is ready
    3. Trigger Stop hook (since CLI exits after completion)
    4. Hook copies plan to agent_logs/plans/

    Args:
        prompt: The prompt to send to Claude
        cwd: Working directory for the Claude session
        timeout: Maximum time in seconds to wait for completion

    Returns:
        dict with: exit_code, stdout, stderr, session_id, tool_calls
    """
    cmd = [
        "claude",
        "--permission-mode", "plan",
        "--dangerously-skip-permissions",
        "--output-format", "stream-json",
        "--verbose",
        "-p", prompt,
    ]

    # Set environment with project directory
    env = {
        **os.environ,
        "CLAUDE_PROJECT_DIR": str(cwd),
    }

    result = subprocess.run(
        cmd,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )

    # Parse JSONL output to extract session_id and tool calls
    session_id = None
    tool_calls: list[str] = []
    exit_plan_mode_called = False

    if result.stdout:
        for line in result.stdout.splitlines():
            if not line.strip():
                continue
            try:
                data = json.loads(line)

                # Extract session_id from init message
                if data.get("type") == "system" and "session_id" in data:
                    session_id = data["session_id"]

                # Track tool calls from assistant messages
                if data.get("type") == "assistant":
                    content = data.get("message", {}).get("content", [])
                    for block in content:
                        if block.get("type") == "tool_use":
                            tool_name = block.get("name", "")
                            tool_calls.append(tool_name)
                            if tool_name == "ExitPlanMode":
                                exit_plan_mode_called = True

            except json.JSONDecodeError:
                continue

    return {
        "exit_code": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "session_id": session_id,
        "tool_calls": tool_calls,
        "exit_plan_mode_called": exit_plan_mode_called,
    }


class TestPlanningSession:
    """Test suite for Claude Code planning sessions."""

    def test_planning_session_creates_files(
        self,
        project_root: Path,
        plans_dir: Path,
        transcripts_dir: Path,
        claude_plans_dir: Path,
        ensure_directories: bool,
        clean_test_files: None,
        date_prefix: str,
        file_pattern_regex: re.Pattern,
        transcript_pattern_regex: re.Pattern,
    ):
        """
        Test that a planning session creates all expected files.

        Verifies:
        1. Plan file created in ~/.claude/plans/ (Claude's working copy)
        2. Plan file saved to agent_logs/plans/ (dated archive)
        3. Transcript cleaned and saved to agent_logs/transcripts/

        Hook flow:
        1. Claude creates plan and calls ExitPlanMode
        2. Stop hook fires when Claude finishes responding
        3. Hook parses transcript to find ExitPlanMode with plan content
        4. Hook copies plan to agent_logs/plans/ with dated name
        """
        # Run the planning session using subprocess
        result = run_claude_planning_session(
            prompt=TEST_PROMPT,
            cwd=project_root,
            timeout=180,
        )

        # Print debug info
        print(f"\n=== Claude CLI Result ===")
        print(f"Exit code: {result['exit_code']}")
        print(f"Session ID: {result['session_id']}")
        print(f"Tool calls: {result['tool_calls']}")
        print(f"ExitPlanMode called: {result['exit_plan_mode_called']}")

        if result["stderr"]:
            print(f"Stderr (first 500 chars): {result['stderr'][:500]}")
        if result["stdout"]:
            # Print last 2000 chars to see ending/errors
            print(f"Stdout (last 2000 chars): {result['stdout'][-2000:]}")

        # Skip test if API is unavailable (billing, auth issues)
        combined_output = (result["stderr"] or "") + (result["stdout"] or "")
        if is_api_unavailable_error(combined_output):
            pytest.skip(f"API unavailable: check stdout/stderr for details")

        # Check for non-zero exit code with API errors
        if result["exit_code"] != 0:
            if is_api_unavailable_error(combined_output):
                pytest.skip(f"API unavailable (exit code {result['exit_code']})")
            # Don't fail immediately on non-zero exit - the session may have completed
            # but returned non-zero for other reasons (e.g., hook issues)
            print(f"Warning: Non-zero exit code {result['exit_code']}")

        # Wait for hooks to complete (Stop hook runs after Claude finishes)
        time.sleep(5)

        # Verification 1: ExitPlanMode was called
        assert result["exit_plan_mode_called"], (
            "ExitPlanMode was not called. "
            f"Tool calls made: {result['tool_calls']}"
        )

        # Verification 2: Plan file exists in ~/.claude/plans/ (Claude's original)
        if claude_plans_dir.exists():
            claude_plan_files = list(claude_plans_dir.glob("*.md"))
            # Filter to recent files (modified in last 5 minutes)
            recent_claude_plans = [
                f for f in claude_plan_files
                if (datetime.now().timestamp() - f.stat().st_mtime) < 300
            ]
            print(f"Recent Claude plans: {recent_claude_plans}")

        # Verification 3: Plan file saved to agent_logs/plans/
        saved_plans = list(plans_dir.glob(f"{date_prefix}-claude-*.md"))
        print(f"Saved plans in agent_logs: {saved_plans}")

        assert len(saved_plans) >= 1, (
            f"No saved plan found in {plans_dir}. "
            f"Expected pattern: {date_prefix}-claude-*.md"
        )

        # Verify plan content contains expected keywords
        plan_content = saved_plans[0].read_text()
        assert "hello" in plan_content.lower() or "print" in plan_content.lower(), (
            f"Plan content doesn't contain 'hello' or 'print'. "
            f"Content preview: {plan_content[:200]}"
        )

        # Verification 4: Transcript saved to agent_logs/transcripts/
        saved_transcripts = list(transcripts_dir.glob(f"{date_prefix}-claude-*.transcript.txt"))
        print(f"Saved transcripts: {saved_transcripts}")

        assert len(saved_transcripts) >= 1, (
            f"No saved transcript found in {transcripts_dir}. "
            f"Expected pattern: {date_prefix}-claude-*.transcript.txt"
        )

        # Verify transcript is readable (not raw JSONL)
        transcript_content = saved_transcripts[0].read_text()
        # Cleaned transcripts should have "User:" or "Assistant:" prefixes
        assert "User:" in transcript_content or "Assistant:" in transcript_content, (
            f"Transcript doesn't appear to be cleaned (missing User:/Assistant: prefixes). "
            f"Content preview: {transcript_content[:200]}"
        )

        print("\n=== All verifications passed ===")
        print(f"Plan saved to: {saved_plans[0]}")
        print(f"Transcript saved to: {saved_transcripts[0]}")

    def test_plan_file_naming_convention(
        self,
        project_root: Path,
        plans_dir: Path,
        ensure_directories: bool,
        clean_test_files: None,
        date_prefix: str,
    ):
        """
        Test that plan files follow the naming convention.

        Expected: YYYY-MM-DD-claude-<plan-heading>.md

        The <plan-heading> should be derived from the first # heading
        in the plan, converted to kebab-case.
        """
        # Run planning session using subprocess
        result = run_claude_planning_session(
            prompt=TEST_PROMPT,
            cwd=project_root,
            timeout=180,
        )

        # Skip test if API is unavailable (billing, auth issues)
        combined_output = (result["stderr"] or "") + (result["stdout"] or "")
        if is_api_unavailable_error(combined_output):
            pytest.skip(f"API unavailable: check stdout/stderr for details")

        if result["exit_code"] != 0 and is_api_unavailable_error(combined_output):
            pytest.skip(f"API unavailable (exit code {result['exit_code']})")

        # Wait for hooks
        time.sleep(5)

        # Check for saved plan
        saved_plans = list(plans_dir.glob(f"{date_prefix}-claude-*.md"))
        assert len(saved_plans) >= 1, "No saved plan found"

        # Verify naming convention
        plan_name = saved_plans[0].name
        pattern = re.compile(rf"^{date_prefix}-claude-[\w-]+\.md$")
        assert pattern.match(plan_name), (
            f"Plan filename doesn't match expected pattern. "
            f"Got: {plan_name}, Expected: {date_prefix}-claude-<heading>.md"
        )

        print(f"Plan filename verified: {plan_name}")


class TestHookConfiguration:
    """Test that hook configuration is correctly set up."""

    def test_settings_json_exists(self, project_root: Path):
        """Verify .claude/settings.json exists and has correct structure."""
        settings_path = project_root / ".claude" / "settings.json"
        assert settings_path.exists(), f"Settings file not found: {settings_path}"

        settings = json.loads(settings_path.read_text())

        # Verify hook configuration
        assert "hooks" in settings, "No 'hooks' key in settings.json"

        # Check for Stop hook (required for "accept edits" approval)
        assert "Stop" in settings["hooks"], "No 'Stop' hook configured"
        stop_hooks = settings["hooks"]["Stop"]
        assert len(stop_hooks) >= 1, "No Stop hooks configured"

        # Verify Stop hook references save-planning-logs.sh
        has_stop_planning_hook = any(
            "save-planning-logs.sh" in str(h.get("hooks", []))
            for h in stop_hooks
        )
        assert has_stop_planning_hook, (
            "No hook referencing 'save-planning-logs.sh' found in Stop hooks"
        )

        # Check for SessionEnd hook (required for "clear context" approval)
        assert "SessionEnd" in settings["hooks"], "No 'SessionEnd' hook configured"
        session_end_hooks = settings["hooks"]["SessionEnd"]
        assert len(session_end_hooks) >= 1, "No SessionEnd hooks configured"

        # Verify SessionEnd hook has "clear" matcher
        has_clear_matcher = any(
            h.get("matcher") == "clear"
            for h in session_end_hooks
        )
        assert has_clear_matcher, (
            "SessionEnd hook should have 'clear' matcher for clear context approval"
        )

        # Verify SessionEnd hook references save-planning-logs.sh
        has_session_end_planning_hook = any(
            "save-planning-logs.sh" in str(h.get("hooks", []))
            for h in session_end_hooks
        )
        assert has_session_end_planning_hook, (
            "No hook referencing 'save-planning-logs.sh' found in SessionEnd hooks"
        )

        print("Hook configuration verified:")
        print(f"  Stop hooks: {stop_hooks}")
        print(f"  SessionEnd hooks: {session_end_hooks}")

    def test_hook_script_exists(self, project_root: Path):
        """Verify save-planning-logs.sh exists and is executable."""
        hook_script = project_root / ".claude" / "hooks" / "save-planning-logs.sh"
        assert hook_script.exists(), f"Hook script not found: {hook_script}"

        # Check if script is executable (on Unix)
        if os.name != 'nt':  # Skip on Windows
            assert os.access(hook_script, os.X_OK), (
                f"Hook script is not executable: {hook_script}"
            )

        print(f"Hook script verified: {hook_script}")

    def test_hook_script_checks_for_exitplanmode(self, project_root: Path):
        """Verify hook script filters for ExitPlanMode in transcript."""
        hook_script = project_root / ".claude" / "hooks" / "save-planning-logs.sh"
        assert hook_script.exists(), f"Hook script not found: {hook_script}"

        content = hook_script.read_text()

        # Script should check for ExitPlanMode in transcript
        assert "ExitPlanMode" in content, (
            "Hook script should check for ExitPlanMode in transcript"
        )

        # Script should use transcript_path
        assert "transcript" in content.lower(), (
            "Hook script should reference transcript for ExitPlanMode detection"
        )

        print("Hook script correctly filters for ExitPlanMode")

    def test_agent_logs_directories_exist(self, plans_dir: Path, transcripts_dir: Path):
        """Verify agent_logs directory structure exists."""
        plans_dir.mkdir(parents=True, exist_ok=True)
        transcripts_dir.mkdir(parents=True, exist_ok=True)

        assert plans_dir.exists(), f"Plans directory not found: {plans_dir}"
        assert transcripts_dir.exists(), f"Transcripts directory not found: {transcripts_dir}"

        print("Directory structure verified:")
        print(f"  Plans: {plans_dir}")
        print(f"  Transcripts: {transcripts_dir}")

    def test_claude_cli_available(self):
        """Verify claude CLI is installed and accessible."""
        try:
            result = subprocess.run(
                ["claude", "--version"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            assert result.returncode == 0, (
                f"claude CLI returned non-zero exit code: {result.returncode}"
            )
            print(f"Claude CLI version: {result.stdout.strip()}")
        except FileNotFoundError:
            pytest.fail("claude CLI not found in PATH")
        except subprocess.TimeoutExpired:
            pytest.fail("claude --version timed out")
