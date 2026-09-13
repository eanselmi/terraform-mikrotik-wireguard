terraform {
  required_version = ">= 1.3.0"

  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = ">= 1.60"
    }
    wireguard = {
      source  = "OJFord/wireguard"
      version = ">= 0.4"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.2"
    }
  }
}
