package main

import rego.v1

managed := [rc |
	some rc in input.resource_changes
	rc.mode == "managed"
	not "delete" in rc.change.actions
]

acl_rules contains r if {
	some rc in managed
	rc.type == "cloudstack_network_acl_rule"
	some r in rc.change.after.rule
}

deny contains msg if {
	some r in acl_rules
	r.traffic_type == "ingress"
	"0.0.0.0/0" in r.cidr_list
	"22" in r.ports
	msg := "EVL-001: SSH(22) must not be open to 0.0.0.0/0 in a network ACL"
}

deny contains msg if {
	some r in acl_rules
	r.traffic_type == "ingress"
	r.protocol == "all"
	"0.0.0.0/0" in r.cidr_list
	msg := "EVL-002: ingress rule allowing all protocols from 0.0.0.0/0 is forbidden"
}

deny contains msg if {
	some r in acl_rules
	r.traffic_type == "ingress"
	"0.0.0.0/0" in r.cidr_list
	some p in r.ports
	p in {"5432", "9100", "9187", "514"}
	msg := sprintf("EVL-003: internal port %s must not be reachable from 0.0.0.0/0", [p])
}

deny contains msg if {
	some rc in managed
	rc.type == "cloudstack_port_forward"
	some f in rc.change.after.forward
	f.private_port in {5432, 9100, 9187}
	msg := sprintf("EVL-004: port forwarding to internal port %d is forbidden", [f.private_port])
}

deny contains msg if {
	some rc in managed
	rc.type == "cloudstack_instance"
	rc.change.after.expunge != true
	msg := sprintf("EVL-005: %s must set expunge = true so quota is released on destroy", [rc.address])
}

deny contains msg if {
	some rc in managed
	rc.type == "cloudstack_instance"
	rc.change.after.root_disk_size > 20
	msg := sprintf("EVL-006: %s root disk %dGB exceeds the 20GB per-VM budget", [rc.address, rc.change.after.root_disk_size])
}

deny contains msg if {
	count([rc | some rc in managed; rc.type == "cloudstack_instance"]) > 6
	msg := "EVL-007: more than 6 instances exceed the 120GB primary storage quota"
}
