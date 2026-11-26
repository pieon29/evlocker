locals {
  ssh_private_key = sensitive(fileexists(pathexpand(var.ssh_private_key_path)) ? file(pathexpand(var.ssh_private_key_path)) : "")

  ip     = { for k, m in module.node : k => m.ip_address }
  mon_ip = local.ip["mon01"]

  common_env = {
    NAME_PREFIX = var.name_prefix
    WEB_IPS     = join(" ", [for n in local.web_names : local.ip[n]])
    DB1_IP      = local.ip["db01"]
    DB2_IP      = local.ip["db02"]
    MON_IP      = local.mon_ip
    EDGE_IP     = local.mon_ip
    APP_DOMAIN  = var.app_domain
  }

  role_env = {
    web = {
      APP_IMAGE          = var.app_image
      API_RATE_LIMIT     = tostring(var.api_rate_limit)
      DB_APP_PASSWORD    = random_password.db_app.result
      APP_ENC_KEY        = random_id.app_enc_key.b64_std
      TOKEN_INVESTIGATOR = random_password.token_investigator.result
      TOKEN_AUDITOR      = random_password.token_auditor.result
    }
    db = {
      DB_APP_PASSWORD  = random_password.db_app.result
      DB_REPL_PASSWORD = random_password.db_replication.result
      DB_BACKUP_PASS   = random_password.db_backup.result
      VRRP_PASS        = random_password.vrrp.result
    }
    mon = {
      DB_BACKUP_PASS         = random_password.db_backup.result
      GRAFANA_ADMIN_PASSWORD = random_password.grafana_admin.result
      TOKEN_AUDITOR          = random_password.token_auditor.result
    }
  }

  db_extra = {
    db01 = { DB_PRIORITY = "110", DB_PEER_IP = local.ip["db02"] }
    db02 = { DB_PRIORITY = "100", DB_PEER_IP = local.ip["db01"] }
  }

  node_env = {
    for k, role in local.roles : k => merge(
      local.common_env,
      local.role_env[role],
      lookup(local.db_extra, k, {}),
      { ROLE = role, NODE_NAME = k, NODE_IP = local.ip[k] },
    )
  }

  node_env_content = {
    for k, env in local.node_env : k => join("\n", concat([for ek, ev in env : "${ek}='${ev}'"], [""]))
  }

  tls_cert = { path = "/etc/evlocker/tls/server.crt", mode = "0644", content = tls_self_signed_cert.web.cert_pem }
  tls_key  = { path = "/etc/evlocker/tls/server.key", mode = "0600", content = tls_private_key.web.private_key_pem }

  role_files = {
    web = [local.tls_cert, local.tls_key]
    db  = []
    mon = [local.tls_cert]
  }

  node_files_script = {
    for k, role in local.roles : k => join("\n", concat(
      ["set -eu"],
      flatten([for f in local.role_files[role] : [
        "install -d -m 0755 \"$(dirname ${f.path})\"",
        "printf '%s' '${base64encode(f.content)}' | base64 -d > ${f.path}",
        "chmod ${f.mode} ${f.path}",
      ]]),
      [""],
    ))
  }
}

resource "terraform_data" "bootstrap" {
  for_each = local.roles

  triggers_replace = {
    instance = module.node[each.key].id
    repo_ref = var.repo_ref
    env      = sha256(local.node_env_content[each.key])
    files    = sha256(local.node_files_script[each.key])
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    host                = local.ip[each.key]
    private_key         = local.ssh_private_key
    bastion_host        = each.key == "mon01" ? null : local.mon_ip
    bastion_user        = "ubuntu"
    bastion_private_key = local.ssh_private_key
    timeout             = "15m"
  }

  provisioner "file" {
    content     = local.node_env_content[each.key]
    destination = "/home/ubuntu/.evl-node.env"
  }

  provisioner "file" {
    content     = local.node_files_script[each.key]
    destination = "/home/ubuntu/.evl-files.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "cloud-init status --wait >/dev/null 2>&1 || true",
      "echo \"[evl] $(hostname) $(ip -o -4 addr show scope global | awk '{print $4}' | head -1)\"",
      "sudo install -d -m 0755 /etc/evlocker",
      "sudo install -m 0600 /home/ubuntu/.evl-node.env /etc/evlocker/node.env",
      "sudo bash /home/ubuntu/.evl-files.sh",
      "rm -f /home/ubuntu/.evl-node.env /home/ubuntu/.evl-files.sh",
      "sudo rm -rf /opt/evlocker",
      "for i in 1 2 3 4 5; do sudo git clone -q ${var.repo_url} /opt/evlocker && break; sleep 5; done",
      "sudo git -C /opt/evlocker checkout -q ${var.repo_ref}",
      "sudo bash -c 'bash /opt/evlocker/bootstrap/run.sh >> /var/log/evlocker-bootstrap.log 2>&1 || { tail -n 40 /var/log/evlocker-bootstrap.log; exit 1; }'",
      "sudo tail -n 2 /var/log/evlocker-bootstrap.log",
    ]
  }
}
