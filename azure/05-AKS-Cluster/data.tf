data "azurerm_client_config" "tenant" {}

# data "azurerm_resource_group" "rg" {
#   name = var.rgLzName
# }

data "azurerm_virtual_network" "vnet-lz" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = var.vnetLzName
  resource_group_name = var.rgLzName
}

data "azurerm_subnet" "snet-aks" {
  count                = var.deployingAllInOne == true ? 0 : 1
  name                 = "snet-aks"
  virtual_network_name = var.vnetLzName
  resource_group_name  = var.rgLzName
}

data "azurerm_private_dns_zone" "dnszone-aks" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = "privatelink.${var.location}.${local.domain_name.aks}"
  resource_group_name = var.rgLzName
}

data "azurerm_private_dns_zone" "dnszone-contoso" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = local.domain_name.contoso
  resource_group_name = var.rgLzName
}

data "azurerm_container_registry" "acr" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = var.acrName
  resource_group_name = var.rgLzName
}

data "azurerm_key_vault" "akv" {
  count               = var.deployingAllInOne == true ? 0 : 1
  name                = var.akvName
  resource_group_name = var.rgLzName
}


data "azurerm_monitor_workspace" "amw" {
  name                = "amw-aks"
  resource_group_name = var.rgLzName
}

data "azurerm_dashboard_grafana" "grafana" {
  name                = "grafana-aks"
  resource_group_name = var.rgLzName
}
