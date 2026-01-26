# Plan: Test Hook - Hello World

## Goal
Print "hello world" to verify the planning session logger hook triggers correctly on ExitPlanMode.

## Implementation
1. Run `echo "hello world"` in bash

## Verification
After exiting plan mode, check:
- `agent_logs/plans/` for a new plan file
- `agent_logs/transcripts/` for a new transcript file
- Git log for a new commit with message "chore: update planning session logs"
