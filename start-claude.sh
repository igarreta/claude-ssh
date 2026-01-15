#!/bin/bash
# Start Claude Code in the claude-ssh project directory

cd /home/rsi/claude-ssh || exit 1

# Set terminal title
echo -ne "\033]0;Claude Code - SSH Manager\007"

# Optional: Show git status on startup
git status --short 2>/dev/null

# Start Claude
exec claude
