---
name: project_beszel-disk-alerting
description: Fleet disk-space alerting reuses beszel-agent (already deployed, already proven) instead of a new tool
metadata:
  type: project
---

A disk-space alarm request turned out to need no new tool: beszel-agent was already
deployed (hub on contabo2; agents on docker03, cygnus) and had already caught a real
disk-full incident on cygnus. The work was closing gaps, not building — extend coverage to
CT206, containerize cygnus's agent to match its other podman services, and clean up stale
docs claiming coverage that didn't exist yet.

**Why:** before proposing new monitoring for anything disk/host-related, check whether
beszel already covers it — it's the fleet's existing tool, not gr-srv03's
`lvm-space-monitor.sh` (that one is host-level thin-pool only, a different mechanism, see
[[project_gr-srv03_powered-hub-instability]] for the unrelated hub-power context).

**How to apply:** CT207 deliberately has no agent yet (deferred until made production, not
an oversight). New LXCs/containers going forward should get a beszel-agent as part of
their setup, native systemd on bare LXCs, podman container on hosts that run podman
(cygnus's pattern). Full coverage table, the cygnus systemd→container fingerprint-migration
procedure, and the CT206 TOKEN-401 gotcha are in
docs/2026-09-06_beszel-fleet-disk-alerting.md.
