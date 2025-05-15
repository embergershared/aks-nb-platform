# 11_values.auto.tfvars

plan_tags = {
  Plan = "11-AKS-Certs-Issuer"
}

cert_manager_ns_name            = "cert-manager"
self_signed_cluster_issuer_name = "selfsigned-cluster-issuer"
root_ca_name                    = "hww-poc-ca-cert"
root_ca_certificate_name        = "root-ca-certificate"
certificate_ca_issuer_name      = "hww-poc-ca-cluster-issuer"
