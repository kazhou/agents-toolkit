# AGENTS.md Review & Claude Code Configuration Recommendations

Based on reviewing `cc_workflow_review.md` against your current setup.

## Current State Summary

**AGENTS.md** - Well-structured with:
- uv package management (good coverage)
- TDD workflow instructions
- Documentation requirements (LOG.md, README updates)
- Branch-per-feature version control

**Existing .claude/ configuration**:
- `settings.json` - PostToolUse hook saves plans on ExitPlanMode
- `hooks/save-planning-logs.sh` - Sophisticated plan/transcript archiver
- `settings.local.json` - WebSearch, pytest permissions

---

## Recommended Changes

### 1. Create CLAUDE.md (Claude Code-Specific)

Per the README, AGENTS.md content gets copied into CLAUDE.md. So CLAUDE.md should contain **all of AGENTS.md** plus additional Claude Code-specific sections:

**Add these sections to the end of CLAUDE.md (after copying AGENTS.md content):**

```markdown
# Claude Code-Specific Guidelines

## Running Commands (CRITICAL)
- **Always use `uv run`** for ALL Python commands:
  - `uv run pytest -v` (not pytest directly)
  - `uv run python script.py` (not python directly)
  - `uv run mypy src/` (not mypy directly)
- Bash commands don't preserve environment between calls
- `source .venv/bin/activate` has NO effect on subsequent commands

## Compaction Preservation
When context is compacted, ALWAYS preserve:
- List of all modified files this session
- Pending documentation updates
- Current task and next steps
- Any failing tests that need attention

## Available Skills
- `/update-docs` - Update README and LOG.md after completing work
- `/fix-issue [number]` - Implement a GitHub issue using TDD
```

**Why separate files?**
- AGENTS.md remains cross-platform (works with Cursor, Copilot, Codex)
- CLAUDE.md is auto-loaded by Claude Code at session start
- CLAUDE.md can include CC-specific sections that don't apply to other tools

### 2. Edits to AGENTS.md

Keep AGENTS.md cross-platform (no Claude-specific instructions). Only clean up formatting:

**Remove redundant activation instruction** (lines 8-9):
```diff
- - Activate the environment:
-   source .venv/bin/activate
```
This is unnecessary and misleading since `uv run` is the correct approach.

**Improve formatting of `uv run` instruction** (line 42):
The current line has excessive whitespace. Clean it up:
```diff
-   -  Instead of:                                                 `source .venv/bin/activate && python script.py` use `uv run python script.py`
+- Instead of `source .venv/bin/activate && python script.py`, use `uv run python script.py`
```

**Note:** The stronger "Running Commands (CRITICAL)" section goes in CLAUDE.md only, since the explanation about bash not preserving environment is Claude Code-specific.

### 3. New Hooks to Add

**A. Documentation Reminder Hook** (PostToolUse on Write/Edit)

Add to `.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "echo '📝 Remember: Update agent_logs/LOG.md and README.md if needed'",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "ExitPlanMode",
        "hooks": [...]  // existing
      }
    ]
  }
}
```

**B. Auto-pytest Hook** (optional - run tests after Python edits)

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "command",
      "command": "jq -r '.tool_input.file_path // empty' | { read fp; if [ -n \"$fp\" ] && echo \"$fp\" | grep -qE '\\.py$'; then uv run pytest -x -q 2>&1 | head -20; fi; }",
      "timeout": 60
    }
  ]
}
```

**C. SessionStart Hook** (optional - context reminder)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Check agent_logs/LOG.md for recent session context'"
          }
        ]
      }
    ]
  }
}
```

### 4. Recommended Skills

**Note:** Skills replaced slash commands. They live in `.claude/skills/<name>/SKILL.md` and support bundled scripts, templates, and auto-invocation.

**Location:** Create in project (`.claude/skills/`) as templates. Copy to `~/.claude/skills/` for use in other projects.

**Create `.claude/skills/update-docs/SKILL.md`:**
```yaml
---
name: update-docs
description: Update documentation after completing work. Use when finishing a coding session or when asked to update docs.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash(git *)
---

# Documentation Update

1. Run `git diff HEAD~5 --stat` to see recent changes
2. Prepend to agent_logs/LOG.md:
   ```
   ## [DATE] - Session Summary
   ### Changes Made
   - List each change
   ### Files Modified
   - path/to/file.py - description
   ```
3. Update README.md if functionality changed
4. Commit: `git add README.md agent_logs/LOG.md && git commit -m "docs: update documentation"`


**Create `.claude/skills/fix-issue/SKILL.md`:**
```yaml
---
name: fix-issue
description: Implement a GitHub issue using TDD workflow
argument-hint: [issue-number]
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(gh *), Bash(uv *), Read, Write, Edit
---

Implement GitHub issue #$ARGUMENTS

1. `gh issue view $ARGUMENTS` for details
2. Create branch: `git checkout -b feature/$ARGUMENTS`
3. Write tests first (TDD)
4. `uv run pytest` - confirm tests fail
5. Implement to pass tests
6. Update README.md and agent_logs/LOG.md
7. Commit and create PR: `gh pr create --fill`
```

**Key skill features:**
- `disable-model-invocation: true` - Only you can trigger with `/fix-issue 123`
- `$ARGUMENTS` - Substituted with whatever follows the slash command
- `argument-hint` - Shows in autocomplete: `/fix-issue [issue-number]`
- Skills can include supporting files (scripts, templates) in the same directory

### 5. Plugins to Consider

| Plugin | Purpose | Install |
|--------|---------|---------|
| **greptile** (already installed) | PR reviews, code search | - |
| **tdd-guard** | Block implementation until tests exist | `npm install -g tdd-guard` |
| **context7** | MCP server for library docs | `npx -y @anthropic-ai/claude-code@latest mcp add context7` |

### 6. Workflow Improvements

**Git worktrees for parallel tasks**:
```bash
git worktree add ../project-feature-123 -b feature/123
cd ../project-feature-123 && claude
```

**Permission mode cycling** (Shift+Tab):
- Plan Mode → Default → AcceptEdits → Plan Mode

---

## Implementation Order

1. **Edit AGENTS.md** - Remove redundant activation lines, fix formatting
2. **Create CLAUDE.md** - Copy AGENTS.md content + add CC-specific sections
3. **Update .claude/settings.json** - Add documentation reminder hook only
4. **Create `/update-docs` skill** - `.claude/skills/update-docs/SKILL.md`
5. (Optional) Create `/fix-issue` skill

**Skipped for now** (documented above in Section 3 for future reference):
- Auto-pytest hook (Section 3B)
- SessionStart hook (Section 3C)

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `CLAUDE.md` | Create new |
| `AGENTS.md` | Edit lines 8-9, 42 |
| `.claude/settings.json` | Add hooks |
| `.claude/skills/update-docs/SKILL.md` | Create new |
| `.claude/skills/fix-issue/SKILL.md` | Create new |

---

## Sources

- [Extend Claude with skills - Official Docs](https://code.claude.com/docs/en/skills)
- [How to create custom Skills | Claude Help Center](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills)
- [awesome-claude-code GitHub](https://github.com/hesreallyhim/awesome-claude-code)
