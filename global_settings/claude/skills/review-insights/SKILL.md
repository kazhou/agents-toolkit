---
name: review-insights
description: Scan all CLAUDE.md files and agent_dev/README.md for `# Insights` sections. Present consolidated insights for human review.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(find *)
---

# Review Insights

Scan the project for all accumulated insights and present them for review.

## Steps

1. **Find all files with Insights sections**
   - Search for `CLAUDE.md` files in the project (excluding node_modules, .venv)
   - Also read `agent_dev/README.md`

2. **Extract # Insights sections**
   - For each file, extract content under `# Insights` or `## Insights` heading
   - Include the file path as context
   - Skip files with empty Insights sections

3. **Present consolidated output**
   - Group insights by source file
   - Show each insight with its date

4. **Ask the user**
   - Which insights should be promoted to permanent rules in CLAUDE.md?
   - Any insights to archive or remove?
