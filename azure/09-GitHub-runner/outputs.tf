output "bastion_rdp_cmd" {
  value = "az network bastion rdp --name ${local.hub_bastion_name} --resource-group ${local.hub_bastion_rg_name} --target-resource-id ${module.gitlab_runner_vm.resource_id} --configure"
}
# output "resources" {
#   # value = data.azurerm_resources.lz_rg_resource_s.resources
#   value = [for v in data.azurerm_resources.lz_rg_resource_s.resources : [v.name, v.type]]
# }
# output "azurerm_storage_account" {
#   value = data.azurerm_storage_account.poc_st_acct
# }

# output "gitlab_runner_token" {
#   value     = data.template_file.gl_runner_script.vars.gitlab_runner_token
#   sensitive = true
# }
# output "StAcctName" {
#   value = data.template_file.gl_runner_script.vars.StAcctName
# }
# output "StContainerName" {
#   value = data.template_file.gl_runner_script.vars.StContainerName
# }
# output "MSIClientid" {
#   value = data.template_file.gl_runner_script.vars.MSIClientid
# }
