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


variable "vm_name" {
  type    = string
  default = "ARC-SRV-01"
}
variable "vm_admin_password" {
  type      = string
  sensitive = true
}

variable "subscription_id" {}
variable "tenant_id" {}
variable "client_id" {}
variable "client_secret" { sensitive = true }
variable "resource_group" {}
variable "location" { default = "westeurope" }