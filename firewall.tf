# Anclas de posicion. El provider ubica una regla con place_before <id>, asi que hay
# que resolver el id de la regla de referencia a partir de su comentario.
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

# Una address list por usuario con sus destinos habilitados. RouterOS resuelve los
# FQDN dinamicamente (requiere /ip dns configurado).
resource "routeros_ip_firewall_addr_list" "user_endpoint" {
  for_each = local.user_endpoints

  list    = "${var.address_list_prefix}${each.value.user}"
  address = each.value.endpoint
  comment = var.comment
}

# Default-deny del tunel. Va scopeado a la subnet: nunca un drop sin acotar, aunque
# al chain solo se llegue por el jump.
resource "routeros_ip_firewall_filter" "drop" {
  chain       = var.firewall_chain
  action      = "drop"
  src_address = var.tunnel_subnet
  log         = var.log_dropped
  log_prefix  = var.log_dropped ? var.drop_log_prefix : null
  comment     = "${var.comment} - default deny"
}

# Un accept por usuario, siempre antes del drop. Las reglas son disjuntas entre si
# (matchean por src), asi que su orden relativo no importa.
resource "routeros_ip_firewall_filter" "user" {
  for_each = var.users

  chain  = var.firewall_chain
  action = "accept"
  # Sin /32: RouterOS normaliza una mascara de host a la IP pelada y el plan
  # mostraria un cambio en cada corrida.
  src_address      = each.value.ip
  dst_address_list = "${var.address_list_prefix}${each.key}"
  comment          = "${var.comment} - ${each.key}"
  place_before     = routeros_ip_firewall_filter.drop.id
}

# Doble condicion (interfaz + subnet) para que nada ajeno al tunel entre al chain.
# Solo las conexiones nuevas pagan la evaluacion, porque el accept de
# established/related del forward chain las corta antes.
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
