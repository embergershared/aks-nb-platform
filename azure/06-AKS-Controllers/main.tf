#############   Private Nginx Ingress Controller on   #############
resource "kubernetes_namespace" "ing_ns" {
  metadata {
    name = var.private_ingress_controller_ns_name
  }
}
resource "helm_release" "private_ingress_controller_release" {
  depends_on = [
    kubernetes_namespace.ing_ns,
  ]

  namespace = kubernetes_namespace.ing_ns.metadata[0].name
  name      = "private-ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  # Additional settings
  cleanup_on_fail = true # default= false

  set {
    name  = "controller.extraArgs.default-ssl-certificate"
    value = "ingress-basic/default-ingress-tls"
  }
  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx-internal"
  }
  set {
    name  = "controller.ingressClassResource.default"
    value = "true"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }
  set {
    name  = "controller.service.loadBalancerIP"
    value = var.private_ingress_load_balancer_ip
  }
}

#############   Cert Manager   #############
# Cert Manager to issue and register Ingress TLS certificates
resource "kubernetes_namespace" "cert_manager_ns" {
  metadata {
    name = var.cert_manager_ns_name
  }
}
resource "helm_release" "cert_manager_release" {
  depends_on = [
    kubernetes_namespace.cert_manager_ns,
  ]

  namespace = kubernetes_namespace.cert_manager_ns.metadata[0].name
  name      = "cert-manager"

  repository = "https://charts.jetstack.io/"
  chart      = "cert-manager"
  version    = "v1.17.0"

  # Additional settings
  cleanup_on_fail = true # default= false

  set {
    name  = "installCRDs"
    value = "true"
  }
}
#*/
