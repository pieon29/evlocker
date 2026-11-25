resource "random_password" "db_app" {
  length  = 24
  special = false
}

resource "random_password" "db_replication" {
  length  = 24
  special = false
}

resource "random_password" "db_backup" {
  length  = 24
  special = false
}

resource "random_password" "token_investigator" {
  length  = 40
  special = false
}

resource "random_password" "token_auditor" {
  length  = 40
  special = false
}

resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

resource "random_password" "console" {
  length  = 20
  special = false
}

resource "random_password" "vrrp" {
  length  = 8
  special = false
}

resource "random_id" "app_enc_key" {
  byte_length = 32
}

resource "tls_private_key" "web" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "web" {
  private_key_pem       = tls_private_key.web.private_key_pem
  validity_period_hours = 2160
  dns_names             = [var.app_domain]
  ip_addresses          = [cloudstack_ipaddress.web.ip_address]

  subject {
    common_name  = var.app_domain
    organization = "evlocker lab ${var.name_prefix}"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
