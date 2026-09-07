---
name: project_podman_compose_gotchas
description: podman-compose `config` output is misleading (pre-extends) and `extends:` files resolve relative to CWD — two silent traps when checking a compose stack on cygnus
metadata:
  type: project
---

Two podman-compose behaviours that look like bugs in *your* config and are not. Verified on
cygnus 2026-09-07 (podman 5.4.2, podman-compose 1.3.0).

**Why it matters:** both fail silently rather than erroring, so they cost debugging time on a
stack that is actually fine.

1. **`podman-compose config` prints `merged_yaml`** — the file-level `-f` merge, computed *before*
   `resolve_extends` runs. An `extends:` block therefore shows up unresolved with none of the
   inherited keys merged in. **Do not use `config` to verify that an `extends:`-supplied setting
   (e.g. a `/dev/dri` device for hardware acceleration) is wired up** — check the running
   container instead.
2. **`extends: file:` resolves relative to the process CWD**, not the compose file's directory.
   `sudo podman compose -f /path/to/docker-compose.yml up` from elsewhere silently fails to find
   the referenced file. **`cd` into the compose directory first.**

Also: rootless podman does not work for `rsi` on cygnus (`newuidmap: Operation not permitted`),
which is the underlying reason for [[feedback_cygnus_podman_compose]].

**How to apply:** when a compose feature appears to be ignored under podman, check these two
before concluding podman-compose lacks the feature — it supports `extends`, `shm_size`,
`device_cgroup_rules`, `group_add`, `security_opt` and `healthcheck`. Feature-by-feature evidence
and the `compose_providers` escape hatch (swap in real docker-compose via `containers.conf`, a
config line rather than a migration) are in [[docs/2026-09-07_nas-software-stack.md]].
