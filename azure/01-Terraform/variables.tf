variable "location" {
  type    = string
  default = "eastus"
}
variable "authorized_ips" {
  type    = set(string)
  default = []
}

