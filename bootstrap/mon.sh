#!/usr/bin/env bash

apt_install docker.io docker-compose-v2 postgresql-client fail2ban openssl bc

cat > /etc/rsyslog.d/10-remote.conf <<'EOF'
module(load="imtcp")
template(name="EvlRemoteFile" type="string" string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")
ruleset(name="evl_remote") {
  action(type="omfile" dynaFile="EvlRemoteFile" dirCreateMode="0750" fileCreateMode="0640")
  stop
}
input(type="imtcp" port="514" ruleset="evl_remote")
EOF
install -d -o syslog -g adm -m 0750 /var/log/remote
cat > /etc/logrotate.d/evl-remote <<'EOF'
/var/log/remote/*/*.log {
    daily
    rotate 400
    dateext
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF
systemctl restart rsyslog
systemctl enable --now fail2ban

install -d -m 0700 /srv/backup /srv/backup/dumps /srv/backup/base /srv/backup/wal
if [ ! -s /etc/evlocker/backup.key ]; then
  umask 077
  openssl rand -base64 48 > /etc/evlocker/backup.key
  umask 022
fi
umask 077
cat > /root/.pgpass <<EOF
*:5432:evlocker:evl_backup:${DB_BACKUP_PASS}
*:5432:replication:evl_backup:${DB_BACKUP_PASS}
*:5432:postgres:evl_backup:${DB_BACKUP_PASS}
EOF
umask 022

for f in evl-backup-dump evl-backup-base evl-restore-drill; do
  install -m 0755 "${BOOT_DIR}/files/${f}" "/usr/local/bin/${f}"
done
for u in evl-backup-dump.service evl-backup-dump.timer evl-backup-base.service evl-backup-base.timer evl-receivewal.service; do
  install -m 0644 "${BOOT_DIR}/files/${u}" "/etc/systemd/system/${u}"
done
install -d -m 0755 /var/lib/prometheus/node-exporter
systemctl daemon-reload

install -d -m 0755 /etc/docker
printf '{\n  "log-driver": "journald",\n  "mtu": 1400\n}\n' > /etc/docker/daemon.json
systemctl enable --now docker
systemctl restart docker
MON_DIR=/opt/evlocker-mon
install -d -m 0755 "${MON_DIR}" "${MON_DIR}/rules" "${MON_DIR}/grafana/provisioning/datasources" "${MON_DIR}/grafana/provisioning/dashboards" "${MON_DIR}/grafana/dashboards"
cp /etc/evlocker/tls/server.crt "${MON_DIR}/edge-ca.crt"
cp /opt/evlocker/monitoring/compose.yaml "${MON_DIR}/compose.yaml"
cp /opt/evlocker/monitoring/rules/*.yml "${MON_DIR}/rules/"
cp /opt/evlocker/monitoring/blackbox.yml "${MON_DIR}/blackbox.yml"
cp /opt/evlocker/monitoring/grafana/datasource.yml "${MON_DIR}/grafana/provisioning/datasources/"
cp /opt/evlocker/monitoring/grafana/dashboards.yml "${MON_DIR}/grafana/provisioning/dashboards/"
cp /opt/evlocker/monitoring/grafana/evlocker.json "${MON_DIR}/grafana/dashboards/"
bash /opt/evlocker/monitoring/gen-prometheus.sh > "${MON_DIR}/prometheus.yml"
umask 077
printf 'GF_SECURITY_ADMIN_PASSWORD=%s\n' "${GRAFANA_ADMIN_PASSWORD}" > "${MON_DIR}/grafana.env"
umask 022
wait_for 20 docker compose -f "${MON_DIR}/compose.yaml" pull
docker compose -f "${MON_DIR}/compose.yaml" up -d

wait_for 60 pg_isready -q -h "${DB_VIP}"
systemctl enable --now evl-receivewal.service
systemctl enable --now evl-backup-dump.timer evl-backup-base.timer
systemctl start evl-backup-dump.service || true

ufw allow 22/tcp
ufw allow from "${WEB_CIDR}" to any port 514 proto tcp
ufw allow from "${DATA_CIDR}" to any port 514 proto tcp
ufw --force enable
