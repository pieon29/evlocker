#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVC="$(terraform -chdir="${ROOT}/terraform" output -raw service_url)"
mkdir -p "${ROOT}/evidence"
OUT="${ROOT}/evidence/db-failover-$(date +%m%d-%H%M%S).csv"
ts() { date +%H:%M:%S.%3N; }
ms() { date +%s%3N; }
q() { ssh "evl-$1" "sudo -u postgres psql -tAc \"$2\" evlocker" 2>/dev/null; }

echo "== before"
echo "db01 recovery=$(q db01 'select pg_is_in_recovery()') evidence_rows=$(q db01 'select count(*) from evidence') custody_rows=$(q db01 'select count(*) from custody_events') wal=$(q db01 'select pg_current_wal_lsn()')"
echo "db02 recovery=$(q db02 'select pg_is_in_recovery()') replay=$(q db02 'select pg_last_wal_replay_lsn()')"

bash "${ROOT}/scripts/probe.sh" "${SVC}readyz" 90 "${OUT}" > "${OUT}.summary" &
PROBE=$!
sleep 15
T0=$(ms)
echo "[$(ts)] db01: stop postgresql (primary failure)"
ssh evl-db01 'sudo systemctl stop postgresql'
while true; do
  r="$(q db02 'select pg_is_in_recovery()')"
  if [ "${r}" = "f" ]; then
    T1=$(ms)
    echo "[$(ts)] db02 promoted to primary"
    break
  fi
  if [ $(( $(ms) - T0 )) -gt 120000 ]; then
    echo "[$(ts)] db02 not promoted within 120s"
    T1=$(ms)
    break
  fi
  sleep 0.5
done
echo "promotion_seconds=$(awk "BEGIN {printf \"%.1f\", (${T1}-${T0})/1000}")"
wait "${PROBE}"
cat "${OUT}.summary"

echo "== after"
echo "db02 recovery=$(q db02 'select pg_is_in_recovery()') evidence_rows=$(q db02 'select count(*) from evidence') custody_rows=$(q db02 'select count(*) from custody_events')"
echo "== failover log (db02)"
ssh evl-db02 'sudo journalctl -t evl-failover -t Keepalived_vrrp --since "-5 min" --no-pager -o short-iso | tail -n 8'
