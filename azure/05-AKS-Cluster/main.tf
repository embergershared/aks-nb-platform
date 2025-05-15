module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"

  suffix = ["lz"]
}

module "avm-res-managedidentity-userassignedidentity" {
  source           = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version          = "0.3.3"
  enable_telemetry = false

  name                = module.naming.user_assigned_identity.name_unique
  location            = var.location # data.azurerm_resource_group.rg.location
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name

  tags = merge(var.base_tags, var.plan_tags)
}

resource "azurerm_role_assignment" "role-assignment-dnszone" {
  scope                            = local.dnszoneAksId # data.azurerm_private_dns_zone.dnszone-aks.id
  role_definition_name             = "Private DNS Zone Contributor"
  principal_id                     = module.avm-res-managedidentity-userassignedidentity.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "role-assignment-vnetcontrib" {
  scope                            = local.vnetLzId # data.azurerm_virtual_network.vnet-lz.id
  role_definition_name             = "Network Contributor"
  principal_id                     = module.avm-res-managedidentity-userassignedidentity.principal_id
  skip_service_principal_aad_check = true
}

module "avm-res-operationalinsights-workspace" {
  source           = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version          = "0.4.1"
  enable_telemetry = false

  name                                      = module.naming.log_analytics_workspace.name_unique
  resource_group_name                       = var.rgLzName # data.azurerm_resource_group.rg.name
  location                                  = var.location # data.azurerm_resource_group.rg.location
  log_analytics_workspace_retention_in_days = 30
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_identity = {
    type = "SystemAssigned"
  }

  tags = merge(var.base_tags, var.plan_tags)
}

resource "azurerm_kubernetes_cluster" "aks-cluster" {
  name                = module.naming.kubernetes_cluster.name_unique
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name
  location            = var.location # data.azurerm_resource_group.rg.location

  node_resource_group        = "${var.rgLzName}-aks-managed"
  dns_prefix_private_cluster = module.naming.kubernetes_cluster.name_unique
  private_cluster_enabled    = true
  private_dns_zone_id        = local.dnszoneAksId # data.azurerm_private_dns_zone.dnszone-aks.id
  azure_policy_enabled       = true
  kubernetes_version         = var.aks_k8s_version
  sku_tier                   = "Standard"

  local_account_disabled            = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  automatic_channel_upgrade         = "patch"

  http_application_routing_enabled = false
  # web_app_routing {
  #   dns_zone_ids = [local.dnszoneContosoId] # data.azurerm_private_dns_zone.dnszone-contoso.id]
  # }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.adminGroupObjectIds]
  }

  default_node_pool {
    name    = "system"
    vm_size = "Standard_DS2_v2"
    # os_disk_size_gb              = 30
    os_sku              = "Ubuntu"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 3

    max_pods                     = 110
    only_critical_addons_enabled = true
    vnet_subnet_id               = local.snetAksId
    orchestrator_version         = var.aks_np_system_version

    zones = ["1", "3"] # zones = ["1", "2", "3"]
  }
  auto_scaler_profile {
    balance_similar_node_groups = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      module.avm-res-managedidentity-userassignedidentity.resource.id,
    ]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    outbound_type       = "userDefinedRouting"
  }
  oms_agent {
    log_analytics_workspace_id      = module.avm-res-operationalinsights-workspace.resource.id
    msi_auth_for_monitoring_enabled = true
  }

  monitor_metrics {
    annotations_allowed = var.metric_annotations_allowlist
    labels_allowed      = var.metric_labels_allowlist
  }

  depends_on = [
    azurerm_role_assignment.role-assignment-dnszone,
  ]

  lifecycle {
    ignore_changes = [default_node_pool.0.upgrade_settings]
  }

  tags = merge(var.base_tags, var.plan_tags)
}

resource "azurerm_kubernetes_cluster_node_pool" "nodepool" {
  name                  = "ubu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks-cluster.id
  orchestrator_version  = var.aks_np_windows_version
  vm_size               = "Standard_DS2_v2"
  # os_disk_size_gb       = 30
  os_type             = "Linux"
  os_sku              = "Ubuntu"
  min_count           = 2
  max_count           = 3
  enable_auto_scaling = true
  max_pods            = 250
  mode                = "User"
  vnet_subnet_id      = local.snetAksId
  zones               = ["1", "3"] # zones = ["1", "2", "3"]

  tags = merge(var.base_tags, var.plan_tags)
}

resource "azurerm_kubernetes_cluster_node_pool" "win_nodepool" {
  name                  = "win"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks-cluster.id
  vm_size               = "Standard_DS2_v2"
  #os_disk_size_gb       = 30
  os_type             = "Windows"
  os_sku              = "Windows2022"
  min_count           = 1
  max_count           = 3
  enable_auto_scaling = true
  max_pods            = 250
  mode                = "User"
  vnet_subnet_id      = local.snetAksId
  zones               = ["1", "3"] # zones = ["1", "2", "3"]

  tags = merge(var.base_tags, var.plan_tags)
}

resource "azurerm_role_assignment" "role-assignment-acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks-cluster.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = local.acrId
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "role-assignment-akv" {
  principal_id                     = azurerm_kubernetes_cluster.aks-cluster.key_vault_secrets_provider[0].secret_identity[0].object_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = local.akvId
  skip_service_principal_aad_check = true
}

# resource "azurerm_role_assignment" "role-assignment-private-dns" {
#   principal_id                     = azurerm_kubernetes_cluster.aks-cluster.web_app_routing[0].web_app_routing_identity[0].object_id
#   role_definition_name             = "Private DNS Zone Contributor"
#   scope                            = local.dnszoneContosoId
#   skip_service_principal_aad_check = true
# }

resource "azurerm_monitor_diagnostic_setting" "diagnostic-aks" {
  name                       = module.naming.monitor_diagnostic_setting.name_unique
  target_resource_id         = azurerm_kubernetes_cluster.aks-cluster.id
  log_analytics_workspace_id = module.avm-res-operationalinsights-workspace.resource.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  enabled_log {
    category = "guard"
  }

  enabled_log {
    category = "csi-azuredisk-controller"
  }

  enabled_log {
    category = "csi-azurefile-controller"
  }

  enabled_log {
    category = "csi-snapshot-controller"
  }

  metric {
    category = "AllMetrics"
  }
}

############   Managed Prometheus & Grafana rules  ############

resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "mgd-prometheus-data-coll-endpoint"
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name
  location            = var.location # data.azurerm_resource_group.rg.location
  kind                = "Linux"
}

# # Logic to determine region mismatch
# locals {
#   dce_region_mismatch = var.cluster_region != var.amw_region
# }

# # Create another DCE if the regions don't match and is_private_cluster is true
# resource "azurerm_monitor_data_collection_endpoint" "dce_mismatch" {
#   count               = (local.dce_region_mismatch && var.is_private_cluster) ? 1 : 0
#   name                = substr("MSProm-PL-${azurerm_resource_group.rg.location}-${azurerm_kubernetes_cluster.aks-cluster.name}", 0, min(44, length("MSProm-PL-${azurerm_resource_group.rg.location}-${azurerm_kubernetes_cluster.aks-cluster.name}")))
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = var.cluster_region
#   kind                = "Linux"
# }

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = "mgd-prometheus-data-coll-rule"
  resource_group_name         = var.rgLzName # data.azurerm_resource_group.rg.name
  location                    = var.location # data.azurerm_resource_group.rg.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"

  destinations {
    monitor_account {
      monitor_account_id = data.azurerm_monitor_workspace.amw.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  description = "DCR for Azure Monitor Metrics Profile (Managed Prometheus)"
  depends_on = [
    azurerm_monitor_data_collection_endpoint.dce
  ]
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "mgd-prometheus-data-coll-rule-assoc-aks"
  target_resource_id      = azurerm_kubernetes_cluster.aks-cluster.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description             = "Association of data collection rule. Deleting this association will break the data collection for the AKS Cluster."
  depends_on = [
    azurerm_monitor_data_collection_rule.dcr
  ]
}

# resource "azurerm_monitor_data_collection_rule_association" "dcra_mismatch" {
#   count                       = (local.dce_region_mismatch && var.is_private_cluster) ? 1 : 0
#   target_resource_id          = azurerm_kubernetes_cluster.k8s.id
#   data_collection_endpoint_id = local.dce_region_mismatch ? azurerm_monitor_data_collection_endpoint.dce_mismatch[0].id : azurerm_monitor_data_collection_endpoint.dce.id
#   description                 = "Association of data collection endpoint for private link clusters. Deleting this association will break the data collection for this AKS Cluster."
#   depends_on = [
#     azurerm_monitor_data_collection_endpoint.dce
#   ]
# }

resource "azurerm_monitor_alert_prometheus_rule_group" "node_recording_rules_rule_group" {
  name                = "${azurerm_kubernetes_cluster.aks-cluster.name}-mgd-prometheus-NodeRecordingRulesRuleGroup"
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name
  location            = var.location # data.azurerm_resource_group.rg.location
  cluster_name        = azurerm_kubernetes_cluster.aks-cluster.name
  description         = "Node Recording Rules Rule Group"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes = [
    data.azurerm_monitor_workspace.amw.id,
    azurerm_kubernetes_cluster.aks-cluster.id
  ]

  rule {
    enabled    = true
    record     = "instance:node_num_cpu:sum"
    expression = <<EOF
count without (cpu, mode) (  node_cpu_seconds_total{job="node",mode="idle"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_cpu_utilisation:rate5m"
    expression = <<EOF
1 - avg without (cpu) (  sum without (mode) (rate(node_cpu_seconds_total{job="node", mode=~"idle|iowait|steal"}[5m])))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_load1_per_cpu:ratio"
    expression = <<EOF
(  node_load1{job="node"}/  instance:node_num_cpu:sum{job="node"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_memory_utilisation:ratio"
    expression = <<EOF
1 - (  (    node_memory_MemAvailable_bytes{job="node"}    or    (      node_memory_Buffers_bytes{job="node"}      +      node_memory_Cached_bytes{job="node"}      +      node_memory_MemFree_bytes{job="node"}      +      node_memory_Slab_bytes{job="node"}    )  )/  node_memory_MemTotal_bytes{job="node"})
EOF
  }
  rule {
    enabled = true

    record     = "instance:node_vmstat_pgmajfault:rate5m"
    expression = <<EOF
rate(node_vmstat_pgmajfault{job="node"}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_seconds:rate5m"
    expression = <<EOF
rate(node_disk_io_time_seconds_total{job="node", device!=""}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_weighted_seconds:rate5m"
    expression = <<EOF
rate(node_disk_io_time_weighted_seconds_total{job="node", device!=""}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_receive_bytes_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_receive_bytes_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_transmit_bytes_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_transmit_bytes_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_receive_drop_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_receive_drop_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_transmit_drop_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_transmit_drop_total{job="node", device!="lo"}[5m]))
EOF
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "kubernetes_recording_rules_rule_group" {
  name                = "${azurerm_kubernetes_cluster.aks-cluster.name}-mgd-prometheus-KubernetesRecordingRulesRuleGroup"
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name
  location            = var.location # data.azurerm_resource_group.rg.location
  cluster_name        = azurerm_kubernetes_cluster.aks-cluster.name
  description         = "Kubernetes Recording Rules Rule Group"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes = [
    data.azurerm_monitor_workspace.amw.id,
    azurerm_kubernetes_cluster.aks-cluster.id
  ]

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate"
    expression = <<EOF
sum by (cluster, namespace, pod, container) (  irate(container_cpu_usage_seconds_total{job="cadvisor", image!=""}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (  1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_working_set_bytes"
    expression = <<EOF
container_memory_working_set_bytes{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_rss"
    expression = <<EOF
container_memory_rss{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_cache"
    expression = <<EOF
container_memory_cache{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_swap"
    expression = <<EOF
container_memory_swap{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_requests"
    expression = <<EOF
kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_requests:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests"
    expression = <<EOF
kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_requests:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_limits"
    expression = <<EOF
kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_limits:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits"
    expression = <<EOF
kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~"Pending|Running"} == 1) )
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_limits:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    label_replace(      kube_pod_owner{job="kube-state-metrics", owner_kind="ReplicaSet"},      "replicaset", "$1", "owner_name", "(.*)"    ) * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (      1, max by (replicaset, namespace, owner_name) (        kube_replicaset_owner{job="kube-state-metrics"}      )    ),    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "deployment"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="DaemonSet"},    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "daemonset"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="StatefulSet"},    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "statefulset"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="Job"},    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "job"
    }
  }
  rule {
    enabled    = true
    record     = ":node_memory_MemAvailable_bytes:sum"
    expression = <<EOF
sum(  node_memory_MemAvailable_bytes{job="node"} or  (    node_memory_Buffers_bytes{job="node"} +    node_memory_Cached_bytes{job="node"} +    node_memory_MemFree_bytes{job="node"} +    node_memory_Slab_bytes{job="node"}  )) by (cluster)
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:node_cpu:ratio_rate5m"
    expression = <<EOF
sum(rate(node_cpu_seconds_total{job="node",mode!="idle",mode!="iowait",mode!="steal"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job="node"}) by (cluster, instance, cpu)) by (cluster)
EOF
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "node_and_kubernetes_recording_rules_rule_group_win" {
  name                = "${azurerm_kubernetes_cluster.aks-cluster.name}-mgd-prometheus-NodeAndKubernetesRecordingRulesRuleGroup-Win"
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name
  location            = var.location # data.azurerm_resource_group.rg.location
  cluster_name        = azurerm_kubernetes_cluster.aks-cluster.name
  description         = "Node and Kubernetes Recording Rules Rule Group for Windows Nodes"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes = [
    data.azurerm_monitor_workspace.amw.id,
    azurerm_kubernetes_cluster.aks-cluster.id
  ]

  rule {
    enabled    = true
    record     = "node:windows_node_filesystem_usage:"
    expression = <<EOF
max by (instance,volume)((windows_logical_disk_size_bytes{job="windows-exporter"} - windows_logical_disk_free_bytes{job="windows-exporter"}) / windows_logical_disk_size_bytes{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_filesystem_avail:"
    expression = <<EOF
max by (instance, volume) (windows_logical_disk_free_bytes{job="windows-exporter"} / windows_logical_disk_size_bytes{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = ":windows_node_net_utilisation:sum_irate"
    expression = <<EOF
sum(irate(windows_net_bytes_total{job="windows-exporter"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_net_utilisation:sum_irate"
    expression = <<EOF
sum by (instance) ((irate(windows_net_bytes_total{job="windows-exporter"}[5m])))
EOF
  }
  rule {
    enabled    = true
    record     = ":windows_node_net_saturation:sum_irate"
    expression = <<EOF
sum(irate(windows_net_packets_received_discarded_total{job="windows-exporter"}[5m])) + sum(irate(windows_net_packets_outbound_discarded_total{job="windows-exporter"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_net_saturation:sum_irate"
    expression = <<EOF
sum by (instance) ((irate(windows_net_packets_received_discarded_total{job="windows-exporter"}[5m]) + irate(windows_net_packets_outbound_discarded_total{job="windows-exporter"}[5m])))
EOF
  }
  rule {
    enabled    = true
    record     = "windows_pod_container_available"
    expression = <<EOF
windows_container_available{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)
EOF
  }
  rule {
    enabled    = true
    record     = "windows_container_total_runtime"
    expression = <<EOF
windows_container_cpu_usage_seconds_total{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)
EOF
  }
  rule {
    enabled    = true
    record     = "windows_container_memory_usage"
    expression = <<EOF
windows_container_memory_usage_commit_bytes{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)
EOF
  }
  rule {
    enabled    = true
    record     = "windows_container_private_working_set_usage"
    expression = <<EOF
windows_container_memory_usage_private_working_set_bytes{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)
EOF
  }
  rule {
    enabled    = true
    record     = "windows_container_network_received_bytes_total"
    expression = <<EOF
windows_container_network_receive_bytes_total{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)
EOF
  }
  rule {
    enabled    = true
    record     = "windows_container_network_transmitted_bytes_total"
    expression = <<EOF
windows_container_network_transmit_bytes_total{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)
EOF
  }
  rule {
    enabled    = true
    record     = "kube_pod_windows_container_resource_memory_request"
    expression = <<EOF
max by (namespace, pod, container) (kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}) * on(container,pod,namespace) (windows_pod_container_available)
EOF
  }
  rule {
    enabled    = true
    record     = "kube_pod_windows_container_resource_memory_limit"
    expression = <<EOF
kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"} * on(container,pod,namespace) (windows_pod_container_available)
EOF
  }
  rule {
    enabled    = true
    record     = "kube_pod_windows_container_resource_cpu_cores_request"
    expression = <<EOF
max by (namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}) * on(container,pod,namespace) (windows_pod_container_available)
EOF
  }
  rule {
    enabled    = true
    record     = "kube_pod_windows_container_resource_cpu_cores_limit"
    expression = <<EOF
kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"} * on(container,pod,namespace) (windows_pod_container_available)
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_pod_container:windows_container_cpu_usage_seconds_total:sum_rate"
    expression = <<EOF
sum by (namespace, pod, container) (rate(windows_container_total_runtime{}[5m]))
EOF
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "node_recording_rules_rule_group_win" {
  name                = "${azurerm_kubernetes_cluster.aks-cluster.name}-mgd-prometheus-NodeRecordingRulesRuleGroup-Win"
  resource_group_name = var.rgLzName # data.azurerm_resource_group.rg.name
  location            = var.location # data.azurerm_resource_group.rg.location
  cluster_name        = azurerm_kubernetes_cluster.aks-cluster.name
  description         = "Node and Kubernetes Recording Rules Rule Group for Windows Nodes"

  rule_group_enabled = true
  interval           = "PT1M"
  scopes = [
    data.azurerm_monitor_workspace.amw.id,
    azurerm_kubernetes_cluster.aks-cluster.id
  ]

  rule {
    enabled    = true
    record     = "node:windows_node:sum"
    expression = <<EOF
count (windows_system_boot_time_timestamp_seconds{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_num_cpu:sum"
    expression = <<EOF
count by (instance) (sum by (instance, core) (windows_cpu_time_total{job="windows-exporter"}))
EOF
  }
  rule {
    enabled    = true
    record     = ":windows_node_cpu_utilisation:avg5m"
    expression = <<EOF
1 - avg(rate(windows_cpu_time_total{job="windows-exporter",mode="idle"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_cpu_utilisation:avg5m"
    expression = <<EOF
1 - avg by (instance) (rate(windows_cpu_time_total{job="windows-exporter",mode="idle"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = ":windows_node_memory_utilisation:"
    expression = <<EOF
1 -sum(windows_memory_available_bytes{job="windows-exporter"})/sum(windows_os_visible_memory_bytes{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = ":windows_node_memory_MemFreeCached_bytes:sum"
    expression = <<EOF
sum(windows_memory_available_bytes{job="windows-exporter"} + windows_memory_cache_bytes{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_memory_totalCached_bytes:sum"
    expression = <<EOF
(windows_memory_cache_bytes{job="windows-exporter"} + windows_memory_modified_page_list_bytes{job="windows-exporter"} + windows_memory_standby_cache_core_bytes{job="windows-exporter"} + windows_memory_standby_cache_normal_priority_bytes{job="windows-exporter"} + windows_memory_standby_cache_reserve_bytes{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = ":windows_node_memory_MemTotal_bytes:sum"
    expression = <<EOF
sum(windows_os_visible_memory_bytes{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_memory_bytes_available:sum"
    expression = <<EOF
sum by (instance) ((windows_memory_available_bytes{job="windows-exporter"}))
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_memory_bytes_total:sum"
    expression = <<EOF
sum by (instance) (windows_os_visible_memory_bytes{job="windows-exporter"})
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_memory_utilisation:ratio"
    expression = <<EOF
(node:windows_node_memory_bytes_total:sum - node:windows_node_memory_bytes_available:sum) / scalar(sum(node:windows_node_memory_bytes_total:sum))
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_memory_utilisation:"
    expression = <<EOF
1 - (node:windows_node_memory_bytes_available:sum / node:windows_node_memory_bytes_total:sum)
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_memory_swap_io_pages:irate"
    expression = <<EOF
irate(windows_memory_swap_page_operations_total{job="windows-exporter"}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = ":windows_node_disk_utilisation:avg_irate"
    expression = <<EOF
avg(irate(windows_logical_disk_read_seconds_total{job="windows-exporter"}[5m]) + irate(windows_logical_disk_write_seconds_total{job="windows-exporter"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "node:windows_node_disk_utilisation:avg_irate"
    expression = <<EOF
avg by (instance) ((irate(windows_logical_disk_read_seconds_total{job="windows-exporter"}[5m]) + irate(windows_logical_disk_write_seconds_total{job="windows-exporter"}[5m])))
EOF
  }
}
#*/
