#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORTS="22 80 443 514 3000 5432 8000 8080 8404 8443 9090 9100 9113 9115 9187"
terraform -chdir="${ROOT}/terraform" output -raw ssh_config | awk '/^Host /{h=$2} /HostName/{print h, $2}' | while read -r host ip; do
  open=""
  for p in ${PORTS}; do
    if timeout 2 bash -c "exec 3<>/dev/tcp/${ip}/${p}" 2>/dev/null; then open="${open} ${p}"; fi
  done
  echo "${host} ${ip} open_from_outside:${open:- none}"
done
echo "== host firewall rules"
for h in bastion web01 db01; do
  echo "-- ${h}"
  ssh -n "evl-${h}" 'sudo ufw status | sed -n "5,40p"'
done
