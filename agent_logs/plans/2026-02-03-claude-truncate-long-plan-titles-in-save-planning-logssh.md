# Truncate Long Plan Titles in save-planning-logs.sh

## Problem
Long plan headings cause two issues:
1. Excessively long filenames (filesystem limit ~255 chars)
2. OSError when `Path(content).exists()` is called on content strings > 4096 chars

## Solution (Implemented)

### File modified
- `.claude/hooks/save-planning-logs.sh`

### Change 1: Title truncation (lines 95-102)
Added truncation after kebab-case conversion (max 50 chars, clean word boundaries):
```python
MAX_LENGTH = 50
if len(name) > MAX_LENGTH:
    truncated = name[:MAX_LENGTH]
    last_hyphen = truncated.rfind('-')
    if last_hyphen > MAX_LENGTH // 2:
        name = truncated[:last_hyphen]
    else:
        name = truncated.rstrip('-')
```

### Change 2: Path validation guard (lines 73-83)
Prevent OSError when content is passed instead of a file path:
```python
could_be_path = '\n' not in plan_content_or_path and len(plan_content_or_path) < 4096
if could_be_path:
    # ... try Path().exists()
else:
    content = plan_content_or_path  # It's definitely content
```

### Change 3: Use file path from transcript (line 317)
Pass the file path (from Write tool call) instead of content:
```python
plan_name = extract_plan_name(plan_file_path if plan_file_path else plan_content)
```

## Verification
Run the hook on a plan with a long title - should truncate cleanly without errors
