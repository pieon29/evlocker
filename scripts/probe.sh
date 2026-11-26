#!/usr/bin/env bash
set -u
URL="${1:?usage: probe.sh <url> <seconds> [outfile]}"
SECS="${2:?seconds}"
OUT="${3:-probe-$(date +%H%M%S).csv}"
END=$(( $(date +%s) + SECS ))
echo "epoch_ms,code,node,time_s" > "${OUT}"
while [ "$(date +%s)" -lt "${END}" ]; do
  ts=$(date +%s%3N)
  res=$(curl -sk -m 2 -o /dev/null -D - -w "CODE=%{http_code} T=%{time_total}" "${URL}" 2>/dev/null | tr -d '\r')
  code=$(echo "${res}" | grep -o 'CODE=[0-9]*' | cut -d= -f2)
  t=$(echo "${res}" | grep -o 'T=[0-9.]*' | cut -d= -f2)
  node=$(echo "${res}" | grep -i '^x-served-by:' | awk '{print $2}')
  echo "${ts},${code:-000},${node:--},${t:-2}" >> "${OUT}"
  sleep 0.2
done
echo "saved ${OUT}"
awk -F, 'NR>1{n++; if($2!="200"){f++; if(!s)s=$1; e=$1}} END{printf "requests=%d failed=%d availability=%.3f%%\n", n, f, (n-f)*100/n; if(f) printf "first_fail_ms=%s last_fail_ms=%s outage_window_s=%.1f\n", s, e, (e-s)/1000}' "${OUT}"
