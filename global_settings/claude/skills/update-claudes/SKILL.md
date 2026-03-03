---
name: update-claudes
description: Recursively update all CLAUDE.md files for accuracy. Fixes stale paths, commands, and references. Never touches `# Insights` sections.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls *), Bash(find *), Bash(cat pyproject.toml), Bash(cat Makefile)
---

# Update CLAUDEs

Recursively scan and update all CLAUDE.md files so their instructions stay accurate.

## What belongs in CLAUDE.md

CLAUDE.md files are for agents:
- Instructions and constraints for working in this directory
- Commands to run (test, build, lint, etc.)
- Conventions to follow
- `# Insights` section (append-only — never modify)

Keep CLAUDE.md files CONCISE! Avoid over-explaining, and favor pointing to where the necessary information can be found. No code snippets; reference files and line numbers instead.

## Steps

1. **Find all CLAUDE.md files**
   - Use Glob to find `**/CLAUDE.md` in the project
   - Exclude `node_modules/`, `.venv/`, `.git/`, `agent_dev/`
   - Also check for `.claude/CLAUDE.md` variants

2. **Audit each CLAUDE.md for accuracy**
   For each file, check:
   - **File/path references** — do referenced files and directories still exist?
   - **Command references** — do referenced commands still work?
     - Check `pyproject.toml` `[project.scripts]` and `[tool.uv.scripts]`
     - Check `Makefile` targets if referenced
     - Check `package.json` scripts if referenced
   - **Skill references** — are referenced skills still installed? (check `global_settings/claude/skills/` and `.claude/skills/`)
   - **Directory descriptions** — do they match current directory contents?

3. **Update each CLAUDE.md**
   - Fix stale file/path references (update paths or remove if deleted)
   - Update command references to match current config
   - Remove references to deleted directories or tools
   - Update directory descriptions if structure changed
   - **DO NOT touch `# Insights` sections** — these are append-only
   - Preserve the existing style and structure

4. **Show summary**
   - List each CLAUDE.md updated and what changed
   - Note any items that need human judgment (e.g., instructions that may be outdated but you're unsure)
