# Gather all resources from the Landing Zone Resource Group, to extract the ones needed through filters in locals.tf
data "azurerm_resources" "lz_rg_resource_s" {
  resource_group_name = var.rgLzName
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name #split("/", local.aksId)[8]
  resource_group_name = var.rgLzName   #split("/", local.aksId)[4]
}

/*
# Data providers for required resources
data "azurerm_virtual_network" "vnet-lz" {
  name                = local.lz_vnet_name
  resource_group_name = var.rgLzName
}
data "azurerm_subnet" "snet-vm" {
  name                 = "snet-vm"
  virtual_network_name = data.azurerm_virtual_network.vnet-lz.name
  resource_group_name  = data.azurerm_virtual_network.vnet-lz.resource_group_name
}
data "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = var.rgLzName
}
data "azurerm_key_vault" "akv" {
  name                = local.kv_name
  resource_group_name = var.rgLzName
}
data "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  resource_group_name = var.rgLzName
}
data "azurerm_storage_account" "poc_st_acct" {
  name                = local.storage_account_name
  resource_group_name = var.rgLzName
}
data "azurerm_storage_container" "poc_st_blob" {
  name                 = var.storage_account_container_name
  storage_account_name = data.azurerm_storage_account.poc_st_acct.name
}
data "azurerm_mssql_server" "sql_server" {
  name                = local.sql_server_name
  resource_group_name = var.rgLzName
}
data "azurerm_user_assigned_identity" "sql_server_uai" {
  name                = local.sql_server_uai_name
  resource_group_name = var.rgLzName
}

# Gather required resources (Bastion) from the Hub Resource Group
data "azurerm_resources" "hub_bastion_s" {
  resource_group_name = var.rgHubName
  type                = "Microsoft.Network/bastionHosts"
}

# Generating the setup script from PowerShell file
data "template_file" "runner_setup_file" {
  template = file("Gitlab-runner-setup.ps1")
}
#*/
