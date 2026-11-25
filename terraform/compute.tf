locals {
  ssh_key_file   = pathexpand(var.ssh_public_key_path)
  ssh_public_key = fileexists(local.ssh_key_file) ? trimspace(file(local.ssh_key_file)) : ""

  web_nodes = {
    for i in range(var.web_count) : format("web%02d", i + 1) => {
      tier = "web"
      ip   = cidrhost(var.web_cidr, 11 + i)
    }
  }

  db_nodes = {
    db01 = { tier = "data", ip = cidrhost(var.data_cidr, 11), priority = 110 }
    db02 = { tier = "data", ip = cidrhost(var.data_cidr, 12), priority = 100 }
  }

  mon_ip = cidrhost(var.mgmt_cidr, 11)
  db_vip = cidrhost(var.data_cidr, 100)

  tier_network_ids = {
    web  = cloudstack_network.web.id
    data = cloudstack_network.data.id
    mgmt = cloudstack_network.mgmt.id
  }

  common_env = {
    NAME_PREFIX = var.name_prefix
    VPC_CIDR    = var.vpc_cidr
    WEB_CIDR    = var.web_cidr
    DATA_CIDR   = var.data_cidr
    MGMT_CIDR   = var.mgmt_cidr
    WEB_IPS     = join(" ", [for n in local.web_nodes : n.ip])
    DB1_IP      = local.db_nodes.db01.ip
    DB2_IP      = local.db_nodes.db02.ip
    DB_VIP      = local.db_vip
    MON_IP      = local.mon_ip
  }

  web_env = merge(local.common_env, {
    ROLE               = "web"
    APP_IMAGE          = var.app_image
    APP_DOMAIN         = var.app_domain
    DB_APP_PASSWORD    = random_password.db_app.result
    APP_ENC_KEY        = random_id.app_enc_key.b64_std
    TOKEN_INVESTIGATOR = random_password.token_investigator.result
    TOKEN_AUDITOR      = random_password.token_auditor.result
  })

  db_env = merge(local.common_env, {
    ROLE             = "db"
    DB_APP_PASSWORD  = random_password.db_app.result
    DB_REPL_PASSWORD = random_password.db_replication.result
    DB_BACKUP_PASS   = random_password.db_backup.result
    VRRP_PASS        = random_password.vrrp.result
  })

  mon_env = merge(local.common_env, {
    ROLE                   = "mon"
    EDGE_IP                = cloudstack_ipaddress.web.ip_address
    APP_DOMAIN             = var.app_domain
    DB_BACKUP_PASS         = random_password.db_backup.result
    GRAFANA_ADMIN_PASSWORD = random_password.grafana_admin.result
    TOKEN_AUDITOR          = random_password.token_auditor.result
  })

  tls_files = [
    {
      path    = "/etc/evlocker/tls/server.crt"
      mode    = "0644"
      content = base64encode(tls_self_signed_cert.web.cert_pem)
    },
    {
      path    = "/etc/evlocker/tls/server.key"
      mode    = "0600"
      content = base64encode(tls_private_key.web.private_key_pem)
    },
  ]

  nodes = merge(
    { for k, v in local.web_nodes : k => merge(v, { env = local.web_env, files = local.tls_files }) },
    { for k, v in local.db_nodes : k => merge(v, { env = merge(local.db_env, { DB_PRIORITY = tostring(v.priority), DB_PEER_IP = k == "db01" ? local.db_nodes.db02.ip : local.db_nodes.db01.ip }), files = [] }) },
    { mon01 = { tier = "mgmt", ip = local.mon_ip, env = local.mon_env, files = [local.tls_files[0]] } },
  )
}

module "node" {
  source   = "./modules/vm"
  for_each = local.nodes

  name           = "${each.key}-${var.name_prefix}"
  offering_id    = data.cloudstack_service_offering.node.id
  template_id    = data.cloudstack_template.ubuntu.id
  zone           = data.cloudstack_zone.this.name
  network_id     = local.tier_network_ids[each.value.tier]
  ip_address     = each.value.ip
  root_disk_size = var.root_disk_size

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname         = each.key
    ssh_public_key   = local.ssh_public_key
    console_password = random_password.console.result
    env_b64          = base64encode(join("\n", concat([for k, v in merge(each.value.env, { NODE_NAME = each.key, NODE_IP = each.value.ip }) : "${k}='${v}'"], [""])))
    files            = each.value.files
    repo_url         = var.repo_url
    repo_ref         = var.repo_ref
  })

  depends_on = [
    cloudstack_network_acl_rule.web,
    cloudstack_network_acl_rule.data,
    cloudstack_network_acl_rule.mgmt,
  ]
}
