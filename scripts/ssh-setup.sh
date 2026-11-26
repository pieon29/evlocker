#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${HOME}/.ssh"
touch "${HOME}/.ssh/config" "${HOME}/.ssh/known_hosts"
CFG="$(terraform -chdir="${ROOT}/terraform" output -raw ssh_config)"
for ip in $(echo "${CFG}" | awk '/HostName/ {print $2}'); do
  ssh-keygen -R "${ip}" >/dev/null 2>&1 || true
done
sed -i '/^# evlocker-begin$/,/^# evlocker-end$/d' "${HOME}/.ssh/config"
{
  echo "# evlocker-begin"
  echo "${CFG}"
  echo "Host evl-*"
  echo "  StrictHostKeyChecking accept-new"
  echo "  ConnectTimeout 15"
  echo "# evlocker-end"
} >> "${HOME}/.ssh/config"
echo "added hosts: evl-bastion evl-web01 evl-web02 evl-db01 evl-db02"
