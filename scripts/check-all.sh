#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVC="$(terraform -chdir="${ROOT}/terraform" output -raw service_url)"
MON="$(echo "${SVC}" | sed -E 's#https://([^/]+)/#\1#')"
WEB1="$(ssh evl-web01 'hostname -I' | awk '{print $1}')"

echo "== service via HAProxy (${MON})"
curl -sk -o /dev/null -w "healthz %{http_code}\n" "${SVC}healthz"
curl -sk -o /dev/null -w "readyz  %{http_code}\n" "${SVC}readyz"
curl -sk -o /dev/null -w "metrics-from-outside %{http_code} (403 expected)\n" "${SVC}metrics"

echo "== direct access to web01 (${WEB1}) must be blocked"
for p in 443 8443 80; do
  curl -sk -m 4 -o /dev/null -w "web01:${p} %{http_code}\n" "https://${WEB1}:${p}/healthz" 2>/dev/null || echo "web01:${p} blocked"
done

echo "== bootstrap"
for h in bastion web01 web02 db01 db02; do
  printf '%s: ' "${h}"
  ssh "evl-${h}" 'test -f /var/lib/evlocker-bootstrap.done && echo DONE || echo NOT-DONE'
done

echo "== database (db01 f + replicas, db02 t)"
ssh evl-db01 "sudo -u postgres psql -tA -c 'select pg_is_in_recovery()' -c 'select client_addr, state from pg_stat_replication'"
ssh evl-db02 "sudo -u postgres psql -tA -c 'select pg_is_in_recovery()'"

echo "== haproxy"
ssh evl-bastion "curl -s 'http://127.0.0.1:8404/stats;csv' | cut -d, -f1,2,18 | grep -E 'web0'"

echo "== backup"
ssh evl-bastion 'sudo ls -l /srv/backup/dumps | tail -2; sudo cat /var/lib/prometheus/node-exporter/evl_backup.prom 2>/dev/null || echo "no backup metric yet"'

echo "== prometheus targets"
ssh evl-bastion "curl -s http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | \"\(.health) \(.labels.job) \(.labels.instance)\"' | sort | uniq -c | sort -rn"

echo "== real client IP in nginx access log (web01)"
curl -sk -o /dev/null "${SVC}version"
curl -sk -o /dev/null "${SVC}version"
ssh evl-web01 'sudo tail -n 2 /var/log/nginx/access.log'
