# rg ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"

  suffix = ["gitlab"]
}
resource "random_password" "vm_password" {
  length  = 16
  special = true
  numeric = true
  lower   = true
  upper   = true
}
module "uai_mid_gitlab" {
  source           = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version          = "0.3.3"
  enable_telemetry = false

  name                = "uai-${module.naming.virtual_machine.name_unique}"
  location            = var.location # data.azurerm_resource_group.rg.location
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name

  tags = merge(var.base_tags, var.plan_tags)
}
module "gitlab_runner_vm" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.17.0
  enable_telemetry = false

  name                = module.naming.virtual_machine.name_unique
  location            = var.location
  resource_group_name = var.rgLzName

  admin_username                     = var.gl_runner_admin_username
  admin_password                     = random_password.vm_password.result
  disable_password_authentication    = false
  encryption_at_host_enabled         = true
  generate_admin_password_or_ssh_key = false
  secure_boot_enabled                = false
  vtpm_enabled                       = false
  os_type                            = var.os_type
  sku_size                           = var.sku_size
  zone                               = 1

  bypass_platform_safety_checks_on_user_schedule_enabled = true
  patch_assessment_mode                                  = "AutomaticByPlatform"
  patch_mode                                             = "AutomaticByPlatform"

  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = local.snetvmId
        }
      }
    }
  }

  managed_identities = {
    user_assigned_resource_ids = [
      module.uai_mid_gitlab.resource_id,
      local.sql_server_uai_id
    ]
  }

  os_disk = {
    caching = "ReadWrite"
    # storage_account_type = "Premium_LRS" # Requested but getting replaced (??) by standard after deployment
    storage_account_type = "Standard_LRS"
  }

  # source_image_reference = {
  #   publisher = "Canonical"
  #   offer     = "0001-com-ubuntu-server-jammy"
  #   sku       = "22_04-lts-gen2"
  #   version   = "latest"
  # }
  source_image_reference = var.source_image_reference

  tags = merge(var.base_tags, var.plan_tags)
}
resource "azurerm_virtual_machine_extension" "entra_id_login" {
  name                       = "AADLoginForWindows"
  virtual_machine_id         = module.gitlab_runner_vm.resource_id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.2"
  auto_upgrade_minor_version = true

  tags = merge(var.base_tags, var.plan_tags)
}
resource "azurerm_key_vault_secret" "this" {
  name         = "${module.gitlab_runner_vm.name}-password"
  value        = random_password.vm_password.result
  key_vault_id = local.akvId
}

# Creating role assignments for the PoC users' groups to login to the Jumpbox with their Entra ID user
resource "azurerm_role_assignment" "msft_group_role_assignment" {
  scope                            = module.gitlab_runner_vm.resource_id
  role_definition_name             = "Virtual Machine Administrator Login"
  principal_id                     = data.azuread_group.msft_entra_id_group.id
  principal_type                   = "Group"
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "hww_group_role_assignment" {
  scope                            = module.gitlab_runner_vm.resource_id
  role_definition_name             = "Virtual Machine User Login"
  principal_id                     = data.azuread_group.hww_entra_id_group.id
  principal_type                   = "Group"
  skip_service_principal_aad_check = true
}

# Creating the A record in the Private DNS Zone for the VM
resource "azurerm_private_dns_a_record" "time_tracker_ingress_a_record" {
  name                = module.naming.virtual_machine.name_unique
  zone_name           = data.azurerm_private_dns_zone.private_dns_zone.name
  resource_group_name = var.rgLzName
  ttl                 = 60

  records = [
    module.gitlab_runner_vm.network_interfaces["network_interface_1"].private_ip_address
  ]
}

# Giving the GitLab Runner MSI access to the other Azure resources though RBAC
resource "azurerm_role_assignment" "acr_push_role_assignment" {
  scope                            = local.acrId
  role_definition_name             = "ACrPush"
  principal_id                     = module.uai_mid_gitlab.principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "aks_rbac_cluster_admin_role_assignment" {
  scope                            = local.aksId
  role_definition_name             = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id                     = module.uai_mid_gitlab.principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "blob_reader_role_assignment" {
  scope                            = data.azurerm_storage_account.poc_st_acct.id
  role_definition_name             = "Storage Blob Data Reader"
  principal_id                     = module.uai_mid_gitlab.principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "kv_secret_reader_role_assignment" {
  scope                            = local.akvId
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = module.uai_mid_gitlab.principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "az_sql_role_assignment" {
  scope                            = local.sql_server_id
  role_definition_name             = "SQL Server Contributor"
  principal_id                     = module.uai_mid_gitlab.principal_id
  skip_service_principal_aad_check = true
}

# Install the VM as a Gitlab runner
resource "azurerm_virtual_machine_extension" "gl_runner_setup_ext" {
  name                       = "runner-setup"
  virtual_machine_id         = module.gitlab_runner_vm.resource_id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  provision_after_extensions = []
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = false

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.runner_setup_file.rendered)}')) | Out-File -filepath Gitlab-runner-setup.ps1\" && powershell -ExecutionPolicy Unrestricted -File Gitlab-runner-setup.ps1 -Param1 \"${local.param_1}\" -Param2 \"${local.param_2}\" -Param3 \"${local.param_3}\" -Param4 \"${local.param_4}\""
  }
SETTINGS

  tags = {}
}

# "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.gl_runner_script.rendered)}')) | Out-File -filepath Gitlab-runner-setup.ps1\" && powershell -ExecutionPolicy Unrestricted -File Gitlab-runner-setup.ps1 -GitLabRunnerToken ${data.template_file.gl_runner_script.vars.GitLabRunnerToken} -StorageAccountName ${data.template_file.gl_runner_script.vars.StorageAccountName} -StorageAccountFileShareName ${data.template_file.gl_runner_script.vars.StorageAccountFileShareName} -StorageAccountFileShareAccessKey ${data.template_file.gl_runner_script.vars.StorageAccountFileShareAccessKey}"
# "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.gl_runner_script.rendered)}')) | Out-File -filepath Gitlab-runner-setup.ps1\" && powershell -ExecutionPolicy Unrestricted -File Gitlab-runner-setup.ps1"
# "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.gl_runner_script.rendered)}')) | Out-File -filepath Gitlab-runner-setup.ps1\" && powershell -ExecutionPolicy Unrestricted -File Gitlab-runner-setup.ps1 -GitLabRunnerToken ${data.template_file.gl_runner_script.vars.gitlab_runner_token} -StAcctName ${data.template_file.gl_runner_script.vars.StAcctName} -StContainerName ${data.template_file.gl_runner_script.vars.StContainerName} -MSIClientid ${data.template_file.gl_runner_script.vars.MSIClientid}"
# "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.gl_runner_script.rendered)}')) | Out-File -filepath Gitlab-runner-setup.ps1\" && powershell -ExecutionPolicy Unrestricted -File Gitlab-runner-setup.ps1 -GitLabRunnerToken ${data.template_file.gl_runner_script.vars.gitlab_runner_token} -StAcctName ${data.template_file.gl_runner_script.vars.st_acct_name} -StContainerName ${data.template_file.gl_runner_script.vars.blob_container_name} -MSIClientid ${data.template_file.gl_runner_script.vars.msi_client_id}"

#*/
