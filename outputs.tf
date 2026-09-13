output "server_public_key" {
  description = "Clave publica de la interfaz WireGuard del router."
  value       = routeros_interface_wireguard.this.public_key
}

output "interface_name" {
  description = "Nombre de la interfaz creada en el router."
  value       = routeros_interface_wireguard.this.name
}

output "listen_port" {
  description = "Puerto UDP en el que escucha la interfaz. Es el que hay que abrir en el firewall de red."
  value       = routeros_interface_wireguard.this.listen_port
}

output "router_address" {
  description = "IP del router dentro del tunel."
  value       = local.router_address
}

output "client_configs" {
  description = "Config de WireGuard por usuario, lista para entregar."
  value       = local.client_configs
  sensitive   = true
}

output "peer_public_keys" {
  description = "Clave publica de cada usuario, por si hace falta identificar un peer en el router."
  value       = { for user, key in wireguard_asymmetric_key.user : user => key.public_key }
}
