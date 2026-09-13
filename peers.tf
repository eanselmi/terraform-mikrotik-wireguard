resource "wireguard_asymmetric_key" "user" {
  for_each = var.users
}

resource "routeros_interface_wireguard_peer" "user" {
  for_each = var.users

  interface  = routeros_interface_wireguard.this.name
  name       = each.key
  public_key = wireguard_asymmetric_key.user[each.key].public_key
  comment    = var.comment

  # The client's private key is stored on the router so RouterOS can render the
  # peer's Client Config / QR code.
  private_key = wireguard_asymmetric_key.user[each.key].private_key

  # Router-side routing: which source addresses are accepted from this peer and
  # which destination is routed to it. This is the user's tunnel IP, NOT their endpoint.
  allowed_address = ["${each.value.ip}/32"]

  # Fields RouterOS uses to render the client configuration. client_allowed_address
  # is not supported by the provider, so the router's Client Config has no AllowedIPs:
  # the complete configuration comes from the client_configs output.
  client_address   = "${each.value.ip}/32"
  client_dns       = coalesce(each.value.dns, var.default_client_dns)
  client_endpoint  = var.client_endpoint
  client_keepalive = "${var.client_keepalive}s"
}
