---
name: sync-docs
description: Update all README.md and CLAUDE.md files to reflect current codebase state. Combines update-docs and update-claudes. Also archives completed active plans.
argument-hint: [path]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls *), Bash(find *), Bash(cat pyproject.toml), Bash(cat Makefile), Bash(mv *)
---

# Sync Docs

Recursively update all README.md and CLAUDE.md files, then archive completed active plans.

## Part 1: Update READMEs

### What belongs in READMEs

READMEs are for humans:
- What the directory/project does (purpose)
- File/directory listing with brief descriptions
- Setup/usage instructions
- Links to sub-READMEs and related docs
- Data format descriptions (for data/ dirs)

### Steps

1. **Find README.md files**
   - If `$ARGUMENTS` is provided, scope to that directory's README only
   - Otherwise, use Glob to find all `**/README.md` in the project
   - Exclude `node_modules/`, `.venv/`, `.git/`, `agent_dev/`

2. **Audit each README against its directory**
   - List the actual files and subdirectories (using `ls`)
   - Compare against what the README documents
   - Flag:
     - **Stale references** — files/dirs mentioned that no longer exist
     - **Undocumented entries** — files/dirs that exist but aren't mentioned
   - Ignore: `.gitignore`, `__pycache__`, `.DS_Store`, `*.pyc`

3. **Verify internal links (root README especially)**
   - Check that all markdown links resolve to existing files
   - Check that directory tree diagrams match reality
   - Flag broken links and outdated tree diagrams

4. **Update each README**
   - Add brief entries for undocumented files/dirs
   - Remove or mark references to deleted files
   - Fix broken internal links
   - Update directory tree diagrams to match current structure
   - Keep descriptions concise — don't over-document
   - Preserve existing style and tone

## Part 2: Update CLAUDE.md Files

### What belongs in CLAUDE.md

CLAUDE.md files are for agents:
- Instructions and constraints for working in this directory
- Commands to run (test, build, lint, etc.)
- Conventions to follow
- `# Insights` section (append-only — never modify)

Keep CLAUDE.md files CONCISE. Favor pointing to where information can be found. No code snippets; reference files and line numbers instead (e.g., `file:line`).

### Steps

1. **Find CLAUDE.md files**
   - If `$ARGUMENTS` is provided, scope to that directory's CLAUDE.md only
   - Otherwise, use Glob to find all `**/CLAUDE.md` in the project
   - Exclude `node_modules/`, `.venv/`, `.git/`, `agent_dev/`
   - Also check for `.claude/CLAUDE.md` variants

2. **Audit each CLAUDE.md for accuracy**
   - **File/path references** — do referenced files and directories still exist?
   - **Command references** — do referenced commands still work?
     - Check `pyproject.toml` `[project.scripts]` and `[tool.uv.scripts]`
     - Check `Makefile` targets if referenced
     - Check `package.json` scripts if referenced
   - **Skill references** — are referenced skills still installed? (check `global_settings/claude/skills/` and `.claude/skills/`)
   - **Directory descriptions** — do they match current directory contents?

3. **Update each CLAUDE.md**
   - Fix stale file/path references
   - Update command references to match current config
   - Remove references to deleted directories or tools
   - Update directory descriptions if structure changed
   - **DO NOT touch `# Insights` sections** — these are append-only
   - Preserve existing style and structure

## Part 3: Archive Completed Plans

1. **Scan `agent_dev/active/`** for plans where all tasks are checked off
2. **Move completed plans** to `agent_dev/archived/`
3. **Report** which plans were archived

## Summary

Show:
- Each README updated and what changed
- Each CLAUDE.md updated and what changed
- Plans archived (if any)
- Items that need human input
