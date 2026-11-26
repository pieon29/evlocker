locals {
  ssh_key_file   = pathexpand(var.ssh_public_key_path)
  ssh_public_key = fileexists(local.ssh_key_file) ? trimspace(file(local.ssh_key_file)) : ""

  web_names = [for i in range(var.web_count) : format("web%02d", i + 1)]

  roles = merge(
    { for n in local.web_names : n => "web" },
    { db01 = "db", db02 = "db", mon01 = "mon" },
  )
}

module "node" {
  source   = "./modules/vm"
  for_each = local.roles

  name           = "${each.key}-${var.name_prefix}"
  offering_id    = data.cloudstack_service_offering.node.id
  template_id    = data.cloudstack_template.ubuntu.id
  zone           = data.cloudstack_zone.this.name
  network_id     = var.shared_network_id
  root_disk_size = var.root_disk_size

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname         = each.key
    mtu              = var.vm_mtu
    ssh_public_key   = local.ssh_public_key
    console_password = random_password.console.result
  })

  depends_on = [terraform_data.ssh_key_check]
}

resource "terraform_data" "ssh_key_check" {
  input = local.ssh_public_key

  lifecycle {
    precondition {
      condition     = can(regex("^ssh-(ed25519|rsa) ", local.ssh_public_key))
      error_message = "SSH public key not found at ssh_public_key_path. Run ssh-keygen -t ed25519 first."
    }
  }
}
