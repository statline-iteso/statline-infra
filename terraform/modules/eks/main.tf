# eks: the cluster and one managed node group, both on the Learner Lab's pre-created LabRole
# (the lab allows no new IAM roles, OIDC providers or IRSA; D-38). Pods that call AWS (External
# Secrets) use the node's LabRole credentials through IMDS, hence the hop limit of 2.

data "aws_iam_role" "lab" {
  name = "LabRole"
}

resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = data.aws_iam_role.lab.arn
  version  = var.kubernetes_version

  vpc_config {
    # Control-plane ENIs in two AZs (EKS requires it); the nodes only use the public subnet.
    subnet_ids              = concat([var.public_subnet_id], var.private_subnet_ids)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    # Whoever creates the cluster (the lab's voclabs role) is cluster admin; no aws-auth edits.
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Extended support bills USD 0.60/h instead of 0.10/h: never fall into it silently.
  upgrade_policy {
    support_type = "STANDARD"
  }

  # Cheap control-plane categories only; audit is the expensive one (as D-19). Log group and
  # retention come from module observabilidad, created first.
  enabled_cluster_log_types = ["api", "controllerManager", "scheduler"]
}

# Network policies (default-deny in the chart, SL-56) are enforced by the VPC CNI's agent.
# Prefix delegation raises the pod limit of a t3.medium from 17 to 110 (the stack needs ~40).
# Created before the node group (its depends_on), so the nodes start with this configuration;
# with no nodes yet the DaemonSet is trivially ready.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_launch_template" "nodes" {
  name_prefix = "lt-${var.name}-nodes-"

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    # 2 so pods (External Secrets) can reach IMDS through the extra network hop.
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  # AL2023 nodeadm config, merged with the one EKS generates: pin maxPods to the prefix-delegation
  # value instead of relying on the node group's own calculation.
  user_data = base64encode(<<-MIME
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: application/node.eks.aws

    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          maxPods: ${var.max_pods}

    --BOUNDARY--
    MIME
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-node" }
  }
}

# Fixed size: no Cluster Autoscaler (it would need its own IAM role). Scale by hand up to max_size.
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name}-nodes"
  node_role_arn   = data.aws_iam_role.lab.arn
  subnet_ids      = [var.public_subnet_id]
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_count
    min_size     = var.node_count
    max_size     = var.node_max_count
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  depends_on = [aws_eks_addon.vpc_cni, aws_eks_addon.kube_proxy]
}

# CoreDNS needs nodes to schedule on.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
}
