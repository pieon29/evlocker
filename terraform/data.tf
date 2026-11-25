data "cloudstack_zone" "this" {
  filter {
    name  = "name"
    value = "^${var.zone_name}$"
  }
}

data "cloudstack_template" "ubuntu" {
  template_filter = "featured"

  filter {
    name  = "name"
    value = var.template_regex
  }
}

data "cloudstack_service_offering" "node" {
  filter {
    name  = "name"
    value = "^${var.service_offering}$"
  }
}
