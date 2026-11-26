#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVC="$(terraform -chdir="${ROOT}/terraform" output -raw service_url)"
MON="$(echo "${SVC}" | sed -E 's#https://([^/]+)/#\1#')"
ts() { date +%H:%M:%S; }

echo "[$(ts)] phase 1: token brute force with 60 forged tokens"
for i in $(seq 1 60); do
  curl -sk -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer forged-token-${i}-$(date +%N)" "${SVC}api/evidence?case_no=CASE-LOAD-1"
done | sort | uniq -c

echo "[$(ts)] phase 2: flood 300 req/s for 10s with forged tokens (rate limit)"
K6="k6"
command -v k6 >/dev/null 2>&1 || K6="/c/Program Files/k6/k6.exe"
"${K6}" run -q -e BASE_URL="${SVC%/}" "${ROOT}/tests/load/k6-flood.js" 2>&1 | grep -E 'status_|http_reqs'

echo "[$(ts)] detection: auth failures seen by the app (prometheus)"
sleep 20
ssh evl-bastion "curl -s 'http://127.0.0.1:9090/api/v1/query' --data-urlencode 'query=sum(increase(evl_auth_failures_total[5m]))' | jq -r '.data.result[0].value[1]'"
echo "[$(ts)] detection: alert state"
ssh evl-bastion "curl -s http://127.0.0.1:9090/api/v1/rules | jq -r '.data.groups[].rules[] | select(.name==\"AuthFailureBurst\") | \"\(.name) \(.state)\"'"

echo "[$(ts)] tracing: source IPs in central log on mon01"
ssh evl-bastion "sudo grep -rh 'auth_failed' /var/log/remote 2>/dev/null | grep -oE 'remote=[0-9.]+' | sort | uniq -c | sort -rn | head -3"
ATTACKER="$(ssh evl-bastion "sudo grep -rh 'auth_failed' /var/log/remote 2>/dev/null | grep -oE 'remote=[0-9.]+' | sort | uniq -c | sort -rn | head -1 | sed -E 's/.*remote=//'")"
if [ -z "${ATTACKER}" ]; then
  echo "central log empty, reading web01 container log"
  ATTACKER="$(ssh evl-web01 "sudo docker logs --since 10m evlocker 2>&1 | grep auth_failed | grep -oE 'remote=[0-9.]+' | sort | uniq -c | sort -rn | head -1 | sed -E 's/.*remote=//'")"
fi
echo "attacker_ip=${ATTACKER}"
echo "rate-limited (429) in nginx log: $(ssh evl-web01 "sudo grep -c ' 429 ' /var/log/nginx/access.log") on web01, $(ssh evl-web02 "sudo grep -c ' 429 ' /var/log/nginx/access.log") on web02"

if [ -n "${ATTACKER}" ]; then
  echo "[$(ts)] response: block ${ATTACKER} on edge 443/80 (ssh stays open)"
  ssh evl-bastion "sudo ufw insert 1 deny proto tcp from ${ATTACKER} to any port 443 && sudo ufw insert 1 deny proto tcp from ${ATTACKER} to any port 80"
  curl -sk -m 5 -o /dev/null -w "after block: %{http_code}\n" "${SVC}healthz" || echo "after block: connection dropped"
  ssh evl-bastion "sudo ufw status numbered | grep -E 'DENY' "
  echo "[$(ts)] recovery: remove block"
  ssh evl-bastion "sudo ufw delete deny proto tcp from ${ATTACKER} to any port 443 && sudo ufw delete deny proto tcp from ${ATTACKER} to any port 80"
  curl -sk -m 5 -o /dev/null -w "after unblock: %{http_code}\n" "${SVC}healthz"
fi
echo "edge=${MON}"
