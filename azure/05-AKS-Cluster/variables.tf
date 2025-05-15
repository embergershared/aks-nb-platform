variable "rgLzName" {
  type    = string
  default = "AksTerra-AVM-LZ-RG"
}

variable "rgHubName" {
  type    = string
  default = "AksTerra-AVM-Hub-RG"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "vnetLzName" {
  type    = string
  default = "vnet-lz"
}

variable "vnetHubName" {
  type    = string
  default = "vnet-hub"
}

variable "adminGroupObjectIds" {
  type    = string
  default = " "
}

variable "acrName" {
  type    = string
  default = "acrlzti5y"
}

variable "akvName" {
  type    = string
  default = "akvlzti5y"
}

variable "deployingAllInOne" {
  type    = bool
  default = false
}

variable "vnetLzId" {
  type    = string
  default = ""
}

variable "snetAksId" {
  type    = string
  default = ""
}


variable "dnszoneAksId" {
  type    = string
  default = ""
}

variable "dnszoneContosoId" {
  type    = string
  default = ""
}

variable "acrId" {
  type    = string
  default = ""
}

variable "akvId" {
  type    = string
  default = ""
}

variable "aks_k8s_version" {}
variable "aks_np_system_version" {}
variable "aks_np_windows_version" {}

variable "metric_annotations_allowlist" { default = null }
variable "metric_labels_allowlist" { default = null }
