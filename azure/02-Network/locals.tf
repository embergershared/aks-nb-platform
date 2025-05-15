locals {
  jumpbox_nsg_rules = {}
  #   "rule01" = {
  #     name                       = "AllowRDPInBound"
  #     access                     = "Allow"
  #     destination_address_prefix = "*"
  #     destination_port_range     = "3389"
  #     direction                  = "Inbound"
  #     priority                   = 100
  #     protocol                   = "Tcp"
  #     source_address_prefix      = "*"
  #     source_port_range          = "*"
  #   }
  #   rule02 = {
  #     name                       = "AllowSSHInBound"
  #     access                     = "Allow"
  #     destination_address_prefix = "*"
  #     destination_port_range     = "22"
  #     direction                  = "Inbound"
  #     priority                   = 200
  #     protocol                   = "Tcp"
  #     source_address_prefix      = "*"
  #     source_port_range          = "*"
  #   }
  # }
}
