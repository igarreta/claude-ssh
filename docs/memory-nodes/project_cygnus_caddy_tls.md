---
name: project_cygnus_caddy_tls
description: "cygnus Caddy serves pgAdmin over HTTPS with a Tailscale cert renewed by a root cron (the caddy user cannot fetch certs)"
metadata:
  node_type: memory
  type: project
---

cygnus Caddy serves pgAdmin at `https://cygnus.tail366c79.ts.net`. The Tailscale cert is
static with no auto-renew, so renewal runs from a **root** cron — the `caddy` user can't
fetch certs and the tailscale operator is `rsi`.

**Why:** without the root cron the cert silently expires and the UI dies; the obvious
"run it as caddy" fix does not work.

**How to apply:** `docs/2026-06-22_cygnus_caddy-tls-pgadmin.md`. A renewal failure from
2026-08-04 (Let's Encrypt ARI stuck order) self-resolved 2026-08-10 — cert renewed cleanly
(`notBefore=Aug 10`, `notAfter=Nov 8 2026`), confirmed both on disk and actually served over
TLS. See `docs/2026-08-04_cygnus_caddy-cert-ari-stuck-order.md` (now closed) if this class of
`409 alreadyReplaced` error recurs — it's a transient Let's Encrypt/Boulder server-side lock,
not a local misconfiguration. Related: [[feedback_https_urls_only]].
