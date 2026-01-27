# agents-toolkit

Repo for various coding agents scripts, guidelines, and tools. To copy into/reuse in projects.

This is a work in progress!

# Contents

- [AGENTS.md](AGENTS.md): guidelines/preferences for agents. Agent-agnostic (e.g., can be used w/ Claude Code, Cursor, etc.) with allowance for further user modification
  - for Claude Code: `cp AGENTS.md ~/.claude/CLAUDE.md` (for global) or `cp AGENTS.md ./CLAUDE.md` (for project)
  - for Cursor: `cp AGENTS.md ~/.cursor/rules/`
- [Planning Session Logger](#planning-session-logger): automatically saves planning mode transcripts and plan files

---

## Planning Session Logger

Automatically saves planning session transcripts and plan files to `agent_logs/` when exiting plan mode. Supports both **Claude Code** and **Cursor**.

### Features

- Plan files copied to `agent_logs/plans/YYYY-MM-DD-<agent>-<heading-name>.md`
- Original plan stays in agent's default location for re-editing
- JSONL transcripts cleaned to readable text
- Auto-commits saved plans to git (not transcripts, in case of sensitive info)
- Re-entering plan mode allows editing the same plan

### File Naming Convention

Files include the agent name for easy identification:
- Plans: `YYYY-MM-DD-<agent>-<plan-name>.md`
- Transcripts: `YYYY-MM-DD-<agent>-<plan-name>.transcript.txt`

Examples:
- `2026-01-27-claude-add-authentication.md`
- `2026-01-27-cursor-refactor-api.md`

### Setup for New Projects

Copy agent config directories and create the agent_logs structure:

```bash
# For Claude Code
cp -r .claude/ /path/to/new-project/

# For Cursor
cp -r .cursor/ /path/to/new-project/

# Create agent_logs structure
mkdir -p /path/to/new-project/agent_logs/{plans,transcripts}

# Add transcripts to .gitignore (may contain sensitive info)
echo "agent_logs/transcripts/" >> /path/to/new-project/.gitignore
```

### Directory Structure

```
# Claude Code
~/.claude/plans/             # CC's default location (editable originals)
.claude/
├── settings.json            # Hook config (PostToolUse on ExitPlanMode)
└── hooks/
    └── save-planning-logs.sh

# Cursor
~/.cursor/plans/             # Cursor's global plans (default)
.cursor/plans/               # Workspace plans (after "Save to workspace")
.cursor/
├── hooks.json               # Hook config (afterFileEdit + sessionEnd)
└── hooks/
    └── save-planning-logs-cursor.sh

# Shared output
agent_logs/
├── plans/           # YYYY-MM-DD-<agent>-<plan-name>.md (tracked in git)
└── transcripts/     # YYYY-MM-DD-<agent>-<plan-name>.transcript.txt (gitignored)
```

### How It Works

#### Claude Code
1. CC creates/edits plans in `~/.claude/plans/`
2. When you exit plan mode (`ExitPlanMode`), the hook triggers
3. Hook **copies** plan file to `agent_logs/plans/` with dated name (using first `# Heading`)
4. Hook cleans the JSONL transcript to readable text
5. Both files are auto-committed to git

#### Cursor (not tested yet)
1. Cursor creates plans in `~/.cursor/plans/` (global) or `.cursor/plans/` (workspace)
2. Hooks trigger on:
   - `afterFileEdit` - when plan is saved to workspace (`.cursor/plans/`)
   - `sessionEnd` - fallback for plans in global directory (`~/.cursor/plans/`)
3. Hook **copies** plan file to `agent_logs/plans/` with dated name
4. Hook cleans the transcript (using `transcript_path` from Cursor)
5. Both files are auto-committed to git

**Note:** For best results with Cursor, click "Save to workspace" when creating plans. This triggers the `afterFileEdit` hook immediately. Plans saved only to the global directory will be captured when the session ends.

### Toggle Hooks

To enable/disable Cursor hooks:

```bash
.cursor/toggle-hooks.sh          # Toggle current state
.cursor/toggle-hooks.sh on       # Enable hooks
.cursor/toggle-hooks.sh off      # Disable hooks
.cursor/toggle-hooks.sh status   # Show current state
```

This renames `hooks.json` to `hooks.json.disabled` (and vice versa).


---

# Agent-specific Resources

## Claude Code
- [How Anthropic Uses Claude Code](https://www-cdn.anthropic.com/58284b19e702b49db9302d5b6f135ad8871e7658.pdf)
  - Always save checkpoints (start in clean git state, commit changes, revert if necessary)
  - Starting over often has a higher success rate than trying to fix Claude's mistakes
- UI design plugin: https://github.com/Dammyjay93/interface-design

## Cursor
- [Cursor agents best practices](https://cursor.com/blog/agent-best-practices)
  - Start with plans
  - Sometimes the agent builds something that doesn't match what you wanted. Instead of trying to fix it through follow-up prompts, go back to the plan.
  - Let the agent find context
  - Long conversations can cause the agent to lose focus. After many turns and summarizations, the context accumulates noise and the agent can get distracted or switch to unrelated tasks. If you notice the effectiveness of the agent decreasing, it's time to start a new conversation.
  - When you start a new conversation, use @Past Chats to reference previous work rather than copy-pasting the whole conversation.
  - Create rules as markdown files in `.cursor/rules/`
    - Keep rules focused on the essentials: the commands to run, the patterns to follow, and pointers to canonical examples in your codebase. Reference files instead of copying their contents; this keeps rules short and prevents them from becoming stale as code changes.
  - Skills are defined in SKILL.md files and can include:
    - Custom commands: Reusable workflows triggered with / in the agent input
    - Hooks: Scripts that run before or after agent actions
    - Domain knowledge: Instructions for specific tasks the agent can pull in on demand
  - The agent can process images directly from your prompts. Paste screenshots, drag in design files, or reference image paths.
