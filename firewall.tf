# Position anchors. The provider places a rule with place_before <id>, so the id of
# the reference rule has to be resolved from its comment.
data "routeros_firewall" "input_anchor" {
  count = var.input_place_before_comment == null ? 0 : 1

  rules {
    filter = {
      chain   = "input"
      comment = var.input_place_before_comment
    }
  }
}

data "routeros_firewall" "srcnat_anchor" {
  count = var.srcnat_place_before_comment == null ? 0 : 1

  nat {
    filter = {
      comment = var.srcnat_place_before_comment
    }
  }
}

# One address list per user, holding their allowed destinations. RouterOS resolves
# FQDNs dynamically (requires /ip dns to be configured).
resource "routeros_ip_firewall_addr_list" "user_endpoint" {
  for_each = local.user_endpoints

  list    = "${var.address_list_prefix}${each.value.user}"
  address = each.value.endpoint
  comment = var.comment
}

# Default deny for the tunnel. Scoped to the subnet: never an unscoped drop, even
# though the chain is only reachable through the jump.
resource "routeros_ip_firewall_filter" "drop" {
  chain       = var.firewall_chain
  action      = "drop"
  src_address = var.tunnel_subnet
  log         = var.log_dropped
  log_prefix  = var.log_dropped ? var.drop_log_prefix : null
  comment     = "${var.comment} - default deny"
}

# One accept per user, always before the drop. The rules are disjoint (they match on
# source), so their relative order does not matter.
resource "routeros_ip_firewall_filter" "user" {
  for_each = var.users

  chain  = var.firewall_chain
  action = "accept"
  # No /32: RouterOS normalizes a host mask to the bare IP, which would show up as a
  # change on every plan.
  src_address      = each.value.ip
  dst_address_list = "${var.address_list_prefix}${each.key}"
  comment          = "${var.comment} - ${each.key}"
  place_before     = routeros_ip_firewall_filter.drop.id
}

# Two conditions (interface and subnet) so nothing foreign to the tunnel enters the
# chain. Only new connections pay for the evaluation, because the established/related
# accept in the forward chain matches them first.
resource "routeros_ip_firewall_filter" "jump" {
  chain        = "forward"
  action       = "jump"
  jump_target  = var.firewall_chain
  in_interface = routeros_interface_wireguard.this.name
  src_address  = var.tunnel_subnet
  comment      = "${var.comment} - per-user ACLs"
}

resource "routeros_ip_firewall_filter" "input" {
  chain        = "input"
  action       = "accept"
  protocol     = "udp"
  dst_port     = tostring(var.listen_port)
  comment      = "${var.comment} - ${var.interface_name}"
  place_before = try(data.routeros_firewall.input_anchor[0].rules[0].id, null)
}

resource "routeros_ip_firewall_nat" "masquerade" {
  count = var.create_nat_masquerade ? 1 : 0

  chain        = "srcnat"
  action       = "masquerade"
  src_address  = var.tunnel_subnet
  comment      = "${var.comment} - ${var.interface_name}"
  place_before = try(data.routeros_firewall.srcnat_anchor[0].nat[0].id, null)
}
