---
name: audit-plan
description: Review a session plan for scope creep and unnecessary complexity before execution begins. Combines scope-check and simplicity-audit. Run after Plan Mode, before any code is written.
argument-hint: [session plan file or .claude/plans/name]
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(find *), Bash(ls *), Bash(grep *), Bash(rg *)
---

# Audit Plan

Review a session plan and the code it will touch for scope creep and unnecessary complexity. Produce a compact pre-execution report for human approval. The goal is to surface problems before any code is written, not after.

## Determine Tier

Assess the session plan and pick the appropriate tier:

- **Tiny** (≤2 files, no new abstractions, no cross-module changes) → 30-second checklist
- **Normal** (typical feature work) → full scope check + quick simplicity scan
- **Large** (parallel tasks, new abstractions, error handling additions) → full scope check + full simplicity audit + Codex review

## Tiny Tier

Quick checklist:
1. Files to touch?
2. Anything outside active plan boundaries?
3. Any broad exception handlers?

Output: `X expected, 0 flagged. Proceed.`

## Normal Tier

### Part 1: Scope Check

1. **Find the session plan**
   - If `$ARGUMENTS` provided, find matching plan in `.claude/plans/` (substring match)
   - Otherwise, list plans in `.claude/plans/` and ask user which one
   - Also read the linked active plan from `agent_dev/active/` if referenced

2. **Extract and categorize planned work**

   **A. Files to be created or modified**
   - List every file the plan intends to create or modify
   - Flag any file outside the active plan's `# Boundaries` section (if defined)
   - Flag new files that aren't test files or directly named in the active plan's tasks

   **B. New abstractions**
   - List every new class, base class, protocol/interface, or factory the plan introduces
   - For each, note: does the active plan explicitly call for this abstraction, or is it inferred?
   - Flag inferred abstractions — ones Claude added that aren't in the active plan's task list

   **C. Error handling beyond plan scope**
   - List every try/except or error handling block planned
   - Cross-reference with active plan: is this error case explicitly mentioned?
   - Flag any broad handlers (Exception, BaseException) or error cases not in the active plan

   **D. Scope vs active plan tasks**
   - List the tasks from the active plan's `# Session slice` or `# Tasks` section (whichever is current)
   - List what the session plan actually covers
   - Flag anything in the session plan not traceable to an active plan task

### Part 2: Quick Simplicity Scan

Scan files about to be modified for:
- Single-subclass base classes
- Single-callsite helpers (functions called from exactly one place, not public API/tests/entry points)
- Broad exception handlers (`except Exception`, bare `except:`, `catch {}`)

Flag findings inline with the scope check output.

## Large Tier

Run full scope check (Part 1 above) AND full simplicity audit:

### Full Simplicity Audit

Scan target files for:

**A. Single-subclass base classes**
- Find all class definitions that are subclassed
- Flag any base class with exactly one subclass and no external users

**B. Single-callsite helpers**
- Find all function/method definitions
- For each, count callsites across the codebase
- Flag functions called from exactly one place that aren't public API, tests, or entry points

**C. Broad exception handlers**
- Find all `except Exception`, `except BaseException`, bare `except:`, and `catch (e)` / `catch {}` blocks
- Flag any that don't re-raise, don't log with context, or swallow errors silently
- Cross-reference with CLAUDE.md rule: only use try/except for specific, known error types

**D. Unused generalization**
- Find function parameters with default `None` never passed as non-None
- Find config/options with fields never read outside their definition file
- Find `**kwargs` never used or passed through

**E. Premature abstractions**
- Find factory functions, registry patterns, or plugin systems with only one registered item
- Find abstract base classes (ABC) with only one concrete implementation

### Codex Review (Large tier only)

Invoke Codex (via MCP) to review the plan for scope creep, unnecessary complexity, and over-engineering. Include Codex's findings in the report.

## Output Format

```
FILES (~N files)
[ ] create  path/to/new_file.py
[ ] modify  path/to/existing.py
[!] outside-boundary  path/to/flagged.py  ← not in active plan scope

NEW ABSTRACTIONS (~N)
[ ] class FooBase  ← explicitly in active plan task 2
[!] class BarMixin  ← not in active plan, inferred by Claude

ERROR HANDLING (~N)
[ ] try/except ValueError in scorer.py  ← mentioned in active plan
[!] except Exception in generator.py  ← broad handler, not in active plan

SCOPE DRIFT (~N items not in active plan)
[!] description of thing Claude added that wasn't asked for

SIMPLICITY (~N findings)
[ ] SINGLE-CALLSITE | file:line | description | suggested action
[!] BROAD-EXCEPT | file:line | description | suggested action
```

Use `[ ]` for expected items and `[!]` for flagged items.

## Summary

End with one line: `X expected, Y flagged. Approve, remove flagged items from plan, or abort.`

## Gate

**Do not begin execution** — wait for user to respond before any code is written.
- If user says "approve" or "looks good" → proceed with execution
- If user cuts specific items → update session plan to remove them, then confirm before proceeding
- If user says "abort" → stop and return to Plan Mode
