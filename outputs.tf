output "server_public_key" {
  description = "Public key of the router's WireGuard interface."
  value       = routeros_interface_wireguard.this.public_key
}

output "interface_name" {
  description = "Name of the interface created on the router."
  value       = routeros_interface_wireguard.this.name
}

output "listen_port" {
  description = "UDP port the interface listens on. This is the port to open on the network firewall."
  value       = routeros_interface_wireguard.this.listen_port
}

output "router_address" {
  description = "Router's IP inside the tunnel."
  value       = local.router_address
}

output "client_configs" {
  description = "WireGuard configuration per user, ready to hand out."
  value       = local.client_configs
  sensitive   = true
}

output "peer_public_keys" {
  description = "Public key of each user, useful to identify a peer on the router."
  value       = { for user, key in wireguard_asymmetric_key.user : user => key.public_key }
}
