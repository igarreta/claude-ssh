---
name: feedback_docs_location
description: "All docs AND memories go in local docs/ dir of claude-ssh repo — not on remote machines, not only in ~/.claude/projects/"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: af2db5a7-f3a6-477c-889d-155b3d4bf3b8
---

Always save documentation, incident write-ups, and memory content in the local `docs/` directory of the claude-ssh repo (`/home/rsi/claude-ssh/docs/`), not on the remote machine being documented.

**Why:** User preference — docs and memories are managed centrally in the git-tracked claude-ssh repo.

**How to apply:**
- When creating any .md doc about a remote system (Pi, LXC, VMs, etc.), write it locally with the Write tool to `/home/rsi/claude-ssh/docs/`
- When saving memories about the project/systems, create or update files in `/home/rsi/claude-ssh/docs/` (git-tracked), not only in `~/.claude/projects/`
- Keep `~/.claude/projects/MEMORY.md` as a short index, but put the actual content in `docs/`
