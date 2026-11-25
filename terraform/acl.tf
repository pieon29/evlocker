locals {
  internet_egress = [
    { protocol = "udp", ports = ["53", "123"], cidrs = ["0.0.0.0/0"] },
    { protocol = "tcp", ports = ["53", "80", "443"], cidrs = ["0.0.0.0/0"] },
  ]

  icmp_rule = { cidrs = [var.vpc_cidr] }

  web_ingress = [
    { protocol = "tcp", ports = ["80", "443"], cidrs = ["0.0.0.0/0"] },
    { protocol = "tcp", ports = ["22", "9100", "9113"], cidrs = [var.mgmt_cidr] },
  ]

  web_egress = concat(local.internet_egress, [
    { protocol = "tcp", ports = ["5432"], cidrs = [var.data_cidr] },
    { protocol = "tcp", ports = ["514"], cidrs = [var.mgmt_cidr] },
  ])

  data_ingress = [
    { protocol = "tcp", ports = ["5432"], cidrs = [var.web_cidr, var.mgmt_cidr] },
    { protocol = "tcp", ports = ["22", "9100", "9187"], cidrs = [var.mgmt_cidr] },
  ]

  data_egress = concat(local.internet_egress, [
    { protocol = "tcp", ports = ["514"], cidrs = [var.mgmt_cidr] },
  ])

  mgmt_ingress = [
    { protocol = "tcp", ports = ["22"], cidrs = var.admin_cidrs },
    { protocol = "tcp", ports = ["514"], cidrs = [var.web_cidr, var.data_cidr] },
  ]

  mgmt_egress = concat(local.internet_egress, [
    { protocol = "tcp", ports = ["22", "443", "9100", "9113"], cidrs = [var.web_cidr] },
    { protocol = "tcp", ports = ["22", "5432", "9100", "9187"], cidrs = [var.data_cidr] },
  ])
}

resource "cloudstack_network_acl_rule" "web" {
  acl_id = cloudstack_network_acl.web.id

  dynamic "rule" {
    for_each = local.web_ingress
    content {
      action       = "allow"
      protocol     = rule.value.protocol
      ports        = rule.value.ports
      cidr_list    = rule.value.cidrs
      traffic_type = "ingress"
    }
  }

  dynamic "rule" {
    for_each = local.web_egress
    content {
      action       = "allow"
      protocol     = rule.value.protocol
      ports        = rule.value.ports
      cidr_list    = rule.value.cidrs
      traffic_type = "egress"
    }
  }

  rule {
    action       = "allow"
    protocol     = "icmp"
    icmp_type    = -1
    icmp_code    = -1
    cidr_list    = local.icmp_rule.cidrs
    traffic_type = "ingress"
  }

  rule {
    action       = "allow"
    protocol     = "icmp"
    icmp_type    = -1
    icmp_code    = -1
    cidr_list    = local.icmp_rule.cidrs
    traffic_type = "egress"
  }
}

resource "cloudstack_network_acl_rule" "data" {
  acl_id = cloudstack_network_acl.data.id

  dynamic "rule" {
    for_each = local.data_ingress
    content {
      action       = "allow"
      protocol     = rule.value.protocol
      ports        = rule.value.ports
      cidr_list    = rule.value.cidrs
      traffic_type = "ingress"
    }
  }

  dynamic "rule" {
    for_each = local.data_egress
    content {
      action       = "allow"
      protocol     = rule.value.protocol
      ports        = rule.value.ports
      cidr_list    = rule.value.cidrs
      traffic_type = "egress"
    }
  }

  rule {
    action       = "allow"
    protocol     = "icmp"
    icmp_type    = -1
    icmp_code    = -1
    cidr_list    = local.icmp_rule.cidrs
    traffic_type = "ingress"
  }

  rule {
    action       = "allow"
    protocol     = "icmp"
    icmp_type    = -1
    icmp_code    = -1
    cidr_list    = local.icmp_rule.cidrs
    traffic_type = "egress"
  }
}

resource "cloudstack_network_acl_rule" "mgmt" {
  acl_id = cloudstack_network_acl.mgmt.id

  dynamic "rule" {
    for_each = local.mgmt_ingress
    content {
      action       = "allow"
      protocol     = rule.value.protocol
      ports        = rule.value.ports
      cidr_list    = rule.value.cidrs
      traffic_type = "ingress"
    }
  }

  dynamic "rule" {
    for_each = local.mgmt_egress
    content {
      action       = "allow"
      protocol     = rule.value.protocol
      ports        = rule.value.ports
      cidr_list    = rule.value.cidrs
      traffic_type = "egress"
    }
  }

  rule {
    action       = "allow"
    protocol     = "icmp"
    icmp_type    = -1
    icmp_code    = -1
    cidr_list    = local.icmp_rule.cidrs
    traffic_type = "ingress"
  }

  rule {
    action       = "allow"
    protocol     = "icmp"
    icmp_type    = -1
    icmp_code    = -1
    cidr_list    = local.icmp_rule.cidrs
    traffic_type = "egress"
  }
}
