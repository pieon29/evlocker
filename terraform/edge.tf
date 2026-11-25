resource "cloudstack_ipaddress" "web" {
  vpc_id = cloudstack_vpc.main.id
  zone   = data.cloudstack_zone.this.name
}

resource "cloudstack_ipaddress" "mgmt" {
  vpc_id = cloudstack_vpc.main.id
  zone   = data.cloudstack_zone.this.name
}

locals {
  web_member_ids = [for k in keys(local.web_nodes) : module.node[k].id]
  edge_ports     = [443, 80]
}

resource "cloudstack_loadbalancer_rule" "web" {
  for_each = var.use_vr_lb ? toset([for p in local.edge_ports : tostring(p)]) : toset([])

  name          = "lb-${each.value}-${var.name_prefix}"
  ip_address_id = cloudstack_ipaddress.web.id
  network_id    = cloudstack_network.web.id
  algorithm     = "roundrobin"
  private_port  = tonumber(each.value)
  public_port   = tonumber(each.value)
  member_ids    = local.web_member_ids
}

resource "cloudstack_port_forward" "web_fallback" {
  count         = var.use_vr_lb ? 0 : 1
  ip_address_id = cloudstack_ipaddress.web.id

  dynamic "forward" {
    for_each = local.edge_ports
    content {
      protocol           = "tcp"
      private_port       = forward.value
      public_port        = forward.value
      virtual_machine_id = module.node["web01"].id
    }
  }
}

resource "cloudstack_port_forward" "bastion" {
  ip_address_id = cloudstack_ipaddress.mgmt.id

  forward {
    protocol           = "tcp"
    private_port       = 22
    public_port        = var.bastion_public_port
    virtual_machine_id = module.node["mon01"].id
  }
}
