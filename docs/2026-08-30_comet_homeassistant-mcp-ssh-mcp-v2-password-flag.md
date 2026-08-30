# homeassistant MCP connector broken by ssh-mcp v2 (`--password` flag removed)

**Status:** closed
**Host:** comet
**Supersedes:** —
**Superseded-by:** —

## Symptom

The `homeassistant` MCP connector failed to connect (`CONNECTION_CLOSED`) while every
other SSH connector worked fine.

## Root cause

`.mcp.json` launches every SSH connector via `npx -y ssh-mcp`, which always pulls the
latest published version — there is no version pin. `ssh-mcp` shipped a v2 that removed
the `--password` CLI flag in favor of an `SSH_MCP_PASSWORD` env var (or per-profile
`SSH_MCP_<PROFILE>_PASSWORD`). `homeassistant` is the only connector using password auth
(`/home/rsi/etc/homeassistant-mcp.sh`, since `hassio@100.98.185.44` doesn't accept the
shared key) — v2 rejects the now-unknown `--password="$PASSWORD"` flag and exits
immediately, which the MCP client reports as a closed connection. Every other connector
uses `--key=`, still supported in v2, so they were unaffected.

Confirmed independently: `ssh` + `sshpass` with the stored password authenticated fine,
so the credential itself was never the problem — only the wrapper's flag.

## Fix

`/home/rsi/etc/homeassistant-mcp.sh` (not in a git repo, no version control):

```bash
# before
exec npx -y ssh-mcp -- --host=100.98.185.44 --user=hassio --password="$PASSWORD"
# after
export SSH_MCP_PASSWORD=$(cat ~/.ssh/homeassistant_password)
exec npx -y ssh-mcp -- --host=100.98.185.44 --user=hassio
```

Verified with a raw MCP `initialize` handshake before editing, and via `/mcp reconnect
homeassistant` afterward — both succeeded (ssh-mcp v2.5.0).

## Risk this can recur

Every SSH connector here still runs via unpinned `npx -y ssh-mcp`, so any future
breaking release can silently take down connectors again, one flag at a time. If it
happens again, check the connector's raw stdout by running the `npx` command directly
(see Fix section pattern) before assuming a network/credential problem.
