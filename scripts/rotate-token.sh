#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVC="$(terraform -chdir="${ROOT}/terraform" output -raw service_url)"
mkdir -p "${ROOT}/evidence"
OUT="${ROOT}/evidence/token-rotation-$(date +%m%d-%H%M%S).csv"
ts() { date +%H:%M:%S; }
code() { curl -sk -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $1" "${SVC}api/evidence?case_no=CASE-LOAD-1"; }

OLD="$(terraform -chdir="${ROOT}/terraform" output -raw token_investigator)"
echo "[$(ts)] before rotation: old_token=$(code "${OLD}")"

bash "${ROOT}/scripts/probe.sh" "${SVC}healthz" 240 "${OUT}" > "${OUT}.summary" &
PROBE=$!
echo "[$(ts)] terraform apply -replace=random_password.token_investigator (confirm with yes)"
T0=$(date +%s)
terraform -chdir="${ROOT}/terraform" apply -replace=random_password.token_investigator -parallelism=1
T1=$(date +%s)
echo "[$(ts)] apply finished in $((T1 - T0))s"

NEW="$(terraform -chdir="${ROOT}/terraform" output -raw token_investigator)"
if [ "${OLD}" = "${NEW}" ]; then echo "token unchanged"; else echo "token changed"; fi
echo "[$(ts)] after rotation: old_token=$(code "${OLD}") new_token=$(code "${NEW}")"
unset OLD NEW
wait "${PROBE}"
cat "${OUT}.summary"
