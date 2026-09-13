variable "users" {
  description = <<-EOT
    Users of the tunnel. The map key is the peer name. Per user:
      ip        = tunnel IP, unique, inside tunnel_subnet, written without a mask.
      endpoints = destinations this user is allowed to reach (IP, CIDR or FQDN).
                  RouterOS resolves FQDNs dynamically and requires /ip dns to be configured.
      dns       = DNS for this user's client configuration. Falls back to default_client_dns.
  EOT

  type = map(object({
    ip        = string
    endpoints = list(string)
    dns       = optional(string)
  }))

  validation {
    condition     = alltrue([for u in var.users : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", u.ip))])
    error_message = "Every users[*].ip must be an IPv4 address without a mask (e.g. 172.19.1.10)."
  }

  validation {
    condition     = length(distinct([for u in var.users : u.ip])) == length(var.users)
    error_message = "Two or more users share the same tunnel IP."
  }
}

variable "tunnel_subnet" {
  description = "Tunnel subnet in CIDR notation (e.g. 172.19.1.0/24). Scopes the jump, the default drop and the masquerade."
  type        = string

  validation {
    condition     = can(cidrhost(var.tunnel_subnet, 0))
    error_message = "tunnel_subnet must be a valid CIDR block."
  }
}

variable "interface_name" {
  description = "Name of the WireGuard interface on the router. Changing it recreates the interface."
  type        = string
  default     = "wg0"
}

variable "listen_port" {
  description = "UDP port the interface listens on. Pinning it prevents RouterOS from assigning a random port when the interface is recreated."
  type        = number
  default     = 51820
}

variable "router_address" {
  description = "Router's own IP inside the tunnel, without a mask. Defaults to the first host address of tunnel_subnet."
  type        = string
  default     = null
}

variable "server_mtu" {
  description = "MTU of the interface. null keeps the RouterOS default."
  type        = number
  default     = null
}

################## Firewall ##################

variable "firewall_chain" {
  description = "Dedicated chain holding the per-user rules."
  type        = string
  default     = "wireguard"
}

variable "address_list_prefix" {
  description = "Prefix for the per-user address lists. Each list is named <prefix><user>."
  type        = string
  default     = "wg-"
}

variable "input_place_before_comment" {
  description = <<-EOT
    Comment of the rule in the input chain to insert the WireGuard port accept before, typically
    the default drop. When null, the rule is appended at the end of the chain: make sure it is
    still effective there.
  EOT
  type        = string
  default     = null
}

variable "srcnat_place_before_comment" {
  description = "Comment of the srcnat rule to insert the masquerade before. When null, the rule is appended at the end."
  type        = string
  default     = null
}

variable "create_nat_masquerade" {
  description = "Create the srcnat masquerade for the tunnel subnet. Disable it when the tunnel traffic is routed instead of translated."
  type        = bool
  default     = true
}

variable "log_dropped" {
  description = "Log the traffic that hits the chain's default drop."
  type        = bool
  default     = true
}

variable "drop_log_prefix" {
  description = "Log prefix for the default drop."
  type        = string
  default     = "DROP-WG"
}

variable "comment" {
  description = "Comment applied to every object the module creates on the router."
  type        = string
  default     = "Managed by Terraform"
}

################## Client configuration ##################

variable "client_allowed_ips" {
  description = <<-EOT
    Networks the clients route through the tunnel (AllowedIPs). It is the same for every user:
    the actual per-user authorization is enforced by the router firewall, not by the client.
  EOT
  type        = list(string)
}

variable "client_endpoint" {
  description = "Endpoint the clients connect to, host:port (e.g. vpn.example.com:51820)."
  type        = string
}

variable "client_keepalive" {
  description = "PersistentKeepalive, in seconds, for the client configurations."
  type        = number
  default     = 25
}

variable "default_client_dns" {
  description = "DNS used in the configuration of users that do not define one of their own."
  type        = string
  default     = "1.1.1.1"
}

variable "client_config_path" {
  description = <<-EOT
    Directory to write one <user>.conf per user into, with 0600 permissions. Removing a user from
    the map deletes their file on the next apply. null disables writing to disk. Use a path
    relative to path.root, not to this module.
    WARNING: these files contain private keys. Keep them out of version control.
  EOT
  type        = string
  default     = null
}
