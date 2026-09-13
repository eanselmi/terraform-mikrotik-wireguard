variable "users" {
  description = <<-EOT
    Usuarios del tunel. La clave del mapa es el nombre del peer. Por usuario:
      ip        = IP de tunel, unica, dentro de tunnel_subnet.
      endpoints = destinos habilitados para ese usuario (IP, CIDR o FQDN).
                  RouterOS resuelve los FQDN dinamicamente y requiere /ip dns configurado.
      dns       = DNS que lleva la config del cliente. Si se omite, usa default_client_dns.
  EOT

  type = map(object({
    ip        = string
    endpoints = list(string)
    dns       = optional(string)
  }))

  validation {
    condition     = alltrue([for u in var.users : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", u.ip))])
    error_message = "Cada users[*].ip debe ser una IPv4 sin mascara (ej: 172.19.1.10)."
  }

  validation {
    condition     = length(distinct([for u in var.users : u.ip])) == length(var.users)
    error_message = "Hay IPs de tunel repetidas entre usuarios."
  }
}

variable "tunnel_subnet" {
  description = "Subnet del tunel en CIDR (ej: 172.19.1.0/24). Acota el jump, el drop y el masquerade."
  type        = string

  validation {
    condition     = can(cidrhost(var.tunnel_subnet, 0))
    error_message = "tunnel_subnet debe ser un CIDR valido."
  }
}

variable "interface_name" {
  description = "Nombre de la interfaz WireGuard en el router. Cambiarlo la recrea."
  type        = string
  default     = "wg0"
}

variable "listen_port" {
  description = "Puerto UDP en el que escucha la interfaz. Fijarlo evita que RouterOS asigne uno aleatorio al recrearla."
  type        = number
  default     = 51820
}

variable "router_address" {
  description = "IP del router dentro del tunel, sin mascara. Por defecto, la primera util de tunnel_subnet."
  type        = string
  default     = null
}

variable "server_mtu" {
  description = "MTU de la interfaz. null deja el valor por defecto de RouterOS."
  type        = number
  default     = null
}

################## Firewall ##################

variable "firewall_chain" {
  description = "Chain propio donde viven las reglas por usuario."
  type        = string
  default     = "wireguard"
}

variable "address_list_prefix" {
  description = "Prefijo de las address lists por usuario. La lista queda <prefijo><usuario>."
  type        = string
  default     = "wg-"
}

variable "input_place_before_comment" {
  description = <<-EOT
    Comentario de la regla del chain input antes de la cual se inserta el accept del puerto
    WireGuard (tipicamente el drop por defecto). Si es null, la regla se agrega al final del
    chain: verificar que ahi siga siendo efectiva.
  EOT
  type        = string
  default     = null
}

variable "srcnat_place_before_comment" {
  description = "Comentario de la regla de srcnat antes de la cual se inserta el masquerade. null lo agrega al final."
  type        = string
  default     = null
}

variable "create_nat_masquerade" {
  description = "Crear el masquerade de srcnat para la subnet del tunel. Desactivar si el trafico se rutea sin NAT."
  type        = bool
  default     = true
}

variable "log_dropped" {
  description = "Loguear el trafico que cae en el drop por defecto del chain."
  type        = bool
  default     = true
}

variable "drop_log_prefix" {
  description = "Prefijo de log del drop por defecto."
  type        = string
  default     = "DROP-WG"
}

variable "comment" {
  description = "Comentario que se le pone a todos los objetos creados en el router."
  type        = string
  default     = "Managed by Terraform"
}

################## Configs de cliente ##################

variable "client_allowed_ips" {
  description = <<-EOT
    Redes que los clientes rutean por el tunel (AllowedIPs). Es igual para todos: la
    autorizacion real por usuario la aplica el firewall del router, no el cliente.
  EOT
  type        = list(string)
}

variable "client_endpoint" {
  description = "Endpoint al que se conectan los clientes, host:puerto (ej: vpn.example.com:51820)."
  type        = string
}

variable "client_keepalive" {
  description = "PersistentKeepalive en segundos de las configs de cliente."
  type        = number
  default     = 25
}

variable "default_client_dns" {
  description = "DNS de las configs de cliente que no definen uno propio."
  type        = string
  default     = "1.1.1.1"
}

variable "client_config_path" {
  description = <<-EOT
    Directorio donde escribir un <usuario>.conf por usuario, con permisos 0600. Al sacar un
    usuario del mapa, el apply borra su archivo. null desactiva la escritura en disco.
    Usar una ruta relativa a path.root, no a este modulo.
    ATENCION: los archivos contienen claves privadas. Mantenerlos fuera del control de versiones.
  EOT
  type        = string
  default     = null
}
