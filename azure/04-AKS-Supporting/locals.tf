locals {
  domain_name = {
    akv = "privatelink.vaultcore.azure.net",
    acr = "privatelink.azurecr.io",
    aks = "azurek8s.io"
  }

  speSubnetId  = var.deployingAllInOne == true ? var.speSubnetId : data.azurerm_subnet.snet-spe.0.id
  dnszoneAkvId = var.deployingAllInOne == true ? var.dnszoneAkvId : data.azurerm_private_dns_zone.dnszone-akv.0.id
  dnszoneAcrId = var.deployingAllInOne == true ? var.dnszoneAcrId : data.azurerm_private_dns_zone.dnszone-acr.0.id
}
