#!/usr/bin/env bash
set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
. /etc/evlocker/node.env
set +a

echo "[$(date -Is)] bootstrap start role=${ROLE} node=${NODE_NAME}"
. "${BOOT_DIR}/lib.sh"
. "${BOOT_DIR}/common.sh"
. "${BOOT_DIR}/${ROLE}.sh"
echo "[$(date -Is)] bootstrap done role=${ROLE} node=${NODE_NAME}"
touch /var/lib/evlocker-bootstrap.done
