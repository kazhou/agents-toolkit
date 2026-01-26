"""Interactive session for CHAI assistant."""

import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

import click
import openai

from .config import load_config, get_space_folder, get_implementation_logs_path
from .recommender import get_recommendations, ScoredTask
from .todo import TodoItem, TodoManager, create_implementation_log


def load_preferences() -> str:
    """Load preferences.md if it exists.

    Preferences are always included in prompts.
    """
    prefs_file = get_space_folder() / "preferences.md"
    if prefs_file.exists():
        try:
            return prefs_file.read_text()
        except Exception:
            pass
    return ""


def check_relevance_ai(task_text: str, resource_name: str, resource_content: str) -> bool:
    """Check if a resource is relevant to a task using GPT-5.1 nano.

    Returns True if the resource is semantically relevant to the task.
    """
    config = load_config()
    api_key = config.get("OPENROUTER_API_KEY")

    if not api_key:
        return None  # Signal to fall back to keyword matching

    client = openai.OpenAI(
        api_key=api_key,
        base_url="https://openrouter.ai/api/v1",
    )

    prompt = f"""Could this resource be useful for the task? Be inclusive - if there's any possible connection, answer "yes".
Answer only "yes" or "no".

Task: {task_text}

Resource name: {resource_name}
Resource content (first 500 chars): {resource_content[:500]}"""

    try:
        response = client.chat.completions.create(
            model="qwen/qwen3-4b:free",
            messages=[{"role": "user", "content": prompt + " /no_think"}],
            max_tokens=20,
        )
        answer = response.choices[0].message.content or ""
        # Strip any <think>...</think> tags that Qwen might output despite /no_think
        answer = re.sub(r'<think>.*?</think>', '', answer, flags=re.DOTALL)
        answer = answer.strip().lower()
        # Check if "yes" appears in the cleaned response
        return "yes" in answer and "no" not in answer
    except Exception:
        return None  # No API key or error - resource won't be included


def extract_paths_from_text(text: str) -> list[str]:
    """Extract directory/file paths from text."""
    import re
    # Match absolute paths (starting with /)
    path_pattern = re.compile(r'(/[\w/.-]+)')
    paths = path_pattern.findall(text)

    # Filter to existing directories
    valid_dirs = []
    for p in paths:
        path = Path(p)
        if path.exists():
            if path.is_dir():
                valid_dirs.append(str(path))
            elif path.is_file():
                valid_dirs.append(str(path.parent))

    return list(set(valid_dirs))


def load_relevant_resources(task_text: str) -> tuple[str, list[str]]:
    """Load resources that might be relevant to the task.

    Uses AI-based semantic matching if OPENAI_API_KEY is configured,
    otherwise falls back to keyword matching.

    Returns:
        Tuple of (resource_content, list_of_paths_to_add)
    """
    resources_dir = get_space_folder() / "resources"
    if not resources_dir.exists():
        return "", []

    relevant_content = []
    all_paths = []

    for resource_file in resources_dir.glob("*.md"):
        try:
            content = resource_file.read_text()

            # Use AI-based matching
            is_relevant = check_relevance_ai(task_text, resource_file.stem, content)

            if is_relevant:
                relevant_content.append(f"## Context from {resource_file.name}\n{content}")
                all_paths.extend(extract_paths_from_text(content))
        except Exception:
            pass

    return "\n\n".join(relevant_content), list(set(all_paths))


def display_recommendations(recommendations: list[ScoredTask]) -> None:
    """Display task recommendations to the user."""
    if not recommendations:
        click.echo("No pending tasks found.")
        return

    click.echo("\nRecommended tasks:")
    click.echo("-" * 40)

    for i, rec in enumerate(recommendations, 1):
        item = rec.item
        click.echo(f"{i}. [{item.slug}] {item.display_text}")
        click.echo(f"   Score: {rec.score:.2f} - {rec.reason}")

    click.echo("-" * 40)


def build_prompt(task_text: str, planning: bool = False) -> tuple[str, list[str]]:
    """Build the prompt with preferences and resources.

    Returns:
        Tuple of (prompt_text, list_of_paths_to_add)
    """
    # Load preferences (always included)
    preferences = load_preferences()
    prefs_section = ""
    if preferences:
        prefs_section = f"\n\n# User Preferences\n{preferences}\n"

    # Load relevant resources
    resources, paths = load_relevant_resources(task_text)
    resources_section = ""
    if resources:
        resources_section = f"\n\n# Relevant Context\n{resources}\n"

    if planning:
        prompt = f"""I need help planning this task: {task_text}
{prefs_section}{resources_section}
This is a new type of task. Please:
1. Analyze what information is needed
2. Break it down into smaller, concrete steps
3. Suggest starting with the smallest possible first step
4. Ask clarifying questions if anything is unclear

Be conservative - start small and verify the approach works before scaling up."""
    else:
        prompt = f"""Please help me complete this task: {task_text}
{prefs_section}{resources_section}
Work on this task step by step. If you need any clarification, ask me."""

    return prompt, paths


def clean_transcript(transcript_path: Path) -> None:
    """Clean up a terminal transcript file.

    Removes ANSI color codes and deduplicates repeated neighboring lines.
    Overwrites the original file with cleaned content.
    """
    import re

    if not transcript_path.exists():
        return

    content = transcript_path.read_text(errors="replace")

    # Remove ANSI escape codes (colors, cursor movement, etc.)
    ansi_pattern = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]|\x1b\].*?\x07|\x1b[PX^_].*?\x1b\\')
    content = ansi_pattern.sub('', content)

    # Remove other control characters except newlines and tabs
    content = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', content)

    # Deduplicate repeated neighboring lines
    lines = content.split('\n')
    deduped = []
    prev_line = None
    for line in lines:
        stripped = line.rstrip()
        if stripped != prev_line:
            deduped.append(line)
            prev_line = stripped

    transcript_path.write_text('\n'.join(deduped))


def copy_to_clipboard(text: str) -> bool:
    """Copy text to clipboard. Returns True if successful."""
    try:
        subprocess.run(["pbcopy"], input=text.encode(), check=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


def save_planning_log(item: TodoItem, prompt: str) -> Path:
    """Save the planning prompt to a log file.

    Returns the path to the log file.
    """
    from datetime import datetime

    logs_path = get_implementation_logs_path()
    logs_path.mkdir(parents=True, exist_ok=True)

    date_str = datetime.now().strftime("%Y-%m-%d")
    filename = f"{date_str}_plan_{item.slug}.md"
    log_file = logs_path / filename

    content = f"""# Planning: {item.display_text}

Started: {datetime.now().strftime("%Y-%m-%d %H:%M")}

## Prompt Sent to Claude

{prompt}

## Planning Notes

(Add notes here after planning session)

"""

    with open(log_file, "w") as f:
        f.write(content)

    return log_file


def invoke_claude_interactive(item: TodoItem) -> bool:
    """Invoke Claude Code CLI interactively for planning.

    Args:
        item: The TodoItem being planned

    Returns:
        True if successful, False otherwise
    """
    prompt, paths = build_prompt(item.text, planning=True)

    # Save planning log
    log_file = save_planning_log(item, prompt)
    click.echo(f"Planning log: {log_file}")

    # Create a session transcript file
    transcript_file = log_file.with_suffix(".transcript.txt")

    if copy_to_clipboard(prompt):
        click.echo("Prompt copied to clipboard! Just paste (Cmd+V) when Claude starts.")
    else:
        click.echo("\n" + "=" * 50)
        click.echo("COPY THIS PROMPT:")
        click.echo("=" * 50)
        click.echo(prompt)
        click.echo("=" * 50)

    # Build claude command with --add-dir for each path
    claude_cmd = ["claude"]
    for p in paths:
        claude_cmd.extend(["--add-dir", p])

    if paths:
        click.echo(f"Directories added: {', '.join(paths)}")

    click.echo(f"Session will be recorded to: {transcript_file}\n")

    # Build environment with NO_COLOR and GITHUB_TOKEN
    import os
    env = os.environ.copy()
    env["NO_COLOR"] = "1"
    config = load_config()
    if config.get("GITHUB_TOKEN"):
        env["GITHUB_TOKEN"] = config["GITHUB_TOKEN"]

    try:
        # Use script to record the terminal session
        # macOS: script -q <output> <command> <args...>
        # Linux: script -q <output> -c "<command>"
        import platform
        if platform.system() == "Linux":
            # Linux requires -c flag with command as a single string
            cmd_string = " ".join(claude_cmd)
            script_cmd = ["script", "-q", str(transcript_file), "-c", cmd_string]
        else:
            # macOS syntax
            script_cmd = ["script", "-q", str(transcript_file)] + claude_cmd
        result = subprocess.run(script_cmd, env=env)

        # Clean and add reference to transcript file in the log
        if transcript_file.exists():
            clean_transcript(transcript_file)
            with open(log_file, "a") as f:
                f.write(f"\n## Session Transcript\n\nSee: {transcript_file}\n")

        return result.returncode == 0
    except FileNotFoundError:
        click.echo("Claude CLI not found. Please install it first.")
        return False
    except Exception as e:
        click.echo(f"Error invoking Claude: {e}")
        return False


def invoke_claude_background(task_text: str) -> None:
    """Invoke Claude Code CLI in background for task execution.

    Starts Claude in a new terminal window so chai can continue.
    """
    prompt, paths = build_prompt(task_text, planning=False)

    if copy_to_clipboard(prompt):
        click.echo("\nPrompt copied to clipboard!")
    else:
        click.echo("\n" + "=" * 50)
        click.echo("COPY THIS PROMPT:")
        click.echo("=" * 50)
        click.echo(prompt)
        click.echo("=" * 50)

    # Build claude command with --add-dir for each path and env vars
    config = load_config()
    env_prefix = "NO_COLOR=1"
    if config.get("GITHUB_TOKEN"):
        env_prefix += f" GITHUB_TOKEN='{config['GITHUB_TOKEN']}'"

    claude_cmd = f"{env_prefix} claude"
    for p in paths:
        claude_cmd += f" --add-dir '{p}'"

    if paths:
        click.echo(f"Directories added: {', '.join(paths)}")

    try:
        # Open Claude in a new terminal window (macOS)
        apple_script = f'''
        tell application "Terminal"
            do script "{claude_cmd}"
            activate
        end tell
        '''
        subprocess.Popen(["osascript", "-e", apple_script])
        click.echo("Claude started in new terminal. Paste (Cmd+V) to begin.\n")
    except Exception as e:
        click.echo(f"Could not start new terminal: {e}")
        click.echo(f"Run '{claude_cmd}' manually in another terminal and paste the prompt.")


def handle_task(manager: TodoManager, slug: str, planning: bool = False) -> None:
    """Handle working on a specific task."""
    item = manager.resolve(slug)
    if not item:
        click.echo(f"Task '{slug}' not found.")
        return

    click.echo(f"\nWorking on: {item.display_text}")

    if planning:
        # Planning mode: interactive, blocks until done
        click.echo("Entering planning mode...")
        click.echo()
        success = invoke_claude_interactive(item)
        click.echo()

        if success:
            if click.confirm("Mark task as done?"):
                notes = click.prompt("Any notes about the implementation?", default="")
                manager.mark_done(item.id, notes=notes)
                click.echo(f"Completed: {item.display_text}")

                feedback = click.prompt(
                    "How did this go? (good/ok/bad or skip)",
                    default="skip",
                )
                if feedback != "skip":
                    click.echo(f"Feedback recorded: {feedback}")
        else:
            click.echo("Task execution had issues.")
    else:
        # Do mode: starts in background, chai continues
        click.echo("Starting task in new terminal...")
        invoke_claude_background(item.text)
        click.echo(f"When done, run: chai done {item.slug}")


def run_session() -> None:
    """Run the interactive CHAI session."""
    click.echo("CHAI Interactive Session")
    click.echo("=" * 40)

    manager = TodoManager()
    manager.load()

    config = load_config()
    rec_count = config.get("recommendations_count", 3)

    # Show initial recommendations
    recommendations = get_recommendations(manager, count=rec_count)
    display_recommendations(recommendations)

    click.echo("\nCommands:")
    click.echo("  <number>  - Work on recommended task")
    click.echo("  do <slug> - Work on specific task")
    click.echo("  plan <slug> - Plan a vague task")
    click.echo("  done <slug> - Mark task as done")
    click.echo("  list      - Show all tasks")
    click.echo("  more      - Show more recommendations")
    click.echo("  quit      - Exit session")
    click.echo()

    while True:
        try:
            cmd = click.prompt("chai", default="").strip()
        except (EOFError, KeyboardInterrupt):
            click.echo("\nGoodbye!")
            break

        if not cmd:
            continue

        parts = cmd.split(maxsplit=1)
        action = parts[0].lower()
        arg = parts[1] if len(parts) > 1 else ""

        if action in ("quit", "exit", "q"):
            click.echo("Goodbye!")
            break

        elif action == "list":
            items = manager.filter(done=False)
            for item in items:
                click.echo(f"[{item.slug}] {item.display_text}")

        elif action == "more":
            rec_count += 3
            recommendations = get_recommendations(manager, count=rec_count)
            display_recommendations(recommendations)

        elif action == "do" and arg:
            handle_task(manager, arg, planning=False)
            # Refresh recommendations after completing
            recommendations = get_recommendations(manager, count=rec_count)
            display_recommendations(recommendations)

        elif action == "plan" and arg:
            handle_task(manager, arg, planning=True)

        elif action == "done" and arg:
            item = manager.resolve(arg)
            if not item:
                click.echo(f"Task '{arg}' not found.")
            else:
                notes = click.prompt("Any notes?", default="")
                manager.mark_done(item.id, notes=notes)
                click.echo(f"Completed: {item.display_text}")
                if item.recurrence:
                    click.echo(f"Recurring task - new instance created with next due date.")
                # Refresh
                manager.load()
                recommendations = get_recommendations(manager, count=rec_count)
                display_recommendations(recommendations)

        elif action.isdigit():
            idx = int(action) - 1
            if 0 <= idx < len(recommendations):
                handle_task(manager, recommendations[idx].item.slug, planning=False)
                # Refresh
                manager.load()
                recommendations = get_recommendations(manager, count=rec_count)
                display_recommendations(recommendations)
            else:
                click.echo(f"Invalid number. Choose 1-{len(recommendations)}")

        else:
            click.echo(f"Unknown command: {cmd}")
            click.echo("Type 'quit' to exit or a number to select a task.")
