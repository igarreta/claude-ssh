#!/bin/bash
# renew-caddy-cert.sh
# Renew the Tailscale-issued TLS cert that Caddy serves on cygnus and reload
# Caddy only if the cert changed. Must run as root: the Tailscale operator is
# 'rsi', so the 'caddy' user cannot fetch certs via the LocalAPI itself.
set -euo pipefail

DOMAIN="cygnus.tail366c79.ts.net"
CRT="/etc/caddy/cygnus.crt"
KEY="/etc/caddy/cygnus.key"
MIN_VALIDITY="720h"          # renew when fewer than ~30 days remain
PUSHOVER_ENV="/home/rsi/etc/pushover.env"
SCRIPT="$(basename "$0")"
HOST="$(hostname)"

notify() {
    [ -f "$PUSHOVER_ENV" ] || return 0
    # shellcheck disable=SC1090
    . "$PUSHOVER_ENV"
    curl -s --max-time 15 \
        --form-string "token=${PUSHOVER_TOKEN}" \
        --form-string "user=${PUSHOVER_USER}" \
        --form-string "device=${DEFAULT_DEVICE:-}" \
        --form-string "title=${HOST} ${SCRIPT}" \
        --form-string "message=$1" \
        https://api.pushover.net/1/messages.json >/dev/null || true
}

before="$(sha256sum "$CRT" 2>/dev/null | awk '{print $1}' || true)"

if ! tailscale cert --min-validity "$MIN_VALIDITY" \
        --cert-file "$CRT" --key-file "$KEY" "$DOMAIN" >/dev/null 2>&1; then
    notify "tailscale cert FAILED for ${DOMAIN}"
    echo "ERROR: tailscale cert failed for ${DOMAIN}" >&2
    exit 1
fi

# tailscale cert writes the files as root; Caddy runs as 'caddy' and the key is
# mode 600, so ownership must be returned to caddy or HTTPS breaks.
chown caddy:caddy "$CRT" "$KEY"

after="$(sha256sum "$CRT" 2>/dev/null | awk '{print $1}' || true)"

if [ "$before" != "$after" ]; then
    if systemctl reload caddy; then
        notify "TLS cert for ${DOMAIN} renewed; Caddy reloaded"
    else
        notify "cert renewed but 'systemctl reload caddy' FAILED"
        echo "ERROR: caddy reload failed" >&2
        exit 1
    fi
fi
