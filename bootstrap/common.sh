#!/usr/bin/env bash

echo "mtu: $(ip -o link show "$(primary_iface)" | grep -o 'mtu [0-9]*')"
apt-get update -y
apt_install ca-certificates curl gettext-base jq ufw chrony rsyslog prometheus-node-exporter unattended-upgrades

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-evlocker.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
MaxAuthTries 3
AllowUsers ubuntu
X11Forwarding no
AllowAgentForwarding no
EOF
systemctl restart ssh || systemctl restart sshd

if [ "${ROLE}" != "mon" ]; then
  cat > /etc/rsyslog.d/90-forward.conf <<EOF
*.* action(type="omfwd" target="${MON_IP}" port="514" protocol="tcp"
           action.resumeRetryCount="-1" queue.type="LinkedList" queue.size="10000"
           queue.filename="fwd_mon" queue.saveOnShutdown="on")
EOF
  systemctl restart rsyslog
fi

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow from "${MON_IP}" to any port 22 proto tcp
ufw allow from "${MON_IP}" to any port 9100 proto tcp

systemctl enable --now prometheus-node-exporter chrony
