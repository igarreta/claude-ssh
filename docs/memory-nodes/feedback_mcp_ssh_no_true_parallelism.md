---
name: feedback_mcp_ssh_no_true_parallelism
description: "Two run-command MCP calls issued together are not concurrent on the remote host — they execute sequentially, breaking any race/timing test"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 97d638ec-9b13-4d17-b59f-d4177f7a58f7
  modified: 2026-08-26T21:26:52.628Z
---

Issuing two `mcp__<host>__run-command` calls in the same turn (e.g. one long-running
`mosquitto_sub` plus a delayed `mosquitto_pub`) does **not** run them concurrently on the
remote host — the connector appears to execute them sequentially, so the first command's full
duration (including any `timeout`) elapses before the second even starts.

**Why:** discovered 2026-08-26 debugging what looked like a broken mosquitto ACL for the
`tuyalink` user during [[project_mosquitto_broker_migration]] — a subscribe-then-publish pair
sent as two "parallel" tool calls always failed to deliver, across multiple accounts and
topics, making a perfectly healthy broker look broken. Wasted real time before the pattern was
recognized.

**How to apply:** never use two separate MCP `run-command` calls to test a race/timing
condition (pub before sub timeout, concurrent writers, etc.) on these SSH connectors. Instead
background both inside **one** command: `(mosquitto_sub ... -C 1 & sleep 2; mosquitto_pub
...; wait)`. If a result from a "parallel" pair looks like a failure, re-test with everything
in one command before trusting it.
