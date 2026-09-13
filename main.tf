locals {
  router_address = coalesce(var.router_address, cidrhost(var.tunnel_subnet, 1))
  subnet_mask    = split("/", var.tunnel_subnet)[1]

  # user x endpoint pairs, flattened for the address lists
  user_endpoints = merge([
    for user, cfg in var.users : {
      for ep in cfg.endpoints : "${user}:${ep}" => { user = user, endpoint = ep }
    }
  ]...)
}

resource "wireguard_asymmetric_key" "server" {}

resource "routeros_interface_wireguard" "this" {
  name        = var.interface_name
  listen_port = var.listen_port
  private_key = wireguard_asymmetric_key.server.private_key
  mtu         = var.server_mtu
  comment     = var.comment
}

resource "routeros_ip_address" "this" {
  address   = "${local.router_address}/${local.subnet_mask}"
  interface = routeros_interface_wireguard.this.name
  comment   = var.comment

  lifecycle {
    # The provider includes 'vrf' in the update payload and /ip/address on ROS 7.24
    # rejects it ("unknown parameter vrf"), so this resource cannot be updated in
    # place. The comment is set on creation and ignored afterwards: without this,
    # changing var.comment would leave the stack unable to converge.
    # To really change it, recreate the resource with -replace, which leaves the
    # interface without an address for a moment.
    ignore_changes = [comment]
  }
}
