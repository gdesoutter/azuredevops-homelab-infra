variable "hyperv_host" {
  type = string
}

variable "hyperv_user" {
  type      = string
  sensitive = true
}

variable "hyperv_password" {
  type      = string
  sensitive = true
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}

#Variables Azure
variable "subscription_id" {}
variable "tenant_id" {}
variable "client_id" {}

variable "client_secret" {
  sensitive = true
}

variable "resource_group" {}

variable "location" {
  default = "westeurope"
}

#Server catalog
variable "vm_catalog" {
  description = "Configuration de chaque VM à déployer"
  type = map(object({
    ram_mb      = number
    vcpu        = number
    switch_name = string
  }))

  default = {
    "ARC-SRV-01" = {
      ram_mb      = 4096
      vcpu        = 2
      switch_name = "Lab-External"
    }
    "DC-02" = {
      ram_mb      = 2048
      vcpu        = 2
      switch_name = "Lab-External"
    }
  }
}