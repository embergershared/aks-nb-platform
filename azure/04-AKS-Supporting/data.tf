data "azurerm_client_config" "tenant" {}

# data "azurerm_resource_group" "rg" {
#   count = var.deployingAllInOne == true ? 0 : 1
#   name  = var.rgLzName
# }

# data "azurerm_virtual_network" "vnet-lz" {
#   count               = var.deployingAllInOne == true ? 0 : 1
#   name                = var.vnetLzName
#   resource_group_name = var.rgLzName
# }

data "azurerm_subnet" "snet-spe" {
  count                = var.deployingAllInOne == true ? 0 : 1
  name                 = "snet-spe"
  virtual_network_name = var.vnetLzName
  resource_group_name  = var.rgLzName
}

data "azurerm_private_dns_zone" "dnszone-acr" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = local.domain_name.acr
  resource_group_name = var.rgLzName
}

data "azurerm_private_dns_zone" "dnszone-akv" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = local.domain_name.akv
  resource_group_name = var.rgLzName
}
