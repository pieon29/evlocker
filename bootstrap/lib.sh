#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

apt_install() {
  local _
  for _ in 1 2 3 4 5; do
    if apt-get install -y --no-install-recommends "$@"; then
      return 0
    fi
    sleep 10
    apt-get update -y || true
  done
  return 1
}

primary_iface() {
  ip -o -4 route show default | awk '{print $5; exit}'
}

render() {
  local src="$1" dst="$2" vars="$3"
  envsubst "${vars}" < "${src}" > "${dst}"
}

wait_for() {
  local tries="$1"
  shift
  local _
  for _ in $(seq 1 "${tries}"); do
    if "$@"; then
      return 0
    fi
    sleep 10
  done
  return 1
}
