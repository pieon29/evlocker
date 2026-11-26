#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVC="$(terraform -chdir="${ROOT}/terraform" output -raw service_url)"
mkdir -p "${ROOT}/evidence"
OUT="${ROOT}/evidence/web-failover-$(date +%m%d-%H%M%S).csv"
ts() { date +%H:%M:%S.%3N; }

bash "${ROOT}/scripts/probe.sh" "${SVC}healthz" 75 "${OUT}" > "${OUT}.summary" &
PROBE=$!
sleep 15
echo "[$(ts)] web01: stop nginx"
ssh evl-web01 'sudo systemctl stop nginx'
sleep 8
echo "[$(ts)] haproxy view"
ssh evl-bastion "curl -s 'http://127.0.0.1:8404/stats;csv' | cut -d, -f1,2,18 | grep -E '^be_https,web'"
sleep 22
echo "[$(ts)] web01: start nginx"
ssh evl-web01 'sudo systemctl start nginx'
sleep 8
echo "[$(ts)] haproxy view"
ssh evl-bastion "curl -s 'http://127.0.0.1:8404/stats;csv' | cut -d, -f1,2,18 | grep -E '^be_https,web'"
wait "${PROBE}"
cat "${OUT}.summary"
echo "== served by"
awk -F, 'NR>1 && $2=="200" {c[$3]++} END {for (k in c) print k, c[k]}' "${OUT}"
echo "== haproxy log (state changes)"
ssh evl-bastion "sudo grep -hE 'is DOWN|is UP' /var/log/haproxy.log /var/log/syslog 2>/dev/null | tail -n 4"
