# cygnus: Caddy TLS reverse proxy + Tailscale cert auto-renewal

**Date:** 2026-06-22
**Host:** cygnus (LXC in gr-srv03)

## What runs

Caddy (`v2.11.4`, systemd `caddy.service`, enabled) is the web front end on
cygnus, listening on :80 and :443.

`/etc/caddy/Caddyfile`:
```
:80 {
	root * /usr/share/caddy
	file_server
}
cygnus.tail366c79.ts.net {
    tls /etc/caddy/cygnus.crt /etc/caddy/cygnus.key
    reverse_proxy localhost:5050
}
```

- `https://cygnus.tail366c79.ts.net` → reverse-proxies to **pgАdmin** (container
  `pgadmin_pgadmin_1`, published `0.0.0.0:5050->80`).
- The user's browser refuses plain HTTP, so HTTPS via this domain is the access
  path (not `http://100.96.140.37:5050`).

## TLS certificate

- Tailscale-issued (Let's Encrypt), `CN=cygnus.tail366c79.ts.net`, 90-day lifetime.
- Served from **static files** `/etc/caddy/cygnus.crt` / `cygnus.key`, owned
  `caddy:caddy` (crt 644, key 600). NOT Caddy-managed ACME.

## The issue: no auto-renewal (fixed 2026-06-22)

Because the `tls` directive points at static files, **Caddy does not renew them**,
and there was no cron/timer doing it either — the cert would have expired and
broken HTTPS.

### Why Caddy can't self-manage it (option rejected)
Caddy's native `tls { get_certificate tailscale }` would auto-renew, but Caddy
runs as user `caddy`, and the Tailscale **operator is `rsi`**. Fetching a cert via
the Tailscale LocalAPI is restricted to the operator/root:
```
$ sudo -u caddy tailscale cert ... cygnus.tail366c79.ts.net
Access denied: cert access denied
```
Making it work would need `sudo tailscale set --operator=caddy`, which moves the
operator off `rsi` and forces `rsi` to use sudo for all `tailscale` commands —
rejected.

### Fix applied: root-run renewal cron
- Script: `/usr/local/sbin/renew-caddy-cert.sh` (root). Runs
  `tailscale cert --min-validity 720h --cert-file /etc/caddy/cygnus.crt
  --key-file /etc/caddy/cygnus.key cygnus.tail366c79.ts.net`, then **chowns the
  files back to `caddy:caddy`** (root would otherwise leave the key unreadable by
  Caddy → HTTPS breaks), and reloads Caddy only if the cert changed. Sends a
  Pushover alert on failure (`/home/rsi/etc/pushover.env`).
- Cron: `/etc/cron.d/caddy-cert-renew` — `17 4 * * 1 root ...` (weekly Mon 04:17).
- `--min-validity 720h` → renews ~30 days before expiry; idempotent the rest of
  the time (no rewrite, no reload).

Source files for the script/cron live in the claude-ssh repo workflow; reinstall with:
```
sudo install -m 755 -o root -g root renew-caddy-cert.sh /usr/local/sbin/renew-caddy-cert.sh
sudo install -m 644 -o root -g root caddy-cert-renew     /etc/cron.d/caddy-cert-renew
```

## Gotchas for next time
- `listen_addresses`-style static cert front ends don't self-renew — always
  check for a renewal job when you see `tls <file> <file>` in a Caddyfile.
- Running `tailscale cert` as root rewrites the output files as `root:root`;
  **chown back to the service user** or the daemon loses read access to the key.
- The operator restriction (`cert access denied`) is the key reason Caddy can't
  do this itself here.
