# 09_values.auto.tfvars

plan_tags = {
  Plan = "09-GitLab-Runner"
}

os_type  = "Windows"
sku_size = "Standard_F16s_v2"

source_image_reference = {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2025-datacenter-g2"
  version   = "latest"
}

gl_runner_admin_username = "glRunnerAdmin"

msft_entra_id_group_name = "HWW AKS PoC - MSFT team"
hww_entra_id_group_name  = "HWW AKS PoC - Hilton team"
private_dns_zone_name    = "private.contoso.com"
