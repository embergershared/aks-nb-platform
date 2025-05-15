data "azurerm_virtual_network" "vnethub" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = var.vnetHubName
  resource_group_name = var.rgHubName
}

data "azurerm_firewall" "firewall" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = "azureFirewall"
  resource_group_name = var.rgHubName
}
