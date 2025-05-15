locals {
  domain_name = {
    akv     = "privatelink.vaultcore.azure.net",
    acr     = "privatelink.azurecr.io",
    aks     = "azmk8s.io"
    contoso = "private.contoso.com"
  }

  vnetLzId         = var.deployingAllInOne == true ? var.vnetLzId : data.azurerm_virtual_network.vnet-lz.0.id
  snetAksId        = var.deployingAllInOne == true ? var.snetAksId : data.azurerm_subnet.snet-aks.0.id
  dnszoneAksId     = var.deployingAllInOne == true ? var.dnszoneAksId : data.azurerm_private_dns_zone.dnszone-aks.0.id
  dnszoneContosoId = var.deployingAllInOne == true ? var.dnszoneContosoId : data.azurerm_private_dns_zone.dnszone-contoso.0.id
  acrId            = var.deployingAllInOne == true ? var.acrId : data.azurerm_container_registry.acr.0.id
  akvId            = var.deployingAllInOne == true ? var.akvId : data.azurerm_key_vault.akv.0.id
}
