# agents-toolkit

Repo for various coding agents scripts, guidelines, and tools. To copy into/reuse in projects.

This is a work in progress!

# Contents

- **Agent Guidelines**
  - [AGENTS.md](AGENTS.md): Cross-platform guidelines for coding agents (Cursor, Copilot, Codex, etc.)
  - [CLAUDE.md](CLAUDE.md): Claude Code-specific version with additional CC features (compaction preservation, skill references)
  - Setup:
    - Claude Code: Already uses `CLAUDE.md` automatically (project-level)
    - Cursor: `cp AGENTS.md ~/.cursor/rules/`
    - Global Claude Code: `cp CLAUDE.md ~/.claude/CLAUDE.md`
- **Claude Code Skills** (see [Skills section](#claude-code-skills))
  - `/update-docs` - Update README and LOG.md after completing work
  - `/fix-issue [number]` - Implement a GitHub issue using TDD
- [Planning Session Logger](#planning-session-logger): automatically saves planning mode transcripts and plan files
- [Documentation Reminder Hook (CC)](#documentation-hook-for-cc): doc-reminder hook for Write/Edit
- **Claude Code Notifications** - get notified when Claude needs input

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
├── settings.json            # Hook config (Stop + SessionEnd hooks)
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
2. When you approve a plan, hooks trigger based on approval type:
   - **Accept edits**: `Stop` hook fires when Claude finishes responding
   - **Clear context**: `SessionEnd` hook fires with `reason: "clear"`
3. Hook parses the session transcript to find `ExitPlanMode` tool call
4. Hook **copies** plan content to `agent_logs/plans/` with dated name (using first `# Heading`)
5. Hook cleans the JSONL transcript to readable text
6. Plan file is auto-committed to git (transcripts are gitignored)

**Supported workflows:**
- `/plan` command
- Shift+Tab to enter plan mode mid-session
- Both "accept edits" and "clear context" approval options

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


## Documentation Hook for CC

Add to `~/.claude/settings.json` (global) or `.claude/settings.json` (local)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Remember: Update agent_logs/LOG.md and README.md if needed'",
            "timeout": 5
          }
        ]
      }
    ]
  }
}    
```

---

## Claude Code Skills

Custom skills for Claude Code workflows. Skills are invoked with `/skill-name` in the chat.

### Available Skills

| Skill | Description | Usage |
|-------|-------------|-------|
| `/update-docs` | Update documentation after completing work | `/update-docs` |
| `/fix-issue` | Implement a GitHub issue using TDD | `/fix-issue 123` |

### Setup for New Projects

Copy the skills directory to your project:

```bash
cp -r .claude/skills/ /path/to/new-project/.claude/skills/
```

Or copy to personal directory for use across all projects:

```bash
cp -r .claude/skills/* ~/.claude/skills/
```

### Skill Details

#### `/update-docs`

Updates README.md and agent_logs/LOG.md after completing work:
1. Shows recent git changes (`git diff HEAD~5 --stat`)
2. Prepends session summary to agent_logs/LOG.md
3. Updates README.md if functionality changed
4. Commits documentation changes

#### `/fix-issue [number]`

Implements a GitHub issue using Test-Driven Development:
1. Fetches issue details from GitHub (`gh issue view`)
2. Creates feature branch (`feature/<issue-number>`)
3. Writes tests first (TDD) - confirms they fail
4. Implements the fix to pass tests
5. Updates documentation
6. Creates PR (`gh pr create --fill`)

### Creating Custom Skills

Skills live in `.claude/skills/<name>/SKILL.md`:

```yaml
---
name: my-skill
description: What it does and when to use it
disable-model-invocation: true  # Only manual /my-skill invocation
allowed-tools: Read, Write, Edit, Bash(git *)
---

# Instructions for Claude to follow...
```

Key frontmatter options:
- `disable-model-invocation: true` - Prevents auto-invocation; requires `/skill-name`
- `allowed-tools` - Tools Claude can use without permission prompts
- `argument-hint` - Shows in autocomplete (e.g., `[issue-number]`)

See [Claude Code Skills Docs](https://code.claude.com/docs/en/skills) for full reference.



## Claude Code Notifications
 Note: this doesn't seem to work in VSCode/Cursor https://github.com/anthropics/claude-code/issues/11156

Add to `.claude/settings.json`:
```
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude Code needs your attention\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```
---



# Agent-specific Resources

## Claude Code
- [How Anthropic Uses Claude Code](https://www-cdn.anthropic.com/58284b19e702b49db9302d5b6f135ad8871e7658.pdf)
  - Always save checkpoints (start in clean git state, commit changes, revert if necessary)
  - Starting over often has a higher success rate than trying to fix Claude's mistakes
- UI design plugin: https://github.com/Dammyjay93/interface-design
- Security Review for Web Apps Skill: https://github.com/BehiSecc/VibeSec-Skill

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
