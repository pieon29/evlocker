resource "cloudstack_vpc" "main" {
  name         = "evl-vpc-${var.name_prefix}"
  display_text = "evlocker vpc ${var.name_prefix}"
  cidr         = var.vpc_cidr
  vpc_offering = var.vpc_offering
  zone         = data.cloudstack_zone.this.name
}

resource "cloudstack_network_acl" "web" {
  name        = "acl-web-${var.name_prefix}"
  description = "web tier"
  vpc_id      = cloudstack_vpc.main.id
}

resource "cloudstack_network_acl" "data" {
  name        = "acl-data-${var.name_prefix}"
  description = "data tier"
  vpc_id      = cloudstack_vpc.main.id
}

resource "cloudstack_network_acl" "mgmt" {
  name        = "acl-mgmt-${var.name_prefix}"
  description = "management tier"
  vpc_id      = cloudstack_vpc.main.id
}

resource "cloudstack_network" "web" {
  name             = "tier-web-${var.name_prefix}"
  display_text     = "web tier"
  cidr             = var.web_cidr
  gateway          = cidrhost(var.web_cidr, 1)
  network_offering = var.tier_network_offering
  vpc_id           = cloudstack_vpc.main.id
  acl_id           = cloudstack_network_acl.web.id
  zone             = data.cloudstack_zone.this.name
}

resource "cloudstack_network" "data" {
  name             = "tier-data-${var.name_prefix}"
  display_text     = "data tier"
  cidr             = var.data_cidr
  gateway          = cidrhost(var.data_cidr, 1)
  network_offering = var.tier_network_offering
  vpc_id           = cloudstack_vpc.main.id
  acl_id           = cloudstack_network_acl.data.id
  zone             = data.cloudstack_zone.this.name
}

resource "cloudstack_network" "mgmt" {
  name             = "tier-mgmt-${var.name_prefix}"
  display_text     = "management tier"
  cidr             = var.mgmt_cidr
  gateway          = cidrhost(var.mgmt_cidr, 1)
  network_offering = var.tier_network_offering
  vpc_id           = cloudstack_vpc.main.id
  acl_id           = cloudstack_network_acl.mgmt.id
  zone             = data.cloudstack_zone.this.name
}
