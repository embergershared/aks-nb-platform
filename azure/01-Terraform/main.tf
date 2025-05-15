# rg ensures we have unique CAF compliant names for our resources.
# rg is required for resource modules
resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = "rg-use2-391575-s3-akswincont-tfstates"

  tags = merge(var.base_tags, var.plan_tags)
}

#--------------------------------------------------------------
#   Terraform States Storage Account
#--------------------------------------------------------------
#   / Main location storage account for remote backend Terraform States
resource "azurerm_storage_account" "this" {
  name                = "st391575s3tfstates"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  large_file_share_enabled        = false
  nfsv3_enabled                   = false
  local_user_enabled              = false
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false # Disable anonymous public read access to containers and blobs
  https_traffic_only_enabled      = true  # Require secure transfer (HTTPS) to the storage account for REST API Operations
  min_tls_version                 = "TLS1_2"

  network_rules {
    default_action = "Deny"
    ip_rules       = var.authorized_ips
    virtual_network_subnet_ids = [
      "/subscriptions/${var.subscription_id}/resourceGroups/rg-use2-391575-s3-akswincont-avm-lz/providers/Microsoft.Network/virtualNetworks/vnet-lz/subnets/snet-vm"
    ]
    private_link_access {
      endpoint_resource_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Security/datascanners/StorageDataScanner"
      endpoint_tenant_id   = var.tenant_id
    }
  }

  tags = azurerm_resource_group.rg.tags
}

################################  Store data in Storage Account  ################################
#------------------------------
# - Containers
#------------------------------
resource "azurerm_storage_container" "this" {
  name = "akswincont-lz"
  # storage_account_name = azurerm_storage_account.this.name
  storage_account_id = azurerm_storage_account.this.id

  # Infrastructure Protection: Block Internet access and restrict network connectivity to the Storage account via the Storage firewall and access the data objects in the Storage account via Private Endpoint which secures all traffic between VNet and the storage account over a Private Link.
  container_access_type = "private"
}
#*/
