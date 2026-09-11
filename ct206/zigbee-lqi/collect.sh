#!/bin/bash
# zigbee-lqi collector — CT206 (zigbee2mqtt). Run every 5 min by zigbee-lqi.timer.
#
# zigbee2mqtt logs at debug with 3x10MB rotation, which leaves only ~22h of history —
# too short to track the LQI degradation across days. This reads whatever is new in the
# live log since the last run and appends it to daily CSVs that are not rotated away.
#
# A tail -F daemon was tried first and rejected: mawk block-buffers its input, so records
# only appeared in bursts ~13 min late. A byte cursor keeps the lag bounded and visible.

set -u

LOGROOT=/opt/zigbee2mqtt/data/log
BASE=/opt/zigbee-lqi
OUT=$BASE/data
STATE=$BASE/state/cursor

mkdir -p "$OUT" "$(dirname "$STATE")"

DIR=$(ls -1d "$LOGROOT"/*/ 2>/dev/null | sort | tail -1)
[ -n "$DIR" ] || { echo "no zigbee2mqtt log directory under $LOGROOT" >&2; exit 1; }
CUR="${DIR}log.log"
[ -f "$CUR" ] || { echo "no log.log in $DIR" >&2; exit 1; }

parse() {  # parse <file> <start-offset> <end-offset>
  local f=$1 from=$2 to=$3
  [ "$to" -gt "$from" ] || return 0
  tail -c "+$((from + 1))" "$f" | head -c "$((to - from))" \
    | awk -v out="$OUT" -v Q="'" -f "$BASE/parse.awk"
}

ino=$(stat -c %i "$CUR")
size=$(stat -c %s "$CUR")

p_dir=""; p_ino=""; p_off=0
[ -f "$STATE" ] && read -r p_dir p_ino p_off < "$STATE"
: "${p_off:=0}"

if [ "$p_dir" = "$DIR" ] && [ "$p_ino" = "$ino" ]; then
  # same file we were reading; truncation resets us to the start
  [ "$size" -lt "$p_off" ] && p_off=0
  parse "$CUR" "$p_off" "$size"
else
  # rotation (log.log -> log1.log) or a z2m restart into a new log directory:
  # finish the file we were on if it is still around, then take the new one whole
  if [ -n "$p_ino" ] && [ -f "${p_dir}log1.log" ] && [ "$(stat -c %i "${p_dir}log1.log")" = "$p_ino" ]; then
    parse "${p_dir}log1.log" "$p_off" "$(stat -c %s "${p_dir}log1.log")"
  fi
  parse "$CUR" 0 "$size"
fi

echo "$DIR $ino $size" > "$STATE"
find "$OUT" -name '*.csv' -mtime +180 -delete 2>/dev/null
exit 0
