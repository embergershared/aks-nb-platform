locals {
  vnetHubId         = var.deployingAllInOne == true ? var.vnetHubId : data.azurerm_virtual_network.vnethub.0.id
  firewallPrivateIp = var.deployingAllInOne == true ? var.firewallPrivateIp : data.azurerm_firewall.firewall.0.ip_configuration.0.private_ip_address

  appgw_nsg_rules = {
    "rule01" = {
      name                       = "Allow443InBound"
      access                     = "Allow"
      destination_address_prefix = "*"
      destination_port_range     = "443"
      direction                  = "Inbound"
      priority                   = 100
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
    }
    "rule02" = {
      name                       = "AllowControlPlaneV2SKU"
      access                     = "Allow"
      destination_address_prefix = "*"
      destination_port_ranges    = ["65200-65535"]
      direction                  = "Inbound"
      priority                   = 200
      protocol                   = "Tcp"
      source_address_prefix      = "GatewayManager"
      source_port_range          = "*"
    }
    "rule03" = {
      name                       = "Allow80InBound"
      access                     = "Allow"
      destination_address_prefix = "*"
      destination_port_ranges    = ["80"]
      direction                  = "Inbound"
      priority                   = 300
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
    }
  }

  domain_name = {
    akv               = "privatelink.vaultcore.azure.net",
    acr               = "privatelink.azurecr.io",
    aks               = "azmk8s.io"
    sql               = "privatelink.database.windows.net"
    contoso           = "private.contoso.com"
    storage_file      = "privatelink.file.core.windows.net"
    storage_blob      = "privatelink.blob.core.windows.net"
    AzureUSGovernment = ".cx.aks.containerservice.azure.us"
    AzureChinaCloud   = ".cx.prod.service.azk8s.cn"
    AzureGermanCloud  = "" //TODO: what is the correct value here?
  }
}
