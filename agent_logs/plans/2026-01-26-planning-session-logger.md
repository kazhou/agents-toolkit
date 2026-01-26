# Plan: Planning Mode Session Logger (Plugin)

## Goal
Create a Claude Code plugin that automatically saves session transcripts and plan files to `agent_logs/`.

## Solution: Claude Code Plugin

A plugin that uses the `SessionEnd` hook to automatically capture and save session data.

## Installation & Usage

```bash
# Install the plugin (one-time setup)
claude plugin install /path/to/agents-toolkit/session-logger-plugin

# That's it! Now all sessions are automatically logged.
# Just use claude normally:
claude
claude --plan
claude -c  # continue session

# Transcripts saved to ./agent_logs/transcripts/
# Plans saved to ./agent_logs/plans/
```

To disable logging temporarily:
```bash
claude plugin disable session-logger
```

To re-enable:
```bash
claude plugin enable session-logger
```

## Plugin Structure

```
session-logger-plugin/
├── manifest.json              # Plugin metadata & config
├── hooks/
│   └── hooks.json             # SessionEnd hook definition
└── scripts/
    └── save-session.sh        # Transcript processing script
```

### manifest.json
```json
{
  "name": "session-logger",
  "version": "1.0.0",
  "description": "Automatically saves session transcripts and plans to agent_logs/",
  "author": "agents-toolkit"
}
```

### hooks/hooks.json
```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/save-session.sh"
          }
        ]
      }
    ]
  }
}
```

### scripts/save-session.sh
Receives JSON via stdin with:
- `session_id`
- `transcript_path`
- `cwd` (current working directory)

Script will:
1. Read transcript from `transcript_path`
2. Clean it (remove ANSI codes, deduplicate lines)
3. Save to `$cwd/agent_logs/transcripts/YYYY-MM-DD-<session-id>.transcript.txt`
4. Copy recent plan files to `$cwd/agent_logs/plans/`

## Naming Convention (per AGENTS.md)

- **Transcripts**: `YYYY-MM-DD-<session-id>.transcript.txt`
- **Plans**: `YYYY-MM-DD-<plan-name>.md`

## Directory Structure (created in each project)

```
agent_logs/
├── transcripts/     # Session transcripts as cleaned .txt files
├── plans/           # Plan .md files
└── LOG.md           # Session summaries (manual)
```

## Copying to New Projects

The plugin saves logs to the current working directory's `agent_logs/` folder. Just create the directory structure in any project:

```bash
mkdir -p agent_logs/{transcripts,plans}
```

The plugin handles the rest automatically.

## Verification

1. Install: `claude plugin install ./session-logger-plugin`
2. Verify: `claude plugin list` shows session-logger enabled
3. Start a session: `claude`
4. Have a brief conversation, then exit
5. Check `agent_logs/transcripts/` for the transcript file
6. Verify transcript is clean (readable text, no ANSI codes)
