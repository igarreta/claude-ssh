---
name: feedback_https_urls_only
description: "User's browser refuses plain HTTP web UIs — always give HTTPS URLs"
metadata:
  node_type: memory
  type: feedback
---

The user's browser refuses plain HTTP web UIs. Always give HTTPS URLs.

**Why:** an http:// link is simply unusable for them, so it reads as a broken answer.

**How to apply:** when surfacing any web UI, give the HTTPS form (usually the Tailscale
name, e.g. `https://cygnus.tail366c79.ts.net`). Full content in `docs/memory_feedback.md`.
Related: [[project_cygnus_caddy_tls]].
