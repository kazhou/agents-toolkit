---
name: update-docs
description: Recursively update all README.md files to reflect current codebase state. Fixes stale references, adds undocumented files, and verifies internal links.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls *), Bash(find *)
---

# Update Docs

Recursively scan and update all README.md files so they accurately reflect the current codebase.

## What belongs in READMEs

READMEs are for humans:
- What the directory/project does (purpose)
- File/directory listing with brief descriptions
- Setup/usage instructions
- Links to sub-READMEs and related docs
- Data format descriptions (for data/ dirs)

## Steps

1. **Find all README.md files**
   - Use Glob to find `**/README.md` in the project
   - Exclude `node_modules/`, `.venv/`, `.git/`, `agent_dev/`

2. **Audit each README against its directory**
   - For each README, list the actual files and subdirectories in its parent directory (using `ls`)
   - Compare against what the README documents
   - Flag:
     - **Stale references** — files/dirs mentioned in the README that no longer exist
     - **Undocumented entries** — files/dirs that exist but aren't mentioned
   - Ignore common non-documentable files: `.gitignore`, `__pycache__`, `.DS_Store`, `*.pyc`

3. **Verify internal links (root README especially)**
   - Check that all markdown links (`[text](path)`) resolve to existing files
   - Check that directory tree diagrams (``` blocks with file listings) match reality
   - Flag broken links and outdated tree diagrams

4. **Update each README**
   - Add brief entries for undocumented files/dirs
   - Remove or mark references to deleted files
   - Fix broken internal links
   - Update directory tree diagrams to match current structure
   - Keep descriptions concise — don't over-document
   - Preserve the existing style and tone of each README

5. **Show summary**
   - List each README updated and what changed
   - Note any items that need human input (e.g., descriptions you couldn't infer)
