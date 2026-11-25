#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${HOME}/.ssh"
touch "${HOME}/.ssh/config"
sed -i '/^# evlocker-begin$/,/^# evlocker-end$/d' "${HOME}/.ssh/config"
{
  echo "# evlocker-begin"
  terraform -chdir="${ROOT}/terraform" output -raw ssh_config
  echo "# evlocker-end"
} >> "${HOME}/.ssh/config"
echo "added hosts: evl-bastion evl-web01 evl-web02 evl-db01 evl-db02"
