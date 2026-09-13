# terraform-mikrotik-wireguard

Módulo de Terraform para gestionar un servidor WireGuard en RouterOS 7, con **autorización por
usuario** aplicada en el firewall del router.

Cada usuario declara la lista de destinos a los que puede llegar. El módulo crea una address list
por usuario y una regla `accept` en un chain propio, cerrado con un `drop` por defecto: lo que no
está habilitado explícitamente, no pasa.

## Cómo funciona

Todos los clientes reciben el mismo `AllowedIPs`, porque el `AllowedIPs` del cliente es solo
ruteo y el usuario puede editarlo. El control de acceso real vive en el router:

```
forward ──jump (in-interface=wgX, src=tunnel_subnet)──> chain "wireguard"
                                                          ├── accept  src=IP_user1  dst-address-list=wg-user1
                                                          ├── accept  src=IP_user2  dst-address-list=wg-user2
                                                          └── drop    src=tunnel_subnet   (log)
```

El módulo también crea la interfaz, su dirección IP, un peer por usuario con sus claves, el
`accept` del puerto UDP en el chain `input` y, opcionalmente, el `masquerade` de srcnat.

## Uso

```hcl
provider "routeros" {
  hosturl  = "apis://10.0.0.1:8729"
  username = var.router_user
  password = var.router_password
  insecure = true
}

module "wireguard" {
  source = "git::https://github.com/eanselmi/terraform-mikrotik-wireguard.git?ref=v1.0.0"

  interface_name = "wg0"
  listen_port    = 51820
  tunnel_subnet  = "172.19.1.0/24"

  client_endpoint    = "vpn.example.com:51820"
  client_allowed_ips = ["10.0.0.0/16"]
  client_config_path = "${path.root}/config_files"

  # Sin esto la regla del puerto UDP queda al final del chain input,
  # es decir, después del drop por defecto.
  input_place_before_comment  = "Default Drop"
  srcnat_place_before_comment = "NAT generico"

  users = {
    jperez = {
      ip        = "172.19.1.10"
      endpoints = ["10.0.5.0/24", "api.interna.example.com"]
    }
    mgomez = {
      ip        = "172.19.1.11"
      endpoints = ["10.0.5.10"]
      dns       = "10.0.0.53"
    }
  }
}
```

Alta de usuario: se agrega la entrada al mapa y se aplica. Baja: se saca y se aplica — el apply
elimina el peer, su address list, su regla de firewall y su archivo `.conf`.

## Requisitos en el router

1. **RouterOS 7.x.** El provider solo soporta v7.
2. **Un transporte habilitado para Terraform**: `api-ssl` (8729) o la REST API (`www-ssl`), con
   un certificado. En ROS 7.24 el autofirmado directo falla con `CA not found`: hay que crear una
   CA y firmar con ella.

   ```routeros
   /certificate add name=ca-tpl common-name=MI-CA key-usage=key-cert-sign,crl-sign days-valid=3650
   /certificate sign ca-tpl name=mi-ca
   /certificate add name=api-tpl common-name=10.0.0.1 days-valid=3650 key-size=2048 \
       key-usage=digital-signature,key-encipherment,tls-server
   /certificate sign api-tpl ca=mi-ca name=api-cert
   /ip service set api-ssl certificate=api-cert address=10.0.0.0/24 disabled=no
   ```

3. **Un usuario dedicado** con policies `api`, `read`, `write` y **`sensitive`**. Sin `sensitive`
   el usuario no puede leer claves privadas y cada plan muestra un cambio fantasma en
   `private_key`.
4. **`/ip dns` configurado**, si se usan FQDN en `endpoints`.
5. **El puerto UDP abierto** en el firewall de red que esté delante del router.

## Inputs

| Nombre | Descripción | Tipo | Default |
|---|---|---|---|
| `users` | Mapa de usuarios: `ip`, `endpoints` y `dns` opcional | `map(object)` | requerido |
| `tunnel_subnet` | Subnet del túnel en CIDR | `string` | requerido |
| `client_allowed_ips` | Redes que los clientes rutean por el túnel | `list(string)` | requerido |
| `client_endpoint` | Endpoint de los clientes, `host:puerto` | `string` | requerido |
| `interface_name` | Nombre de la interfaz | `string` | `"wg0"` |
| `listen_port` | Puerto UDP de escucha | `number` | `51820` |
| `router_address` | IP del router en el túnel | `string` | primera útil de `tunnel_subnet` |
| `server_mtu` | MTU de la interfaz | `number` | `null` |
| `firewall_chain` | Chain de las reglas por usuario | `string` | `"wireguard"` |
| `address_list_prefix` | Prefijo de las address lists | `string` | `"wg-"` |
| `input_place_before_comment` | Comentario de la regla de `input` antes de la cual insertar el accept | `string` | `null` |
| `srcnat_place_before_comment` | Comentario de la regla de `srcnat` antes de la cual insertar el masquerade | `string` | `null` |
| `create_nat_masquerade` | Crear el masquerade de srcnat | `bool` | `true` |
| `log_dropped` | Loguear lo que cae en el drop | `bool` | `true` |
| `drop_log_prefix` | Prefijo de log del drop | `string` | `"DROP-WG"` |
| `comment` | Comentario de todos los objetos creados | `string` | `"Managed by Terraform"` |
| `client_keepalive` | `PersistentKeepalive` en segundos | `number` | `25` |
| `default_client_dns` | DNS para los usuarios que no definen uno | `string` | `"1.1.1.1"` |
| `client_config_path` | Directorio donde escribir los `.conf`. `null` no escribe nada | `string` | `null` |

## Outputs

| Nombre | Descripción |
|---|---|
| `client_configs` | Config de cada usuario, lista para entregar (sensitive) |
| `server_public_key` | Clave pública de la interfaz |
| `interface_name` | Nombre de la interfaz creada |
| `listen_port` | Puerto UDP de escucha |
| `router_address` | IP del router en el túnel |
| `peer_public_keys` | Clave pública de cada usuario |

## Advertencias

**Las claves privadas quedan en el state.** El módulo genera los pares de claves, así que el
state debe tratarse como material sensible: backend remoto, cifrado y acceso restringido. Lo
mismo aplica a `client_config_path`: son archivos con la clave privada del usuario, hay que
mantenerlos fuera del control de versiones.

**`client_allowed_address` no se puede setear.** El campo existe en ROS 7.21+ pero el provider no
lo expone ([issue #966](https://github.com/terraform-routeros/terraform-provider-routeros/issues/966)),
así que el "Client Config" que genera el router queda sin `AllowedIPs`. La config completa es la
de `client_configs` / los archivos `.conf`, no el QR del router.

**El `place_before` se resuelve por comentario.** Si se renombra o se borra en el router la regla
que sirve de ancla, el plan falla al no encontrarla. Es deliberado: es preferible un error a
insertar una regla en una posición donde no hace efecto.

**Los `/32` se normalizan.** RouterOS guarda una máscara de host como IP pelada, por eso
`src_address` de las reglas por usuario va sin máscara. En `allowed_address` del peer sí se
conserva.

**`routeros_ip_address` no se puede modificar in place.** El provider incluye `vrf` en el payload
de update y `/ip/address` de ROS 7.24 lo rechaza con `unknown parameter vrf`. El módulo ignora
los cambios de `comment` en ese recurso para que un cambio de `var.comment` no deje el stack sin
converger: el comentario se fija al crearlo. Si hace falta cambiarlo de verdad, hay que recrear
el recurso, lo que deja la interfaz sin IP unos instantes:

```bash
terraform apply -replace='module.wireguard.routeros_ip_address.this'
```

## Licencia

MIT
