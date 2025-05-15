module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"

  suffix = ["lz"]
}

module "avm-res-containerregistry-registry" {
  source           = "Azure/avm-res-containerregistry-registry/azurerm"
  version          = "0.3.1"
  enable_telemetry = false

  name                          = var.acrName
  location                      = var.location
  resource_group_name           = var.rgLzName
  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"

  private_endpoints = {
    primary = {
      private_dns_zone_resource_ids = [local.dnszoneAcrId]
      subnet_resource_id            = local.speSubnetId
    }
  }

  tags = merge(var.base_tags, var.plan_tags)
}

module "avm-res-keyvault-vault" {
  source           = "Azure/avm-res-keyvault-vault/azurerm"
  version          = "0.9.1"
  enable_telemetry = false

  name                          = var.akvName
  location                      = var.location
  resource_group_name           = var.rgLzName
  tenant_id                     = data.azurerm_client_config.tenant.tenant_id
  public_network_access_enabled = true
  private_endpoints = {
    primary = {
      private_dns_zone_resource_ids = [local.dnszoneAkvId]
      subnet_resource_id            = local.speSubnetId
    }
  }
  network_acls = {
    ip_rules = var.authorized_ips
  }

  tags = merge(var.base_tags, var.plan_tags)
}

resource "azurerm_role_assignment" "terraform_secretofficer_role_assignment" {
  scope                = module.avm-res-keyvault-vault.resource_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.tenant.object_id
}


##################   Managed Prometheus & Grafana   ##################
# Ref: https://github.com/Azure/prometheus-collector/tree/main/AddonTerraformTemplate
resource "azurerm_resource_provider_registration" "prometheus" {
  name = "Microsoft.Dashboard"
}

resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-aks"
  resource_group_name = var.rgLzName
  location            = var.location
}

resource "azurerm_dashboard_grafana" "grafana" {
  name                  = "grafana-aks"
  resource_group_name   = var.rgLzName
  location              = var.location
  grafana_major_version = "10"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.amw.id
  }
}

resource "azurerm_role_assignment" "data_reader_role_assignment" {
  scope              = azurerm_monitor_workspace.amw.id
  role_definition_id = "/subscriptions/${split("/", azurerm_monitor_workspace.amw.id)[2]}/providers/Microsoft.Authorization/roleDefinitions/b0d8363b-8ddd-447d-831f-62ca05bff136"
  principal_id       = azurerm_dashboard_grafana.grafana.identity.0.principal_id
}

resource "azurerm_role_assignment" "grafana_admin_role_assignment" {
  count = length(var.grafana_admin_s)

  principal_id                     = var.grafana_admin_s[count.index]
  principal_type                   = "Group"
  role_definition_name             = "Grafana Admin"
  scope                            = azurerm_dashboard_grafana.grafana.id
  skip_service_principal_aad_check = true
}
#*/
