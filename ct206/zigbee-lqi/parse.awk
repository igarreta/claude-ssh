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

/ROUTE_ERROR|ZIGBEE_DELIVERY_FAILED/ {
  code = "unknown"
  if (match($0, /(errorCode|status)=[A-Z_]+/)) {
    code = substr($0, RSTART, RLENGTH)
    sub(/^[a-zA-Z]+=/, "", code)
  }
  tgt = ""
  if (match($0, /target=[0-9]+/)) tgt = substr($0, RSTART + 7, RLENGTH - 7)
  f = out "/routeerr-" day ".csv"
  print ts "," code "," tgt >> f
  close(f)
}
