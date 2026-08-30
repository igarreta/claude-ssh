---
name: project_log-monitor_collect-sigpipe
description: "log-monitor's daily 'FAILED to collect logs (ssh error)' for contabo2 was never ssh — collect.sh died on an internal SIGPIPE from `head` in its remote pipeline; fixed 2026-08-30"
metadata:
  node_type: memory
  type: project
---

`run.sh` hardcodes **"(ssh error)"** for any non-zero exit from `collect.sh`, so a purely
internal failure arrives as an SSH accusation. In this case `printf | head -n 200` in the
remote pipeline raised SIGPIPE on a >200-signature journal, `pipefail` turned it into exit 141,
and the caller's `set -e` aborted silently — empty digest, **cursor never advanced**, so the
backlog grew and the failure could never clear itself.

**Why:** four days of contabo2 blackout (2026-08-27 → 08-30). The trigger was the *previous*
fix — adding `rsi` to `systemd-journal` on 08-26 ([[project_log-monitor_journal-group-gap]])
made the full journal visible, and contabo2's ~4,500 unique UFW-scan lines/day instantly blew
past the cap. The bug was latent on **every** host, not just contabo2.

**How to apply:**
- Never trust the "(ssh error)" wording — it now reports the real exit code, but old alerts and
  archived reports still say ssh. Verify with an actual `ssh` before chasing connectivity.
- `SUPPRESS_PATTERN` must stay applied **remotely, before aggregation and the cap**. Filtering
  after the cap lets noise crowd out every real message even when nothing crashes.
- Don't use `${var//…}` on anything that may hold a whole journal — bash global substitution on
  a multi-MB string takes minutes and looks exactly like an SSH hang. Use `grep -c`.
- An empty digest plus a stale cursor is the signature of this class of bug; a genuinely quiet
  host still advances its cursor.

Full detail: [[docs/2026-08-30_log-monitor_collect-sigpipe.md]], architecture in
[[docs/2026-06-30_log-monitor.md]].
