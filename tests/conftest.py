"""
Pytest fixtures for Claude Code planning session tests.

Provides fixtures for:
- Project root path
- Temporary test files cleanup
- Directory structure verification
"""

import os
import re
from pathlib import Path
from datetime import datetime
import pytest


# Project root directory (where pyproject.toml lives)
PROJECT_ROOT = Path(__file__).parent.parent.absolute()


@pytest.fixture
def project_root() -> Path:
    """Return the project root directory."""
    return PROJECT_ROOT


@pytest.fixture
def agent_logs_dir(project_root: Path) -> Path:
    """Return the agent_logs directory path."""
    return project_root / "agent_logs"


@pytest.fixture
def plans_dir(agent_logs_dir: Path) -> Path:
    """Return the plans directory path."""
    return agent_logs_dir / "plans"


@pytest.fixture
def transcripts_dir(agent_logs_dir: Path) -> Path:
    """Return the transcripts directory path."""
    return agent_logs_dir / "transcripts"


@pytest.fixture
def claude_plans_dir() -> Path:
    """Return the Claude Code plans directory (~/.claude/plans/)."""
    return Path.home() / ".claude" / "plans"


@pytest.fixture
def ensure_directories(plans_dir: Path, transcripts_dir: Path):
    """Ensure agent_logs directories exist."""
    plans_dir.mkdir(parents=True, exist_ok=True)
    transcripts_dir.mkdir(parents=True, exist_ok=True)
    return True


@pytest.fixture
def clean_test_files(plans_dir: Path, transcripts_dir: Path, claude_plans_dir: Path, date_prefix: str):
    """
    Clean up test-generated files before and after test.

    Only removes TODAY's test files matching *hello* patterns.
    Historical files from previous dates are preserved.
    """
    def cleanup():
        # Only clean TODAY's test files - use date prefix to avoid deleting historical files
        patterns = [f"{date_prefix}*hello*", f"{date_prefix}*hello-world*"]

        for pattern in patterns:
            # Clean agent_logs/plans
            for f in plans_dir.glob(pattern):
                try:
                    f.unlink()
                except OSError:
                    pass

            # Clean agent_logs/transcripts
            for f in transcripts_dir.glob(pattern):
                try:
                    f.unlink()
                except OSError:
                    pass

        # Clean ~/.claude/plans - these are temp files without dates, so use broader pattern
        # but only clean recently modified files (< 5 minutes old)
        if claude_plans_dir.exists():
            import time
            for f in claude_plans_dir.glob("*hello*"):
                try:
                    # Only delete if modified in last 5 minutes (likely test-generated)
                    if time.time() - f.stat().st_mtime < 300:
                        f.unlink()
                except OSError:
                    pass

    # Clean before test
    cleanup()

    yield

    # Clean after test (optional - comment out to inspect files after test)
    # cleanup()


@pytest.fixture
def date_prefix() -> str:
    """Return today's date in YYYY-MM-DD format."""
    return datetime.now().strftime("%Y-%m-%d")


@pytest.fixture
def file_pattern_regex(date_prefix: str) -> re.Pattern:
    """
    Return a regex pattern for matching saved plan files.

    Pattern: YYYY-MM-DD-claude-<plan-name>.md
    """
    return re.compile(rf"^{date_prefix}-claude-[\w-]+\.md$")


@pytest.fixture
def transcript_pattern_regex(date_prefix: str) -> re.Pattern:
    """
    Return a regex pattern for matching saved transcript files.

    Pattern: YYYY-MM-DD-claude-<plan-name>.transcript.txt
    """
    return re.compile(rf"^{date_prefix}-claude-[\w-]+\.transcript\.txt$")
