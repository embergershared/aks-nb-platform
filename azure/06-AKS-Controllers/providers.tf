terraform {
  required_version = "~> 1.6"
  required_providers {
    azurerm = {
      # https://registry.terraform.io/providers/hashicorp/azurerm/latest
      source  = "hashicorp/azurerm"
      version = "~> 3.74"
    }
    kubernetes = {
      # https://registry.terraform.io/providers/hashicorp/kubernetes/latest
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      # https://registry.terraform.io/providers/hashicorp/helm/latest
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }
}

provider "azurerm" {
  # alias = "platform-lz"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  # resource_provider_registrations = "none" # Enum: core, none, all, extended, legacy # azurerm ~> 4.0 attribute
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# / Kubelogin with az cli login
#   To use it: in the console that runs terraform, perform an "az login", then run terraform
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login",
      "azurecli",
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630"
    ]
  }
}

provider "helm" {
  # Ref: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
  #      https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630"
      ]
    }
  }
}
