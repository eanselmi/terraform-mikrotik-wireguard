locals {
  client_configs = {
    for user, cfg in var.users : user => templatefile("${path.module}/templates/wg-client.conf.tmpl", {
      private_key       = wireguard_asymmetric_key.user[user].private_key
      address           = cfg.ip
      dns               = coalesce(cfg.dns, var.default_client_dns)
      server_public_key = routeros_interface_wireguard.this.public_key
      allowed_ips       = join(", ", var.client_allowed_ips)
      endpoint          = var.client_endpoint
      keepalive         = var.client_keepalive
    })
  }
}

# Un archivo por usuario. Al sacar un usuario de var.users, Terraform destruye el
# recurso y borra el archivo del disco.
# Contienen la clave privada del usuario: mantener el directorio fuera de git.
resource "local_sensitive_file" "client_config" {
  for_each = var.client_config_path == null ? {} : local.client_configs

  filename             = "${var.client_config_path}/${each.key}.conf"
  content              = each.value
  file_permission      = "0600"
  directory_permission = "0700"
}
