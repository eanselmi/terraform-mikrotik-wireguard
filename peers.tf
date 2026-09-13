resource "wireguard_asymmetric_key" "user" {
  for_each = var.users
}

resource "routeros_interface_wireguard_peer" "user" {
  for_each = var.users

  interface  = routeros_interface_wireguard.this.name
  name       = each.key
  public_key = wireguard_asymmetric_key.user[each.key].public_key
  comment    = var.comment

  # La private key del cliente vive en el router para que RouterOS pueda generar
  # el Client Config / QR del peer.
  private_key = wireguard_asymmetric_key.user[each.key].private_key

  # Ruteo del lado del router: de que IPs se acepta trafico de este peer y hacia
  # cual se enruta el suyo. Es la IP de tunel del usuario, NO su endpoint.
  allowed_address = ["${each.value.ip}/32"]

  # Campos con los que RouterOS arma la config del cliente. client_allowed_address
  # no esta soportado por el provider, asi que el Client Config del router queda sin
  # AllowedIPs: la config completa sale del output client_configs.
  client_address   = "${each.value.ip}/32"
  client_dns       = coalesce(each.value.dns, var.default_client_dns)
  client_endpoint  = var.client_endpoint
  client_keepalive = "${var.client_keepalive}s"
}
