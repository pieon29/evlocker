locals {
  ssh_private_key = sensitive(fileexists(pathexpand(var.ssh_private_key_path)) ? file(pathexpand(var.ssh_private_key_path)) : "")

  node_env_content = {
    for k, v in local.nodes : k => join("\n", concat(
      [for ek, ev in merge(v.env, { NODE_NAME = k, NODE_IP = v.ip }) : "${ek}='${ev}'"],
      [""],
    ))
  }

  node_files_script = {
    for k, v in local.nodes : k => join("\n", concat(
      ["set -eu"],
      flatten([for f in v.files : [
        "install -d -m 0755 \"$(dirname ${f.path})\"",
        "printf '%s' '${base64encode(f.content)}' | base64 -d > ${f.path}",
        "chmod ${f.mode} ${f.path}",
      ]]),
      [""],
    ))
  }
}

resource "terraform_data" "bootstrap" {
  for_each = local.nodes

  triggers_replace = {
    instance = module.node[each.key].id
    repo_ref = var.repo_ref
    env      = sha256(local.node_env_content[each.key])
    files    = sha256(local.node_files_script[each.key])
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    host                = each.key == "mon01" ? cloudstack_ipaddress.mgmt.ip_address : each.value.ip
    port                = each.key == "mon01" ? var.bastion_public_port : 22
    private_key         = local.ssh_private_key
    bastion_host        = each.key == "mon01" ? null : cloudstack_ipaddress.mgmt.ip_address
    bastion_port        = var.bastion_public_port
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
      "echo \"[evl] $(hostname) $(ip -o link show | grep -o 'mtu [0-9]*' | sed -n 2p)\"",
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

  depends_on = [
    cloudstack_port_forward.bastion,
    cloudstack_loadbalancer_rule.web,
    cloudstack_port_forward.web_fallback,
  ]
}
