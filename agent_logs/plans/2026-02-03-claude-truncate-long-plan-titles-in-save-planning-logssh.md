# Truncate Long Plan Titles in save-planning-logs.sh

## Problem
The `extract_plan_name` function extracts plan names from markdown headings without length limits. Long headings create excessively long filenames that could:
- Exceed filesystem limits (255 chars for most systems)
- Be unwieldy to work with

## Solution
Add truncation logic to `extract_plan_name` function with these requirements:
- Max length: **50 characters** for the plan name portion (reasonable for readability while leaving room for date prefix and extension)
- Clean truncation: avoid cutting mid-word when possible
- No trailing hyphens after truncation

## Implementation

### File to modify
- `.claude/hooks/save-planning-logs.sh` (lines 67-93, `extract_plan_name` function)

### Changes
Add truncation after the kebab-case conversion (around line 91):

```python
# After: name = name.strip('-')
# Add truncation logic:
MAX_LENGTH = 50
if len(name) > MAX_LENGTH:
    # Try to truncate at word boundary (hyphen)
    truncated = name[:MAX_LENGTH]
    last_hyphen = truncated.rfind('-')
    if last_hyphen > MAX_LENGTH // 2:  # Only use if reasonable
        name = truncated[:last_hyphen]
    else:
        name = truncated.rstrip('-')
```

## Verification
1. Test with a long heading like `# This Is A Very Long Plan Title That Should Definitely Be Truncated Because It Exceeds The Maximum Length`
2. Verify the resulting filename is truncated cleanly
3. Verify short titles still work normally
