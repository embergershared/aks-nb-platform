variable "rgHubName" {
  type = string
}

variable "rgLzName" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "gl_runner_admin_username" {
  type    = string
  default = "azureuser"
}

variable "os_type" {
  type    = string
  default = "Windows"
}

variable "sku_size" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "source_image_reference" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }
}

variable "gitlab_runner_token" {
  type      = string
  sensitive = true
}

variable "storage_account_container_name" {
  type = string
}

variable "msft_entra_id_group_name" {}
variable "hww_entra_id_group_name" {}
variable "private_dns_zone_name" {}
