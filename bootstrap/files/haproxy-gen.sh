#!/usr/bin/env bash
set -euo pipefail

cat <<CFG
global
    log /dev/log local0
    maxconn 4000
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 3s
    timeout client 60s
    timeout server 60s

frontend fe_https
    bind :443
    default_backend be_https

frontend fe_http
    bind :80
    default_backend be_http

backend be_https
    balance roundrobin
    option httpchk
    http-check send meth GET uri /healthz
    http-check expect status 200
    default-server inter 2s fall 2 rise 2 check check-ssl verify none send-proxy-v2 check-send-proxy
CFG
n=0
for ip in ${WEB_IPS}; do
  n=$((n + 1))
  printf '    server web%02d %s:443\n' "${n}" "${ip}"
done
cat <<CFG

backend be_http
    balance roundrobin
    default-server inter 2s fall 2 rise 2 check send-proxy-v2 check-send-proxy
CFG
n=0
for ip in ${WEB_IPS}; do
  n=$((n + 1))
  printf '    server web%02d %s:80\n' "${n}" "${ip}"
done
cat <<CFG

listen stats
    bind 127.0.0.1:8404
    mode http
    stats enable
    stats uri /stats
CFG
