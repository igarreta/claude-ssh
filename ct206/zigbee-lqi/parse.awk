# Parse zigbee2mqtt log lines into daily CSVs.
#   -v out=<dir>   output directory
#   -v Q=<'>       a single quote (awk string literals cannot carry one)

{ ts = substr($0, 2, 19); day = substr($0, 2, 10) }

index($0, "MQTT publish: topic " Q "zigbee2mqtt/") && index($0, "\"linkquality\":") {
  prefix = "MQTT publish: topic " Q "zigbee2mqtt/"
  rest = substr($0, index($0, prefix) + length(prefix))
  e = index(rest, Q)
  if (e < 2) next
  dev = substr(rest, 1, e - 1)
  if (dev ~ /^bridge/) next
  if (!match($0, /"linkquality":[0-9]+/)) next
  q = substr($0, RSTART + 14, RLENGTH - 14) + 0
  f = out "/lqi-" day ".csv"
  print ts "," dev "," q >> f
  close(f)
  next
}

# Route errors.
#
# IMPORTANT (2026-09-13): z2m's log_level went debug -> info. Under debug ONE route error
# emitted 3-4 lines matching the old broad /ROUTE_ERROR/ pattern (ezspIncomingNetworkStatus-
# Handler + the info summary + the INCOMING_ROUTE_ERROR_HANDLER CBFRAME + ezspIncoming-
# RouteErrorHandler); under info only the summary survives. The old parser counted all of
# them, so **every routeerr-*.csv dated before 2026-09-13 is inflated ~3-4x** and is NOT
# comparable with later files. Those logs are long rotated, so they cannot be recomputed.
#
# Fix: count the ONE line that z2m emits at info level, which is present in both eras:
#   Received network/route error ROUTE_ERROR_SOURCE_ROUTE_FAILURE for "43800".
# That yields exactly one row per route error regardless of log_level, so counts from
# 2026-09-13 onward are stable and mutually comparable.
/Received network\/route error/ {
  code = "unknown"
  if (match($0, /ROUTE_ERROR[A-Z_]*/)) code = substr($0, RSTART, RLENGTH)
  tgt = ""
  if (match($0, /for "[0-9]+"/)) tgt = substr($0, RSTART + 5, RLENGTH - 6)
  f = out "/routeerr-" day ".csv"
  print ts "," code "," tgt >> f
  close(f)
  next
}

# Failed unicast deliveries are a DIFFERENT event from a route error, and z2m logs them
# only at debug — so this line records nothing while log_level is info. Kept so the metric
# reappears intact if debug is ever turned back on for an investigation.
/ZIGBEE_DELIVERY_FAILED/ {
  code = "ZIGBEE_DELIVERY_FAILED"
  tgt = ""
  if (match($0, /indexOrDestination=[0-9]+/)) tgt = substr($0, RSTART + 19, RLENGTH - 19)
  else if (match($0, /target=[0-9]+/)) tgt = substr($0, RSTART + 7, RLENGTH - 7)
  f = out "/delivfail-" day ".csv"
  print ts "," code "," tgt >> f
  close(f)
}
