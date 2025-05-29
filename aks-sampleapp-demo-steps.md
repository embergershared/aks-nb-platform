# AKS Sample Application Deployment

## Deployment steps

### Build and push or import container images to an ACR

- Check network access to the ACR Private Endpoint and Container Registry attachment to the Private AKS cluster

```pwsh
# Sourced variables
. \aks-values.ps1
# $SUBSC_ID = ""
# $ACR_NAME = ""
# $AKS_STORE_PUBLIC_PORT = ""
# $AKS_ING_PUBLIC_PORT = ""

az login
az account set -s $SUBSC_ID

az acr build --registry "$ACR_NAME" --image aks-store-demo/product-service:latest ./src/product-service/
# az acr build --registry "$ACR_NAME" --image aks-store-demo/order-service:latest ./src/order-service/
# az acr build --registry "$ACR_NAME" --image aks-store-demo/store-front:latest ./src/store-front/

# ghcr.io/azure-samples/aks-store-demo/product-service:latest
# ghcr.io/azure-samples/aks-store-demo/order-service:latest
# ghcr.io/azure-samples/aks-store-demo/store-front:latest
az acr import --name "$ACR_NAME" `
  --source "ghcr.io/azure-samples/aks-store-demo/order-service:latest" `
  --image "aks-store-demo/order-service:latest"
  # --username "$SRC_ACR_USER" `
  # --password "$SRC_ACR_PWD"

az acr import --name "$ACR_NAME" `
  --source "ghcr.io/azure-samples/aks-store-demo/store-front:latest" `
  --image "aks-store-demo/store-front:latest"
```

### Deploy an application to Azure Kubernetes Service (AKS)

```pwsh
# Update the manifest file

# 1. Update the image references in the `aks-store-quickstart.yaml` file
containers:
...
- name: order-service
  image: "$ACR_NAME".azurecr.io/aks-store-demo/order-service:latest
...
- name: product-service
  image: "$ACR_NAME".azurecr.io/aks-store-demo/product-service:latest
...
- name: store-front
  image: "$ACR_NAME".azurecr.io/aks-store-demo/store-front:latest
...

# 2. Save and close the file

# 3. Deploy the application with an Internal Load Balancer
<check the kubectl context and access to the Private AKS cluster>
<create a namespace to deploy into>
kubectl apply -f ./aks-store-demo/aks-store-quickstart.yaml -n <namespace>

# 4. Check the status of the pods
kubectl get pods -n <namespace>

# 5. Check the status of the services
kubectl get service store-front --watch -n <namespace>

# 6. Check the service at its Internal IP
http://10.42.1.235
```

## Publish the service Publicly through Azure Firewall

```pwsh
# Create a NAT rule to forward traffic from the Azure Firewall to the internal service
$RG_NETWORK = "rg-net-${SUFFIX}"
$AZFW_NAME = "azfw-${SUFFIX}"
$AZFW_PUBLICIP_NAME = "pip-for-azfw-${SUFFIX}"
$VNET_NAME = "vnet-${SUFFIX}"
$AKS_SUBNET_NAME = "aks-snet"

$AZFW_PUBLIC_IP = $(az network public-ip show --resource-group $RG_NETWORK --name $AZFW_PUBLICIP_NAME --query "ipAddress" -o tsv)
$MY_PUBLIC_IP = $((Invoke-WebRequest ifconfig.me/ip).Content.Trim()) # 35.140.25.92
$AKS_SUBNET_CIDR = $(az network vnet subnet show --resource-group $RG_NETWORK --vnet-name $VNET_NAME --name $AKS_SUBNET_NAME --query "addressPrefix" -o tsv)

$STORE_FRONT_END_SERVICE_IP = $(kubectl get svc store-front -o jsonpath='{.status.loadBalancer.ingress[*].ip}' -n aks-store)
# $STORE_FRONT_END_SERVICE_IP = "10.42.1.235"

az network firewall nat-rule create `
  --resource-group $RG_NETWORK `
  --firewall-name $AZFW_NAME `
  --collection-name NatRC-Http `
  --name 'To-aks-store' `
  --destination-addresses $AZFW_PUBLIC_IP `
  --destination-ports $AKS_STORE_PUBLIC_PORT `
  --protocols Any `
  --source-addresses $MY_PUBLIC_IP `
  --translated-port 80 `
  --translated-address $STORE_FRONT_END_SERVICE_IP
  --action Dnat `
  --priority 100
```

## Deploy a Private Ingress Controller

```pwsh
# Create Firewall rule to access nginx images
az network firewall application-rule create `
  --resource-group $RG_NETWORK `
  --firewall-name $AZFW_NAME `
  --collection-name 'AppRC-nginx-fw' `
  --name 'AppR-k8s-cr' `
  --source-addresses $AKS_SUBNET_CIDR `
  --protocols 'https=443' `
  --target-fqdns registry.k8s.io us-east4-docker.pkg.dev prod-registry-k8s-io-us-east-1.s3.dualstack.us-east-1.amazonaws.com `
  --action allow `
  --priority 120


helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Create namespace
$INT_ING_NS = "int-ingr"
kubectl create namespace $INT_ING_NS

# Deploy ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx `
  --namespace $INT_ING_NS `
  --values ./aks-sampleapp-helm-internal-ing-values.yaml

# Create Azure Firewall NAT rule
$INT_ING_SERVICE_IP = $(kubectl get svc "$INT_ING_NS-ingress-nginx-controller" -o jsonpath='{.status.loadBalancer.ingress[*].ip}' -n $INT_ING_NS)
# $INT_ING_SERVICE_IP = "10.42.1.236"

az network firewall nat-rule create `
  --firewall-name $AZFW_NAME `
  --resource-group $RG_NETWORK `
  --collection-name NatRC-Http `
  --name 'To-internal-ingr-ctrl' `
  --destination-addresses $AZFW_PUBLIC_IP `
  --destination-ports $AKS_ING_PUBLIC_PORT `
  --protocols Any `
  --source-addresses $MY_PUBLIC_IP `
  --translated-port 80 `
  --translated-address $INT_ING_SERVICE_IP
  # --action Dnat `
  # --priority 100 `


# Expose AKS store through the Ingress Controller
kubectl apply -f aks-sampleapp-aks-store-ingress.yaml -n aks-store





# resource "helm_release" "private_ingress_controller_release" {
#   depends_on = [
#     kubernetes_namespace.ing_ns,
#   ]

#   namespace = kubernetes_namespace.ing_ns.metadata[0].name
#   name      = "private-ingress-nginx"

#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"

#   # Additional settings
#   cleanup_on_fail = true # default= false

#   set {
#     name  = "controller.extraArgs.default-ssl-certificate"
#     value = "ingress-basic/default-ingress-tls"
#   }
#   set {
#     name  = "controller.replicaCount"
#     value = "2"
#   }
#   set {
#     name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
#     value = "/healthz"
#   }
#   set {
#     name  = "controller.ingressClassResource.name"
#     value = "nginx-internal"
#   }
#   set {
#     name  = "controller.ingressClassResource.default"
#     value = "true"
#   }
#   set {
#     name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
#     value = "true"
#   }
#   set {
#     name  = "controller.service.loadBalancerIP"
#     value = var.private_ingress_load_balancer_ip
#   }
# }
```

## References

[Kubernetes on Azure tutorial - Prepare an application for Azure Kubernetes Service (AKS) - Azure Kubernetes Service | Microsoft Learn](https://learn.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-app?tabs=azure-cli)

[Azure-Samples/aks-store-demo](https://github.com/Azure-Samples/aks-store-demo)
