# Boot strap the Cert issuer for all cluster based on a self-signed certificate
# https://cert-manager.io/docs/configuration/selfsigned/#bootstrapping-ca-issuers

resource "kubernetes_manifest" "cluster_issuer_self_signed" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "${var.self_signed_cluster_issuer_name}"
    }
    spec = {
      selfSigned = {}
    }
  }
}
# Certificate Authority
resource "kubernetes_manifest" "poc_root_ca" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "${var.root_ca_name}"
      namespace = "${data.kubernetes_namespace.cert_manager_ns.metadata[0].name}"
    }
    spec = {
      isCA = "true"
      # commonName = "${upper(local.aks_name)} - AKS Cluster CA"
      literalSubject = "O=Contoso private for Hilton WW, CN=${upper(local.aks_name)} cluster AKS Certificate Authority, OU=AKS PoC"
      secretName     = "${var.root_ca_certificate_name}"
      usages = [
        "server auth",
        "client auth"
      ]
      privateKey = {
        # algorithm = "ECDSA"
        # size      = 256
        algorithm = "RSA"
        encoding  = "PKCS1"
        size      = 4096
      }
      issuerRef = {
        name  = "${kubernetes_manifest.cluster_issuer_self_signed.manifest.metadata.name}"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.cluster_issuer_self_signed
  ]
}

# Certificates Cluster Issuer for the entire cluster using the CA
# Using Just Issuer would make the Issuer namespaced
resource "kubernetes_manifest" "cluster_issuer_poc_ca" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "${var.certificate_ca_issuer_name}"
    }
    spec = {
      ca = {
        secretName = "${kubernetes_manifest.poc_root_ca.manifest.spec.secretName}"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.poc_root_ca
  ]
}
#*/
