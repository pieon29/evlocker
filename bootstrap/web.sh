#!/usr/bin/env bash

apt_install docker.io nginx prometheus-nginx-exporter

install -d -m 0755 /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "journald",
  "live-restore": true,
  "no-new-privileges": true
}
EOF
systemctl enable --now docker
systemctl restart docker

umask 077
cat > /etc/evlocker/app.env <<EOF
DATABASE_URL=postgresql://evl_app:${DB_APP_PASSWORD}@${DB_VIP}:5432/evlocker?sslmode=require&connect_timeout=3
APP_ENC_KEY=${APP_ENC_KEY}
TOKEN_INVESTIGATOR=${TOKEN_INVESTIGATOR}
TOKEN_AUDITOR=${TOKEN_AUDITOR}
NODE_NAME=${NODE_NAME}
EOF
umask 022

install -m 0755 "${BOOT_DIR}/files/evl-app-deploy" /usr/local/bin/evl-app-deploy
wait_for 30 /usr/local/bin/evl-app-deploy "${APP_IMAGE}"

export MGMT_CIDR APP_DOMAIN
render "${BOOT_DIR}/files/nginx-evlocker.conf" /etc/nginx/sites-available/evlocker '${MGMT_CIDR} ${APP_DOMAIN}'
ln -sf /etc/nginx/sites-available/evlocker /etc/nginx/sites-enabled/evlocker
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

cat > /etc/default/prometheus-nginx-exporter <<'EOF'
ARGS="-nginx.scrape-uri=http://127.0.0.1:8080/stub_status"
EOF
systemctl enable --now prometheus-nginx-exporter
systemctl restart prometheus-nginx-exporter

ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from "${MGMT_CIDR}" to any port 9113 proto tcp
ufw --force enable
