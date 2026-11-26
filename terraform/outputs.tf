output "service_url" {
  value = "https://${local.mon_ip}/"
}

output "bastion" {
  value = "ssh ubuntu@${local.mon_ip}"
}

output "nodes" {
  value = local.ip
}

output "ssh_config" {
  value = join("\n", concat(
    [
      "Host evl-bastion",
      "  HostName ${local.mon_ip}",
      "  User ubuntu",
      "",
    ],
    flatten([for k, v in local.ip : k == "mon01" ? [] : [
      "Host evl-${k}",
      "  HostName ${v}",
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
