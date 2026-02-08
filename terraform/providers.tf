terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "1.2.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {}
}

provider "hyperv" {
  user     = var.hyperv_user
  password = var.hyperv_password
  host     = var.hyperv_host
  port     = 5986
  https    = true
  insecure = true
}

provider "azurerm" {
  features {}
}