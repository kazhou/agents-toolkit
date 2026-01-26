# Plan: Planning Mode Session Logger

## Goal
Create a portable script that automatically saves planning mode logs (full transcripts + plan files) to an `agent_logs/` directory when Claude Code planning sessions end.

## Solution: Claude Code Hooks

Use Claude Code's native `SessionEnd` hook to automatically capture and save planning session data.

## Naming Convention (per AGENTS.md)

- **Plans**: `YYYY-MM-DD-<plan-name>.md`
- **Transcripts**: `YYYY-MM-DD-<plan-name>.transcript.txt`

## Files Created

### 1. `.claude/settings.json` - Hook Configuration
```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/save-planning-logs.sh"
          }
        ]
      }
    ]
  }
}
```

### 2. `.claude/hooks/save-planning-logs.sh` - Main Logger Script

Responsibilities:
- Read session info from stdin (JSON with `session_id`, `transcript_path`)
- Check if session was a planning session (by examining transcript for plan mode indicators)
- Convert JSONL transcript to readable text format
- Copy transcript to `agent_logs/transcripts/` as `.transcript.txt`
- Copy plan files to `agent_logs/plans/` with date prefix
- Use portable JSON parsing (jq with Python fallback)

### 3. `agent_logs/` Directory Structure
```
agent_logs/
├── transcripts/     # Session transcripts as readable .txt files
├── plans/           # Plan .md files
└── planning-session-logger-plan.md
```

### 4. `.gitignore` Updates
Added patterns to optionally exclude logs from version control:
```
# Planning/Agent Logs (uncomment to exclude from version control)
# agent_logs/transcripts/
# agent_logs/plans/
```

## How to Copy to New Projects

To add the planning session logger to another project:

1. **Copy the hook script and settings:**
   ```bash
   # From the agents-toolkit directory
   cp -r .claude/hooks /path/to/your/project/.claude/
   cp .claude/settings.json /path/to/your/project/.claude/
   ```

2. **Create the logs directory:**
   ```bash
   mkdir -p /path/to/your/project/agent_logs/{transcripts,plans}
   touch /path/to/your/project/agent_logs/transcripts/.gitkeep
   touch /path/to/your/project/agent_logs/plans/.gitkeep
   ```

3. **Make the script executable:**
   ```bash
   chmod +x /path/to/your/project/.claude/hooks/save-planning-logs.sh
   ```

4. **Optionally update `.gitignore`:**
   ```bash
   cat >> /path/to/your/project/.gitignore << 'EOF'

   # Planning/Agent Logs (uncomment to exclude from version control)
   # agent_logs/transcripts/
   # agent_logs/plans/
   EOF
   ```

## Verification

1. Ensure script is executable: `chmod +x .claude/hooks/save-planning-logs.sh`
2. Start a Claude Code planning session (`/plan` command)
3. Exit the session
4. Check `agent_logs/` for:
   - Transcript file in `transcripts/` named `YYYY-MM-DD-<plan-name>.transcript.txt`
   - Plan file in `plans/` named `YYYY-MM-DD-<plan-name>.md`
5. Verify transcript is readable text (not raw JSONL)
