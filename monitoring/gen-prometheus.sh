#!/usr/bin/env bash
set -euo pipefail

list() {
  local port="$1" out="" ip
  shift
  for ip in "$@"; do
    out="${out}'${ip}:${port}', "
  done
  echo "[${out%, }]"
}

read -r -a WEBS <<< "${WEB_IPS}"
DBS=("${DB1_IP}" "${DB2_IP}")
ALL=("${WEBS[@]}" "${DBS[@]}" "${MON_IP}")

web_probe=""
for ip in "${WEBS[@]}"; do
  web_probe="${web_probe}'https://${ip}:8443/healthz', "
done

cat <<YAML
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: node
    static_configs:
      - targets: $(list 9100 "${ALL[@]}")

  - job_name: nginx
    static_configs:
      - targets: $(list 9113 "${WEBS[@]}")

  - job_name: app
    scheme: https
    tls_config:
      ca_file: /etc/prometheus/edge-ca.crt
      server_name: ${APP_DOMAIN}
    static_configs:
      - targets: $(list 8443 "${WEBS[@]}")

  - job_name: postgres
    static_configs:
      - targets: $(list 9187 "${DBS[@]}")

  - job_name: blackbox-web
    metrics_path: /probe
    params:
      module: [https_health]
    static_configs:
      - targets: [${web_probe%, }]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115

  - job_name: blackbox-edge
    metrics_path: /probe
    params:
      module: [https_health]
    static_configs:
      - targets: ['https://${EDGE_IP}/healthz']
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115
YAML
