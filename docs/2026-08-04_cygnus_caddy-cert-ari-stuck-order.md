# cygnus: Caddy TLS cert renewal failed — Let's Encrypt ARI stuck order

**Status:** open
**Host:** cygnus
**Supersedes:** —
**Superseded-by:** —

**Date:** 2026-08-04
**Status detail:** unresolved as of 2026-08-04 (not urgent — see Impact)

## Symptom

Pushover alert: `cygnus renew-caddy-cert.sh: tailscale cert FAILED for
cygnus.tail366c79.ts.net`. Manual retries of
`tailscale cert --min-validity 720h --cert-file /etc/caddy/cygnus.crt
--key-file /etc/caddy/cygnus.key cygnus.tail366c79.ts.net` all fail with:

```
500 Internal Server Error: 409 urn:ietf:params:acme:error:alreadyReplaced:
Could not validate ARI 'replaces' field :: cannot indicate an order replaces
certificate with serial "05cd45d205dc9574eda2cf0fedefcf633984", which already
has a replacement order
```

## Impact

Not an outage. The served cert (issued 2026-06-03, expires 2026-09-01) stays
valid and unchanged through every failed attempt — only the *renewal* fails.
As of 2026-08-04, ~4 weeks of margin remain before actual expiry.

## Root cause

Confirmed via `sudo journalctl -u tailscaled` (rsi isn't in `adm`/
`systemd-journal` on cygnus, and sudo needs a password — this required the
user to run the command directly). The cron-triggered renewal on 2026-08-03
04:17 got as far as starting the DNS-01 challenge, then Tailscale's own
control-plane DNS API failed:

```
Aug 03 04:17:02 cert("cygnus.tail366c79.ts.net"): starting sync renewal
Aug 03 04:17:03 cert("cygnus.tail366c79.ts.net"): starting SetDNS call for _acme-challenge...
Aug 03 04:17:04 cert("cygnus.tail366c79.ts.net"): getCertPEM: SetDNS "..." => set-dns response: 500 Internal Server Error, failed to create DNS record
```

By the time the DNS record write failed, Let's Encrypt (Boulder) had already
registered the ACME order and locked the "replacement slot" for the current
cert's serial via the ARI `replaces` extension. Because the DNS-01 challenge
was never published, that order never completed — and every subsequent
renewal attempt (cron or manual) gets rejected with `409 alreadyReplaced`,
since Boulder won't allow a second order claiming to replace a cert that
already has an outstanding replacement order.

This is a **transient failure in Tailscale's control-plane DNS API**, not a
misconfiguration in the Caddyfile, the renewal script, or cygnus itself. See
`docs/2026-06-22_cygnus_caddy-tls-pgadmin.md` for the renewal setup this
script belongs to.

## How long does the lock take to clear?

Unclear — don't trust a specific number here. Boulder's published docs
describe pending-order/authorization lifetimes on the order of ~1 hour (or
up to 7 days in older docs), but our stuck order had already outlived 24+
hours as of the first manual retry (2026-08-04) and a second manual retry
that same day still failed. Treat the lock as bounded but of unknown
duration; the cert's real expiry (2026-09-01) is the actual deadline that
matters.

## Status / next steps

- 2026-08-04: manually re-ran `/usr/local/sbin/renew-caddy-cert.sh` twice —
  both failed with the same `alreadyReplaced` error. Served cert unchanged
  (still serial `05cd45d2...`, same June-3 cert).
- No local config change needed or attempted — nothing here is
  misconfigured.
- Plan: let the weekly cron (Mon 04:17) keep retrying; treat as resolved
  once a renewal succeeds and the served cert's serial/dates change. If
  still failing as expiry approaches (say by mid-to-late August), revisit
  and consider manual intervention (e.g. contact Tailscale support, or fall
  back to a different ACME path) with more urgency.

## Gotchas for next time

- `409 alreadyReplaced` from `tailscale cert` does **not** mean the local
  config is wrong — check `journalctl -u tailscaled` for the actual
  `SetDNS`/ACME sequence around the failure time first, before touching
  Caddyfile or the renewal script.
- The lock is server-side (Let's Encrypt/Boulder), not local — restarting
  tailscaled or cygnus does not clear it. It requires the stale order to
  expire, or a later renewal attempt to succeed and replace it.
- Diagnosing this needs `sudo journalctl -u tailscaled` — ask the user to
  run the journalctl command and paste output, since MCP sudo-exec on
  cygnus needs a password we don't have.
