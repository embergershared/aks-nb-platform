# This code takes the Kubernetes Certificate created for the AKS CA and stores it in Azure
resource "pkcs12_from_pem" "root_ca_cert_pkcs12" {
  # Equivalent to: openssl pkcs12 -export -out tls.pfx -inkey tls.key.pem -in tls.crt.pem
  password        = var.pkcs12_password
  cert_pem        = data.kubernetes_secret.root_ca_cert_secret.data["tls.crt"]
  private_key_pem = data.kubernetes_secret.root_ca_cert_secret.data["tls.key"]
  encoding        = "modern"
}

# resource "local_file" "cert_pfx" {
#   filename       = "${var.k8s_rootcacert_secret_name}.pfx"
#   content_base64 = pkcs12_from_pem.root_ca_cert_pkcs12.result
# }

resource "local_file" "cert_crt" {
  filename       = "${data.azurerm_kubernetes_cluster.aks.name}-ca-cert.crt"
  content_base64 = base64encode(data.kubernetes_secret.root_ca_cert_secret.data["tls.crt"])
}

resource "azurerm_key_vault_certificate" "poc_root_ca_cert" {
  name         = "${data.azurerm_kubernetes_cluster.aks.name}-ca-cert-01"
  key_vault_id = data.azurerm_key_vault.akv.id

  certificate {
    contents = pkcs12_from_pem.root_ca_cert_pkcs12.result
    password = var.pkcs12_password
  }
  tags = merge(var.base_tags, var.plan_tags)
}

resource "azurerm_storage_blob" "cert_crt_blob" {
  name                   = "${data.azurerm_kubernetes_cluster.aks.name}-ca-cert.crt"
  storage_account_name   = data.azurerm_storage_account.poc_st_acct.name
  storage_container_name = data.azurerm_storage_container.poc_st_blob_container.name
  type                   = "Block"
  source_content         = data.kubernetes_secret.root_ca_cert_secret.data["tls.crt"]
}
#*/
