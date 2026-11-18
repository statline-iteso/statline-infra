# plataforma: the namespaces of the cluster and the four platform charts (SL-12). Redis is not a
# chart here: it is our own StatefulSet in the GitOps chart (DECISIONS D-20). ClusterIssuers are
# not here either: they live in gitops/ and Argo CD applies them (DECISIONS D-22).

locals {
  ambientes = {
    plataforma       = "plataforma"
    statline-staging = "staging"
    statline-prod    = "prod"
  }
}

resource "kubernetes_namespace" "ambiente" {
  for_each = local.ambientes

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/part-of" = "statline"
      # Selects the namespace in NetworkPolicies (namespaceSelector).
      "statline.io/ambiente" = each.value
    }
  }
}

resource "random_password" "grafana" {
  length           = 24
  special          = true
  override_special = "-_"
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_kube_prometheus_stack
  namespace  = kubernetes_namespace.ambiente["plataforma"].metadata[0].name
  timeout    = 900

  values = [templatefile("${path.module}/valores/kube-prometheus-stack.yaml", {
    grafana_admin_password = random_password.grafana.result
  })]
}

# Needs the ServiceMonitor CRD, which kube-prometheus-stack installs.
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_ingress_nginx
  namespace  = kubernetes_namespace.ambiente["plataforma"].metadata[0].name

  values = [templatefile("${path.module}/valores/ingress-nginx.yaml", {
    nombre_ip     = var.ingress_public_ip_name
    grupo_recurso = var.resource_group_name
  })]

  depends_on = [helm_release.kube_prometheus_stack]
}

# Needs the ServiceMonitor CRD for its metrics too.
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.chart_cert_manager
  namespace  = kubernetes_namespace.ambiente["plataforma"].metadata[0].name

  values = [templatefile("${path.module}/valores/cert-manager.yaml", {})]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_argo_cd
  namespace  = kubernetes_namespace.ambiente["plataforma"].metadata[0].name

  values = [templatefile("${path.module}/valores/argo-cd.yaml", {})]
}
