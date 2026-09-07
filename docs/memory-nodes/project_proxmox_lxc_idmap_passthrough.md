---
name: project_proxmox_lxc_idmap_passthrough
description: PVE 9.2 has a per-mount `idmap=passthrough` option that fixes unprivileged LXC bind-mount ownership outright — reach for it instead of chmod 777 or going privileged
metadata:
  type: project
---

Proxmox exposes a **per-mount-point `idmap=` option**; `idmap=passthrough` identity-maps all
UIDs/GIDs so on-disk IDs match container IDs. Verified on gr-srv03 2026-09-07 (pve-manager
9.2.11, pve-container 6.1.14, kernel 7.0.14-15-pve, ZFS 2.4.4).

**Why it matters:** it retires two long-standing workarounds in this fleet — the `chmod 777` on
`/mnt/backup_a` and any hand-written `lxc.idmap` arithmetic — and it is **ignored on privileged
containers**, so it is an argument to *stay* unprivileged rather than escalate. That reversed the
NAS Samba decision ([[project_nas]]), where the user had been leaning privileged.

**How to apply:** whenever an LXC bind mount shows `nobody:nogroup` or denies writes, reach for
`idmap=passthrough` first. It does **not** grant `security.*` xattrs (Samba `vfs_acl_xattr` /
Windows ACLs stay unavailable), and a shared group + umask are still needed when several guests
write one tree. Note gr-srv03 is on PVE **9.2.11 / kernel 7.0.14**, not the 9.1.2 / 6.17.2 that
CLAUDE.md still records.

Detail, syntax and source references:
[[docs/Proxmox_unpriviedged_LXC_mount_permissions.md]] (2026-09-07 update banner).
First design use: [[docs/2026-09-07_nas-software-stack.md]].
