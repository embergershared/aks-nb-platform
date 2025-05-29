# Control AKS traffic with Azure Firewall

## Steps

```pwsh
# Functions
function AddLog ($message) {
  #Add-Content -Path $filePath -Value "$(Get-Date): $message"
  Write-Host "$(Get-Date): $message"
}
function TrimAndRemoveHyphens {
  param(
    [Parameter(Mandatory = $true)]
    [string]$inputString,
        
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$maxLength
  )

  # First trim the string to the maximum length
  $trimmedString = $inputString.Substring(0, [System.Math]::Min($maxLength, $inputString.Length))
    
  # Remove any trailing hyphens
  $trimmedString = $trimmedString.TrimEnd('-')
    
  # Remove any leading hyphens
  $trimmedString = $trimmedString.TrimStart('-')
    
  return $trimmedString
}
function GeneratePassword {
  param(
    [ValidateRange(12, 256)]
    [int] 
    $length = 14
  )

  $symbols = '!@#$%^&*'.ToCharArray()
  $characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $symbols
  do {
    $password = -join (0..$length | % { $characterList | Get-Random })
    [int]$hasLowerChar = $password -cmatch '[a-z]'
    [int]$hasUpperChar = $password -cmatch '[A-Z]'
    [int]$hasDigit = $password -match '[0-9]'
    [int]$hasSymbol = $password.IndexOfAny($symbols) -ne -1
  }
  until (($hasLowerChar + $hasUpperChar + $hasDigit + $hasSymbol) -ge 3)

  return $password #| ConvertTo-SecureString -AsPlainText
}
AddLog "Functions loaded"

# Sourced variables
. \aks-values.ps1
# $SUFFIX = ""
# $LOC = ""
# $VM_USER_NAME = ""
# $VM_PUBLIC_PORT = ""

# Generated variables
$RG_NETWORK = "rg-net-${SUFFIX}"
$VNET_NAME = "vnet-${SUFFIX}"
$AKS_SUBNET_NAME = "aks-snet"
$AZFW_NAME = "azfw-${SUFFIX}"
$AZFW_PUBLICIP_NAME = "pip-for-azfw-${SUFFIX}"
$AZFW_IPCONFIG_NAME = "azfw-ipconfig-${SUFFIX}"
$AZFW_ROUTE_TABLE_NAME = "udr-${SUFFIX}"
$AZFW_ROUTE_NAME = "azfw-route-${SUFFIX}"
$AZFW_ROUTE_NAME_INTERNET = "azfw-route-internet-${SUFFIX}"

$KV_NAME = TrimAndRemoveHyphens -inputString "kv-${SUFFIX}" -maxLength 24
$LAW_NAME = TrimAndRemoveHyphens -inputString "law-${SUFFIX}" -maxLength 15
$ST_NAME = (TrimAndRemoveHyphens -inputString "st-${SUFFIX}" -maxLength 24).Replace("-", "").ToLower()

$VM_NAME = TrimAndRemoveHyphens -inputString "vm-win-${SUFFIX}" -maxLength 15
$VM_USER_PASSWORD_KV_SECRET_NAME = "${VM_NAME}-password"

$BASTION_NAME = "bastion-${SUFFIX}"
$BASTION_PIP_NAME = "pip-for-bastion-${SUFFIX}"

$RG_AKS = "rg-aks-${SUFFIX}"
$RG_AKS_MC = "${RG_AKS}-managed"
$AKS_NAME = "aks-${SUFFIX}"
$AKS_IDENTITY_NAME = "uai-${SUFFIX}"
AddLog "Variables values set"


# 1. Create Resource Groups
az group create --name $RG_NETWORK --location $LOC
az group create --name $RG_AKS --location $LOC
AddLog "Resource Groups created: $RG_NETWORK, $RG_AKS"

# 2. Create VNet and subnets
az network vnet create --resource-group $RG_NETWORK --name $VNET_NAME --location $LOC --address-prefixes 10.42.0.0/16 --subnet-name $AKS_SUBNET_NAME --subnet-prefix 10.42.1.0/24
az network vnet subnet create --resource-group $RG_NETWORK --vnet-name $VNET_NAME --name AzureFirewallSubnet --address-prefix 10.42.0.192/26
az network vnet subnet create --resource-group $RG_NETWORK --vnet-name $VNET_NAME --name AzureFirewallManagementSubnet --address-prefix 10.42.0.128/26
az network vnet subnet create --resource-group $RG_NETWORK --vnet-name $VNET_NAME --name AzureBastionSubnet --address-prefix 10.42.0.64/26
AddLog "VNet and its subnets created: $VNET_NAME"

# 3. Create Azure Firewall
az network public-ip create --resource-group $RG_NETWORK -n $AZFW_PUBLICIP_NAME --location $LOC --sku "Standard"
az extension add --name azure-firewall
az network firewall create --resource-group $RG_NETWORK --name $AZFW_NAME --location $LOC --enable-dns-proxy true
az network firewall ip-config create --resource-group $RG_NETWORK --firewall-name $AZFW_NAME --name $AZFW_IPCONFIG_NAME --public-ip-address $AZFW_PUBLICIP_NAME --vnet-name $VNET_NAME
AddLog "Azure Firewall created: $AZFW_NAME"

$AZFW_PUBLIC_IP = $(az network public-ip show --resource-group $RG_NETWORK --name $AZFW_PUBLICIP_NAME --query "ipAddress" -o tsv)
$AZFW_PRIVATE_IP = $(az network firewall show --resource-group $RG_NETWORK --name $AZFW_NAME --query "ipConfigurations[0].privateIPAddress" -o tsv)

# 4. Create UDR to Azure Firewall
az network route-table create --resource-group $RG_NETWORK --location $LOC --name $AZFW_ROUTE_TABLE_NAME
az network route-table route create --resource-group $RG_NETWORK --name $AZFW_ROUTE_NAME --route-table-name $AZFW_ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $AZFW_PRIVATE_IP
az network route-table route create --resource-group $RG --name $AZFW_ROUTE_NAME_INTERNET --route-table-name $AZFW_ROUTE_TABLE_NAME --address-prefix $AZFW_PUBLIC_IP/32 --next-hop-type Internet
AddLog "Route table created: $AZFW_ROUTE_TABLE_NAME"

# 5. Add Azure Firewall rules for AKS
az network firewall network-rule create --resource-group $RG_NETWORK --firewall-name $AZFW_NAME --collection-name 'NetwRC-Aks-AzFw' --name 'NetwR-api-udp' --protocols 'UDP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 1194 --action allow --priority 110
az network firewall network-rule create --resource-group $RG_NETWORK --firewall-name $AZFW_NAME --collection-name 'NetwRC-Aks-AzFw' --name 'NetwR-api-tcp' --protocols 'TCP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 9000
az network firewall network-rule create --resource-group $RG_NETWORK --firewall-name $AZFW_NAME --collection-name 'NetwRC-Aks-AzFw' --name 'NetwR-time' --protocols 'UDP' --source-addresses '*' --destination-fqdns 'ntp.ubuntu.com' --destination-ports 123
az network firewall network-rule create --resource-group $RG_NETWORK --firewall-name $AZFW_NAME --collection-name 'NetwRC-Aks-AzFw' --name 'NetwR-ghcr' --protocols 'TCP' --source-addresses '*' --destination-fqdns ghcr.io pkg-containers.githubusercontent.com --destination-ports '443'
az network firewall network-rule create --resource-group $RG_NETWORK --firewall-name $AZFW_NAME --collection-name 'NetwRC-Aks-AzFw' --name 'NetwR-docker' --protocols 'TCP' --source-addresses '*' --destination-fqdns docker.io registry-1.docker.io production.cloudflare.docker.com --destination-ports '443'

az network firewall application-rule create --resource-group $RG_NETWORK --firewall-name $AZFW_NAME --collection-name 'AppRC-Aks-Fw' --name 'AppR-fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 110
AddLog "Azure Firewall rules created for AKS"

# 6. Associate UDR to AKS subnet
az network vnet subnet update --resource-group $RG_NETWORK --vnet-name $VNET_NAME --name $AKS_SUBNET_NAME --route-table $AZFW_ROUTE_TABLE_NAME
AddLog "Route table associated to AKS subnet: $AKS_SUBNET_NAME"

# 7. Create Log Analytics Workspace & Storage account for logs
az monitor log-analytics workspace create --name $LAW_NAME --resource-group $RG_NETWORK --sku "PerGB2018" --location $LOC
AddLog "Log Analytics Workspace created: $LAW_NAME"
az storage account create --name $ST_NAME --resource-group $RG_NETWORK --location $LOC --sku Standard_LRS

# 8. Enable diagnostic settings for Azure Firewall
$LAW_ID = $(az monitor log-analytics workspace show --resource-group $RG_NETWORK --workspace-name $LAW_NAME --query id -o tsv)
$AZFW_ID = $(az network firewall show --resource-group $RG_NETWORK --name $AZFW_NAME --query id -o tsv)
$ST_ID = $(az storage account show --resource-group $RG_NETWORK --name $ST_NAME --query id -o tsv)

# Create diagnostic settings for Azure Firewall - Enable all Log categories
$diagnosticLogs = @(
  @{category = "AZFWApplicationRule"; enabled = $true }
  @{category = "AZFWApplicationRuleAggregation"; enabled = $true }

  @{category = "AZFWNatRule"; enabled = $true }
  @{category = "AZFWNatRuleAggregation"; enabled = $true }

  @{category = "AZFWNetworkRule"; enabled = $true }
  @{category = "AZFWNetworkRuleAggregation"; enabled = $true }

  @{category = "AZFWDnsQuery"; enabled = $true }
  @{category = "AZFWFqdnResolveFailure"; enabled = $true }

  @{category = "AZFWFatFlow"; enabled = $true }
  @{category = "AZFWFlowTrace"; enabled = $true }
  @{category = "AZFWIdpsSignature"; enabled = $true }
  @{category = "AZFWThreatIntel"; enabled = $true }
) | ConvertTo-Json -Compress

az monitor diagnostic-settings create --name "diag-law-${AZFW_NAME}" `
  --resource $AZFW_ID `
  --workspace $LAW_ID `
  --export-to-resource-specific true `
  --logs $diagnosticLogs
az monitor diagnostic-settings create --name "diag-st-${AZFW_NAME}" `
  --resource $AZFW_ID `
  --storage-account $ST_ID `
  --logs $diagnosticLogs
AddLog "Diagnostic settings created for Azure Firewall: $AZFW_NAME"

# 9. Create Azure Key Vault
az keyvault create --name $KV_NAME --resource-group $RG_NETWORK
AddLog "Key Vault created: $KV_NAME"

# 10. Create a Windows VM
# Create VM admin Password
$VM_USER_PASSWORD = GeneratePassword 16
az keyvault secret set --vault-name $KV_NAME --name $VM_USER_PASSWORD_KV_SECRET_NAME --value $VM_USER_PASSWORD
AddLog "Key Vault secret created: $VM_USER_PASSWORD_KV_SECRET_NAME"

# Create the Windows 11 VM
$SUBNET_ID = $(az network vnet subnet show --resource-group $RG_NETWORK --vnet-name $VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)
az vm create --resource-group $RG_AKS `
  --name $VM_NAME `
  --image "microsoftwindowsdesktop:windows-11:win11-24h2-pro:latest" `
  --public-ip-address '""' `
  --size "Standard_F16s_v2" `
  --subnet $SUBNET_ID `
  --admin-username $VM_USER_NAME `
  --admin-password $VM_USER_PASSWORD
AddLog "Windows VM created: $VM_NAME"

# 11. Create Azure Firewall rules for VM
$VM_PRIVATE_NIC_ID = $(az vm show --resource-group $RG_AKS --name $VM_NAME --query "networkProfile.networkInterfaces[0].id" -o tsv)
$VM_PRIVATE_IP = $(az network nic show --ids $VM_PRIVATE_NIC_ID --query "ipConfigurations[0].privateIPAddress" -o tsv)
$MY_PUBLIC_IP = $((Invoke-WebRequest ifconfig.me/ip).Content.Trim())

# Allow VM inbound access from Public internet to internal RDP through DNAT
az network firewall nat-rule create `
  --resource-group $RG_NETWORK `
  --firewall-name $AZFW_NAME `
  --collection-name 'NatRC-rdp' `
  --name 'NatR-vm-win11' `
  --destination-addresses $AZFW_PUBLIC_IP `
  --destination-ports $VM_PUBLIC_PORT$ `
  --protocols Any `
  --source-addresses $MY_PUBLIC_IP `
  --translated-port 3389 `
  --action Dnat `
  --priority 120 `
  --translated-address $VM_PRIVATE_IP

# Allow VM outbound access to Public internet
az network firewall network-rule create `
  --resource-group $RG_NETWORK `
  --firewall-name $AZFW_NAME `
  --collection-name 'NetwRC-vm-win11' `
  --name 'NetwR-allow-all-out' `
  --protocols 'Any' `
  --source-addresses $VM_PRIVATE_IP `
  --destination-addresses "*" `
  --destination-ports "*" `
  --action allow `
  --priority 120
AddLog "Azure Firewall rules created for VM: $VM_NAME"


# 12. Create Azure Bastion
az network public-ip create `
  --resource-group $RG_NETWORK `
  --name $BASTION_PIP_NAME `
  --location $LOC `
  --sku Standard
az network bastion create `
  --name $BASTION_NAME `
  --public-ip-address $BASTION_PIP_NAME `
  --resource-group $RG_NETWORK `
  --vnet-name $VNET_NAME `
  --location $LOC `
  --sku Basic


# Create ACR
az acr create -n myregistry -g MyResourceGroup --sku Standard --role-assignment-mode rbac-abac

# 13. Create Private DNS Zone
az network private-dns zone create -g $RG_NETWORK -n "privatelink.$LOC.azmk8s.io"
az network private-dns link vnet create -g $RG_NETWORK -n PrivateAks-ZoneLink `
  -z "privatelink.$LOC.azmk8s.io" `
  -v $VNET_NAME `
  -e false
AddLog "Private DNS Zone created: privatelink.$LOC.azmk8s.io"

# 14. Prepare AKS deployment
$VNET_ID = $(az network vnet show -g $RG_NETWORK -n $VNET_NAME --query id -o tsv)
$SUBNET_ID = $(az network vnet subnet show --resource-group $RG_NETWORK --vnet-name $VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)
$PRIV_DNS_ZONE_ID = $(az network private-dns zone show --resource-group $RG_NETWORK -n "privatelink.$LOC.azmk8s.io" --query id -o tsv)

az identity create --resource-group $RG_AKS --name $AKS_IDENTITY_NAME --location $LOC
$IDENTITY_PRINCIPAL_ID = $(az identity show --resource-group $RG_AKS --name $AKS_IDENTITY_NAME --query principalId -o tsv)
$IDENTITY_RESOURCE_ID = $(az identity show --resource-group $RG_AKS --name $AKS_IDENTITY_NAME --query id -o tsv)
AddLog "User Assigned Identity created: $AKS_IDENTITY_NAME"

az role assignment create --scope $VNET_ID --role "Network Contributor" --assignee $IDENTITY_PRINCIPAL_ID
az role assignment create --scope $PRIV_DNS_ZONE_ID --role "Contributor" --assignee $IDENTITY_PRINCIPAL_ID
AddLog  "Role assignments created for User Assigned Identity: $AKS_IDENTITY_NAME"


# 15. Deploy AKS cluster with outbound rule
az aks create --resource-group $RG_AKS `
  --name $AKS_NAME `
  --location $LOC `
  --node-resource-group $RG_AKS_MC `
  --node-count 3 `
  --network-plugin azure `
  --network-plugin-mode overlay `
  --outbound-type userDefinedRouting `
  --vnet-subnet-id $SUBNET_ID `
  --generate-ssh-keys `
  --pod-cidr 10.244.0.0/16 `
  --assign-identity $IDENTITY_RESOURCE_ID `
  --enable-private-cluster `
  --private-dns-zone $PRIV_DNS_ZONE_ID `
  --disable-public-fqdn `
  --node-vm-size Standard_D2as_v5 `
  --os-sku AzureLinux `
  --network-policy calico
AddLog "AKS cluster created: $AKS_NAME"
```

## References

[Limit network traffic with Azure Firewall in Azure Kubernetes Service (AKS)](<https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic?tabs=aks-with-system-assigned-identities>)

[Create an Azure private DNS zone using the Azure CLI](https://learn.microsoft.com/en-us/azure/dns/private-dns-getstarted-cli)

[`az aks create` reference](https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create)
