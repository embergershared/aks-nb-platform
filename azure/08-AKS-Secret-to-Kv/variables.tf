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

variable "k8s_cert_mgr_ns_name" {}
variable "k8s_rootcacert_secret_name" {}
variable "pkcs12_password" {
  type      = string
  sensitive = true
}
variable "storage_account_container_name" {}
