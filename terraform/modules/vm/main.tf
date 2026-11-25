terraform {
  required_providers {
    cloudstack = {
      source = "cloudstack/cloudstack"
    }
  }
}

resource "cloudstack_instance" "this" {
  name             = var.name
  display_name     = var.name
  service_offering = var.offering_id
  template         = var.template_id
  zone             = var.zone
  network_id       = var.network_id
  ip_address       = var.ip_address
  root_disk_size   = var.root_disk_size
  user_data        = var.user_data
  expunge          = true
}
