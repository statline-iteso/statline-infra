# plataforma: the namespaces of the cluster, the platform charts (SL-12) and External Secrets
# (D-38), and the Job that creates the application databases. Redis is not a chart here: it is our
# own StatefulSet in the GitOps chart (DECISIONS D-20). ClusterIssuers and the ClusterSecretStore
# are not here either: they live in gitops/plataforma and Argo CD applies them (DECISIONS D-22).

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
    eip_allocation_id = var.ingress_eip_allocation_id
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

# Syncs SSM parameters into Kubernetes Secrets (ExternalSecret in the GitOps chart). It authenticates
# with the node's LabRole through IMDS: no IRSA in the lab (D-38). Needs the ServiceMonitor CRD.
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_external_secrets
  namespace  = kubernetes_namespace.ambiente["plataforma"].metadata[0].name

  values = [templatefile("${path.module}/valores/external-secrets.yaml", {})]

  depends_on = [helm_release.kube_prometheus_stack]
}

# RDS only creates the server: this Job creates statline_<env> when missing (idempotent). It runs
# in plataforma, which has no NetworkPolicies, and reaches RDS through the cluster security group.
# The name carries a hash of the endpoint, so a new server gets a new Job.
resource "kubernetes_secret_v1" "db_admin" {
  metadata {
    name      = "statline-db-admin"
    namespace = kubernetes_namespace.ambiente["plataforma"].metadata[0].name
  }
  data = {
    ADMIN_URL = var.db_admin_url
  }
}

resource "kubernetes_job_v1" "crear_bases" {
  metadata {
    name      = "crear-bases-${substr(sha1(var.db_address), 0, 8)}"
    namespace = kubernetes_namespace.ambiente["plataforma"].metadata[0].name
  }

  spec {
    backoff_limit = 6
    template {
      metadata {
        labels = { "app.kubernetes.io/name" = "crear-bases" }
      }
      spec {
        restart_policy                  = "OnFailure"
        automount_service_account_token = false
        security_context {
          run_as_non_root = true
          run_as_user     = 70 # postgres user of the alpine image
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }
        container {
          name    = "psql"
          image   = "postgres:16-alpine"
          command = ["sh", "-ec"]
          args = [<<-SH
            for db in ${join(" ", var.bases_de_datos)}; do
              if psql "$ADMIN_URL" -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
                echo "$db exists"
              else
                psql "$ADMIN_URL" -c "CREATE DATABASE $db" && echo "$db created"
              fi
            done
          SH
          ]
          env_from {
            secret_ref {
              name = kubernetes_secret_v1.db_admin.metadata[0].name
            }
          }
          resources {
            requests = { cpu = "10m", memory = "32Mi" }
            limits   = { memory = "64Mi" }
          }
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "10m"
  }
}
