#!/bin/bash
# zigbee-lqi report — summarise the collector CSVs.
#   report.sh            daily averages per device + route errors per day
#   report.sh hourly [N] fleet hourly trend over the last N days (default 2)

set -u
DATA=/opt/zigbee-lqi/data
MODE=${1:-daily}
DAYS=${2:-2}

if [ "$MODE" = hourly ]; then
  echo "== hourly: fleet LQI (Enchufe_1, Enchufe_2, luces medianera z) + route errors =="
  awk -F, '
    FILENAME ~ /\/lqi-/ {
      if ($2 != "Enchufe_1" && $2 != "Enchufe_2" && $2 != "luces medianera z") next
      h = substr($1, 1, 13); s[h] += $3; n[h]++; hh[h] = 1
    }
    FILENAME ~ /\/routeerr-/ { h = substr($1, 1, 13); e[h]++; hh[h] = 1 }
    END {
      for (h in hh)
        printf "%s  lqi=%6.1f  n=%-5d  routeerr=%d\n", h, (n[h] ? s[h]/n[h] : 0), n[h]+0, e[h]+0
    }' $(ls -1 "$DATA"/lqi-*.csv | tail -"$DAYS") $(ls -1 "$DATA"/routeerr-*.csv | tail -"$DAYS") | sort
  exit 0
fi

echo "== daily: average linkquality per device =="
cat "$DATA"/lqi-*.csv 2>/dev/null | awk -F, '
  { d=substr($1,1,10); k=$2"|"d; s[k]+=$3; n[k]++ }
  END { for (k in s) { split(k,a,"|"); printf "%-30s %s  %6.1f  n=%d\n", a[1], a[2], s[k]/n[k], n[k] } }' | sort

echo
echo "== daily: route errors =="
cat "$DATA"/routeerr-*.csv 2>/dev/null | awk -F, '
  { d[substr($1,1,10)]++ } END { for (k in d) printf "%s  %d\n", k, d[k] }' | sort
