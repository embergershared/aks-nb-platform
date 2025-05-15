locals {
  # Existing resources extraction:
  lz_vnet_name         = [for v in data.azurerm_resources.lz_rg_resource_s.resources : v.name if v.type == "Microsoft.Network/virtualNetworks"].0
  acr_name             = [for v in data.azurerm_resources.lz_rg_resource_s.resources : v.name if v.type == "Microsoft.ContainerRegistry/registries"].0
  kv_name              = [for v in data.azurerm_resources.lz_rg_resource_s.resources : v.name if v.type == "Microsoft.KeyVault/vaults"].0
  aks_name             = [for v in data.azurerm_resources.lz_rg_resource_s.resources : v.name if v.type == "Microsoft.ContainerService/managedClusters"].0
  storage_account_name = [for v in data.azurerm_resources.lz_rg_resource_s.resources : v.name if(v.type == "Microsoft.Storage/storageAccounts" && lookup(v.tags, "Plan", "AbsentKey") == "08-AzSQL-Data")].0
  sql_server_name      = [for v in data.azurerm_resources.lz_rg_resource_s.resources : v.name if(v.type == "Microsoft.Sql/servers" && lookup(v.tags, "Plan", "AbsentKey") == "08-AzSQL-Data")].0
  sql_server_uai_name  = [for v in data.azurerm_resources.lz_rg_resource_s.resources : v.name if(v.type == "Microsoft.ManagedIdentity/userAssignedIdentities" && lookup(v.tags, "Plan", "AbsentKey") == "08-AzSQL-Data")].0

  # Matching Resource IDs from their data sources
  vnetLzId          = data.azurerm_virtual_network.vnet-lz.id
  snetvmId          = data.azurerm_subnet.snet-vm.id
  acrId             = data.azurerm_container_registry.acr.id
  akvId             = data.azurerm_key_vault.akv.id
  aksId             = data.azurerm_kubernetes_cluster.aks.id
  sql_server_id     = data.azurerm_mssql_server.sql_server.id
  sql_server_uai_id = data.azurerm_user_assigned_identity.sql_server_uai.id

  # Bastion resource names
  hub_bastion_name    = data.azurerm_resources.hub_bastion_s.resources.0.name
  hub_bastion_rg_name = data.azurerm_resources.hub_bastion_s.resources.0.resource_group_name

  # Custom extension script parameters
  param_1 = var.gitlab_runner_token
  param_2 = data.azurerm_storage_account.poc_st_acct.name
  param_3 = data.azurerm_storage_container.poc_st_blob.name
  param_4 = module.uai_mid_gitlab.client_id
}
