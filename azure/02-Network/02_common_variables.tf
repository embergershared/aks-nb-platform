# 03a_common_variables.tf

variable "tenant_id" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}

variable "base_tags" {
  type    = map(string)
  default = null
}
variable "plan_tags" {
  type    = map(string)
  default = null
}
