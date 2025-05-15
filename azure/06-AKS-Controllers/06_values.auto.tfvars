# 10_values.auto.tfvars

plan_tags = {
  Plan = "10-AKS-Controllers"
}

private_ingress_controller_ns_name = "internal-ing-ctrl"
private_ingress_load_balancer_ip   = "10.1.1.7"

cert_manager_ns_name            = "cert-manager"
self_signed_cluster_issuer_name = "selfsigned-cluster-issuer"
root_ca_name                    = "hww-poc-ca-cert"
root_ca_certificate_name        = "root-ca-certificate"
certificate_ca_issuer_name      = "hww-poc-ca-cluster-issuer"
