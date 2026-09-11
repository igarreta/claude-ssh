---
name: project_nas-service-placement-rules
description: "Placement rulebook for the gr-srv03 + NAS pair, settled 2026-09-11: the one-week rule, no clustering, one-way dependencies, PBS on the NAS with an off-box key; the dependency audit is a NAS-commissioning task"
metadata:
  node_type: memory
  type: project
  modified: 2026-09-11T00:00:00.000Z
---

**Why it matters:** every "where should this service run?" question for the rest of this fleet's
life is answered by these rules, and two of them cost real investigation to reach — clustering was
evaluated and **rejected**, and the HA→Postgres path turned out to be fire-and-forget HTTP rather
than a recorder, which is why HA survives a NAS outage at all.

**How to apply:**

- Placing or moving any service: check the one-week rule and the dependency direction **first**.
  Never add a synchronous gr-srv03 → NAS dependency; mounts are the dangerous class.
- Do **not** re-propose Proxmox clustering, HA/failover, or `pvesr` replication. If it is ever
  reconsidered, the deadline is before the NAS has guests.
- Do **not** propose moving castor to the NAS, or standing up a second Postgres there.
- **When the NAS is commissioned, run the §7 dependency audit** — that is the trigger this node
  exists to fire. §7 also holds the unresolved items (gr-srv03 has no RAM headroom, so the VM 102
  decommission is a prerequisite; neither restore path is rehearsed; shared power/switch SPOFs).
- Before the first PBS backup runs, settle where the encryption key lives — **off the NAS**.

Detail: `docs/2026-09-11_nas-gr-srv03_service-placement-rules.md`.
Related: [[project_nas]], [[project_docker03_decommission]], [[project_castor_postgres]],
[[project_gr-srv03_powered-hub-instability]], [[project_backup_schedule]].
