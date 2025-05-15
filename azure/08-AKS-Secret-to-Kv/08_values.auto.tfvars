# 12_values.auto.tfvars

plan_tags = {
  Plan = "12-AKS-Secret-to-Kv"
}

k8s_cert_mgr_ns_name       = "cert-manager"
k8s_rootcacert_secret_name = "root-ca-certificate"

storage_account_container_name = "poc-data"
