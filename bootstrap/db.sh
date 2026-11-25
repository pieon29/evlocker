#!/usr/bin/env bash

apt_install postgresql postgresql-contrib keepalived prometheus-postgres-exporter
PGVER="$(ls /usr/lib/postgresql | sort -V | tail -1)"
apt_install "postgresql-${PGVER}-pgaudit" && PGAUDIT=1 || PGAUDIT=0
export PGVER

PGCONF="/etc/postgresql/${PGVER}/main"
PGDATA="/var/lib/postgresql/${PGVER}/main"

cat > "${PGCONF}/conf.d/evlocker.conf" <<EOF
listen_addresses = '*'
password_encryption = 'scram-sha-256'
ssl = on
wal_level = replica
max_wal_senders = 10
wal_keep_size = '1GB'
hot_standby = on
wal_log_hints = on
log_destination = 'stderr,syslog'
syslog_ident = 'postgres'
log_connections = on
log_disconnections = on
log_line_prefix = '%m [%p] %q%u@%d %r '
EOF

if [ "${PGAUDIT}" = "1" ]; then
  cat >> "${PGCONF}/conf.d/evlocker.conf" <<'EOF'
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'ddl,role'
EOF
fi

cat > "${PGCONF}/pg_hba.conf" <<EOF
local   all          postgres                     peer
local   all          prometheus                   peer
local   all          all                          peer
hostssl evlocker     evl_app      ${WEB_CIDR}     scram-sha-256
hostssl replication  replicator   ${DATA_CIDR}    scram-sha-256
hostssl postgres     replicator   ${DATA_CIDR}    scram-sha-256
hostssl replication  evl_backup   ${MGMT_CIDR}    scram-sha-256
hostssl evlocker     evl_backup   ${MGMT_CIDR}    scram-sha-256
EOF

install -m 0755 "${BOOT_DIR}/files/evl-pg-check" /usr/local/bin/evl-pg-check
install -m 0755 "${BOOT_DIR}/files/evl-pg-promote" /usr/local/bin/evl-pg-promote
install -m 0755 "${BOOT_DIR}/files/evl-db-rejoin" /usr/local/bin/evl-db-rejoin
install -d -m 0755 /etc/evlocker
echo "PGVER=${PGVER}" > /etc/evlocker/pg.env

if [ "${NODE_NAME}" = "db01" ]; then
  systemctl restart postgresql
  wait_for 30 pg_isready -q
  sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -v app_pw="${DB_APP_PASSWORD}" \
    -v repl_pw="${DB_REPL_PASSWORD}" \
    -v backup_pw="${DB_BACKUP_PASS}" \
    -f "${BOOT_DIR}/files/db-init.sql"
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d evlocker -f /opt/evlocker/app/schema.sql
else
  systemctl stop postgresql
  basebackup_from_primary() {
    rm -rf "${PGDATA:?}"/*
    sudo -u postgres env PGPASSWORD="${DB_REPL_PASSWORD}" PGSSLMODE=require \
      pg_basebackup -h "${DB1_IP}" -U replicator -D "${PGDATA}" -X stream -R
  }
  wait_for 120 basebackup_from_primary
  chmod 700 "${PGDATA}"
  systemctl start postgresql
  wait_for 30 pg_isready -q
fi

cat > /etc/default/prometheus-postgres-exporter <<'EOF'
DATA_SOURCE_NAME="user=prometheus host=/run/postgresql dbname=postgres sslmode=disable"
ARGS=""
EOF
systemctl enable --now prometheus-postgres-exporter
systemctl restart prometheus-postgres-exporter

IFACE="$(primary_iface)"
export IFACE
render "${BOOT_DIR}/files/keepalived.conf" /etc/keepalived/keepalived.conf \
  '${NODE_NAME} ${IFACE} ${DB_PRIORITY} ${NODE_IP} ${DB_PEER_IP} ${VRRP_PASS} ${DB_VIP}'
chmod 600 /etc/keepalived/keepalived.conf
systemctl enable keepalived
systemctl restart keepalived

if ! grep -q "evlocker-vrrp" /etc/ufw/before.rules; then
  sed -i "/^COMMIT/i -A ufw-before-input -p 112 -s ${DB_PEER_IP} -j ACCEPT -m comment --comment evlocker-vrrp" /etc/ufw/before.rules
fi
ufw allow from "${WEB_CIDR}" to any port 5432 proto tcp
ufw allow from "${MGMT_CIDR}" to any port 5432 proto tcp
ufw allow from "${DATA_CIDR}" to any port 5432 proto tcp
ufw allow from "${MGMT_CIDR}" to any port 9187 proto tcp
ufw --force enable
