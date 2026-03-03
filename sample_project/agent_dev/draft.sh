#!/bin/bash
# Create a new drafting doc in agent_dev/drafting/
# Usage: ./agent_dev/draft.sh [slug]

slug="${1:-draft}"
slug=$(echo "$slug" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
date=$(date +%y-%m-%d)
dir="agent_dev/drafting"

mkdir -p "$dir"

file="$dir/${date}_${slug}.md"
i=2
while [ -f "$file" ]; do
  file="$dir/${date}_${slug}_${i}.md"
  ((i++))
done

cat > "$file" << EOF
# ${slug}
<!-- Brainstorm: WHAT and WHY. No code beyond frameworks/architectures. -->


EOF

echo "Created: $file"
