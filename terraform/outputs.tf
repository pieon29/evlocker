output "service_url" {
  value = "https://${cloudstack_ipaddress.web.ip_address}/"
}

output "bastion" {
  value = "ssh -p ${var.bastion_public_port} ubuntu@${cloudstack_ipaddress.mgmt.ip_address}"
}

output "nodes" {
  value = { for k, v in module.node : k => v.ip_address }
}

output "db_vip" {
  value = local.db_vip
}

output "ssh_config" {
  value = join("\n", concat(
    [
      "Host evl-bastion",
      "  HostName ${cloudstack_ipaddress.mgmt.ip_address}",
      "  Port ${var.bastion_public_port}",
      "  User ubuntu",
      "  ForwardAgent no",
      "",
    ],
    flatten([for k, v in module.node : k == "mon01" ? [] : [
      "Host evl-${k}",
      "  HostName ${v.ip_address}",
      "  User ubuntu",
      "  ProxyJump evl-bastion",
      "",
    ]])
  ))
}

output "token_investigator" {
  value     = random_password.token_investigator.result
  sensitive = true
}

output "token_auditor" {
  value     = random_password.token_auditor.result
  sensitive = true
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}

output "console_password" {
  value     = random_password.console.result
  sensitive = true
}
