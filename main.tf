################################################################################
# Cluster
################################################################################

resource "aws_eks_cluster" "cluster" {
  name = format("%s-API-Cluster", var.name)
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.cluster-version
  enabled_cluster_log_types = var.cluster-log-types

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    security_group_ids = [
      aws_security_group.cluster.id
    ]

    # subnet_ids              = module.vpc.aws-private-subnets[*]["id"]
    subnet_ids = data.aws_subnets.public.ids

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = false
    }
  }

  compute_config {
    enabled = false
    # node_pools = [
    #   "general-purpose",
    #   "system"
    # ]
    # node_role_arn = aws_iam_role.node.arn
  }

  storage_config {
    block_storage {
      enabled = false
    }
  }

  bootstrap_self_managed_addons = true

  timeouts {
    create = lookup(var.cluster-timeouts, "create", null)
    update = lookup(var.cluster-timeouts, "update", null)
    delete = lookup(var.cluster-timeouts, "delete", null)
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-eks-policy-attachment,
    aws_iam_role_policy_attachment.cluster-compute-policy-attachment,
    aws_iam_role_policy_attachment.cluster-block-storage-policy-attachment,
    aws_iam_role_policy_attachment.cluster-load-balancing-policy-attachment,
    aws_iam_role_policy_attachment.cluster-networking-policy-attachment,

    aws_security_group_rule.cluster-group-rule-outbound,
    aws_security_group_rule.cluster-group-rule,
  ]

  lifecycle {
    ignore_changes = [
      vpc_config
    ]
  }

  tags = merge({
    Name = format("%s-Cluster", var.name)
  }, {})
}

resource "aws_eks_addon" "addon" {
  for_each = data.aws_eks_addon_version.addon

  addon_name    = each.value.addon_name
  cluster_name  = aws_eks_cluster.cluster.name
  addon_version = each.value.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]

  tags = merge({
    Name = format("%s", each.value.addon_name)
    Version = format("%s", each.value.version)
    K8s-Version = format("%s", each.value.kubernetes_version)
  }, {})
}

################################################################################
# Cluster Security Group
# Defaults follow https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
################################################################################

resource "aws_security_group" "cluster" {
  name_prefix = format("%s-Cluster-SG-", var.name)
  vpc_id = data.aws_vpc.vpc.id # module.vpc.aws-vpc-id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({
    Name = format("%s-Cluster-SG", var.name)
  }, {})
}

resource "aws_security_group_rule" "cluster-group-rule" {
  security_group_id = aws_security_group.cluster.id

  description = "Node Groups to Cluster API"
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  type        = "ingress"

  self = true
}

resource "aws_security_group_rule" "cluster-group-rule-outbound" {
  security_group_id = aws_security_group.cluster.id

  description = "Cluster API Outbound Access"
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  type        = "egress"

  cidr_blocks = ["0.0.0.0/0"]
}

# resource "aws_security_group_rule" "cluster-bastion-rule" {
#     security_group_id = aws_security_group.cluster.id
#
#     description = "Bastion to Cluster API"
#     protocol    = "tcp"
#     from_port   = 443
#     to_port     = 443
#     type        = "ingress"
#
#     source_security_group_id = module.bastion.bastion-security-group-id
# }
#
# resource "aws_security_group_rule" "cluster-bastion-rule" {
#    security_group_id = aws_security_group.cluster.id
#
#    description                = "Node Groups to Cluster API"
#    protocol                   = "tcp"
#    from_port                  = 443
#    to_port                    = 443
#    type                       = "ingress"
#
#    self = true
# }

################################################################################
# Node Security Group
# Defaults follow https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
# Plus NTP/HTTPS (otherwise nodes fail to launch)
################################################################################

locals {
  node-security-group-rules = {
    ingress-cluster-control-plane-443 = {
      description = "Cluster API (Control Plane) to Node Groups"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      source      = true
    }

    ingress-cluster-kubelet = {
      description = "Cluster API (Control Plane) to Node Kubelet(s)"
      protocol    = "tcp"
      from_port   = 10250
      to_port     = 10250
      type        = "ingress"
      source      = true
    }

    ingress-self-coredns-tcp = {
      description = "Node to Node CoreDNS, TCP"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    }

    ingress-self-coredns-udp = {
      description = "Node to Node CoreDNS, UDP"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    }
  }

  recommended-node-security-group-rules = {
    ingress-self-ephemeral-ports = {
      description = "Node to Node Ingress on Ephemeral Ports"
      protocol    = "tcp"
      from_port   = 1025
      to_port     = 65535
      type        = "ingress"
      self        = true
    }

    # metrics-server
    ingress-cluster-control-plane-webhook = {
      description = "Cluster API to Node 4443/tcp Webhook"
      protocol    = "tcp"
      from_port   = 4443
      to_port     = 4443
      type        = "ingress"
      source      = true
    }

    # istio
    istio-cluster = {
      description = "Cluster API to Node 15017/tcp"
      protocol    = "tcp"
      from_port   = 15017
      to_port     = 15017
      type        = "ingress"
      source      = true
    }

    # prometheus-adapter
    ingress-cluster-prometheus-webhook = {
      description = "Cluster API to node 6443/tcp webhook"
      protocol    = "tcp"
      from_port   = 6443
      to_port     = 6443
      type        = "ingress"
      source      = true
    }

    # ALB controller
    ingress-cluster-9443-webhook = {
      description = "Cluster API to node 9443/tcp webhook"
      protocol    = "tcp"
      from_port   = 9443
      to_port     = 9443
      type        = "ingress"
      source      = true
    }

    egress-all = {
      description = "Allow all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }

    lattice = {
      description = "Allow VPC Lattice Prefix List"
      protocol = "-1"
      type = "ingress"
      from_port   = 0
      to_port     = 0
      prefix_list_ids = [
        data.aws_ec2_managed_prefix_list.prefix-list.id
      ]
    }
  }
}

resource "aws_security_group" "node" {
  name_prefix = format("%s-Node-SG-", var.name)
  vpc_id = data.aws_vpc.vpc.id # module.vpc.aws-vpc-id

  tags = merge({
    Name = format("%s-Node-SG", var.name)
  }, {})
}

resource "aws_security_group_rule" "node-rule" {
  for_each = {
    for k, v in merge(
      local.node-security-group-rules,
      local.recommended-node-security-group-rules,
    ) : k => v
  }

  # Required
  security_group_id = aws_security_group.node.id
  protocol          = lookup(each.value, "protocol", null)
  from_port         = lookup(each.value, "from_port", null)
  to_port           = lookup(each.value, "to_port", null)
  type = each.value.type

  # Optional
  description = lookup(each.value, "description", null)
  cidr_blocks = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks = lookup(each.value, "ipv6_cidr_blocks", null)
  prefix_list_ids = lookup(each.value, "prefix_list_ids", [])
  self = lookup(each.value, "self", null)

  source_security_group_id = try(each.value.source, false) ? aws_security_group.cluster.id : lookup(each.value, "source_security_group_id", null)
}


################################################################################
# IAM Role
################################################################################

resource "aws_iam_role" "cluster" {
  name_prefix = format("%s-Cluster-IAM-Role-", var.name)
  path = "/"

  description = "Cluster IAM Role"

  // assume_role_policy    = data.aws_iam_policy_document.cluster-eks-cluster-assume-role-policy.json
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  force_detach_policies = true

  tags = merge({
    Name = format("%s-IAM-Role", var.name)
  }, {})
}

# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/920
# Resources running on the cluster are still generating logs when destroying the module resources
# which results in the log group being re-created even after Terraform destroys it. Removing the
# ability for the cluster role to create the log group prevents this log group from being re-created
# outside of Terraform due to services still generating logs during destroy process
resource "aws_iam_policy" "cluster-iam-role-create-log-group-policy" {
  name_prefix = format("%s-IAM-Role-", var.name)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["logs:CreateLogGroup"]
        Effect   = "Deny"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster-iam-role-create-log-group-policy-attachment" {
  policy_arn = aws_iam_policy.cluster-iam-role-create-log-group-policy.arn
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-eks-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-compute-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-block-storage-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-load-balancing-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-networking-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.cluster.name
}

# Policies attached ref https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
# resource "aws_iam_role_policy_attachment" "cluster-iam-policy-attachment" {
#   for_each = {
#     for k, v in {
#       eks-cluster-policy                = "${local.cluster-iam-policy-prefix}/AmazonEKSClusterPolicy",
#       eks-vpc-resource-controller       = "${local.cluster-iam-policy-prefix}/AmazonEKSVPCResourceController",
#       eks-worker-node-minimal-policy    = "${local.cluster-iam-policy-prefix}/AmazonEKSWorkerNodeMinimalPolicy",
#       eks-registry-pull-only-poliy      = "${local.cluster-iam-policy-prefix}/AmazonEC2ContainerRegistryPullOnly",
#       eks-cluster-compute-policy        = "${local.cluster-iam-policy-prefix}/AmazonEKSComputePolicy",
#       eks-cluster-block-storage-policy  = "${local.cluster-iam-policy-prefix}/AmazonEKSBlockStoragePolicy"
#       eks-cluster-load-balancing-policy = "${local.cluster-iam-policy-prefix}/AmazonEKSLoadBalancingPolicy"
#       eks-cluster-networking-policy     = "${local.cluster-iam-policy-prefix}/AmazonEKSNetworkingPolicy"
#     } : k => v
#   }
#
#   policy_arn = each.value
#   role       = aws_iam_role.cluster-iam-role.name
# }

# Node Group

# role - https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html
resource "aws_iam_role" "node" {
  name_prefix = format("%s-Node-Group-IAM-Role-", var.name)
  description        = "Node-Group IAM Role"
  assume_role_policy = data.aws_iam_policy_document.cluster-eks-node-group-assume-role-policy.json

  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "node-iam-role-attachment-minimal" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-iam-role-attachment-ec2-container-pull-only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.node.name
}

# resource "aws_iam_role" "node-group-role" {
#   name = format("%s-Node-Group-IAM-Role", var.name)
#   description = "Node-Group IAM Role"
#
#   // path = format("/%s/", join("/", [
#   //     module.parameter.namespace,
#   //     module.parameter.environment,
#   // ]))
#
#   force_detach_policies = true
#
#   assume_role_policy = data.aws_iam_policy_document.cluster-eks-node-group-assume-role-policy.json
#
#   // depends_on = module.vpc[0].aws-ssm-vpc-endpoint
#
#   tags = merge({
#     Name = format("%s-Node-Group-IAM-Role", var.name)
#   }, {})
# }

resource "aws_iam_policy" "node-aws-load-balancer-controller-policy" {
  name_prefix = format("%s-Node-Group-LB-Controller-Policy-", var.name)
  policy = local.aws-loadbalancer-controller-iam-policy

  tags = merge({
    Name = format("%s-Node-Group-LB-Controller-Policy", var.name)
  }, {})
}

resource "aws_iam_role_policy_attachment" "node-role-aws-load-balancer-controller-policy" {
  policy_arn = aws_iam_policy.node-aws-load-balancer-controller-policy.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-role-eks-worker-policy" {
  policy_arn = data.aws_iam_policy.node-group-role-eks-worker-policy.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-role-cni-policy" {
  policy_arn = data.aws_iam_policy.node-group-role-cni-policy.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-role-ecr-registry-policy" {
  policy_arn = data.aws_iam_policy.node-group-role-ecr-registry-policy.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-role-ssm-policy" {
  policy_arn = data.aws_iam_policy.node-group-role-ssm-policy.arn
  role       = aws_iam_role.node.name # aws_iam_role.node-group-role.name
}

resource "aws_iam_role_policy_attachment" "node-role-efs-policy" {
  policy_arn = data.aws_iam_policy.node-group-role-efs-policy.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-role-ebs-policy" {
  policy_arn = data.aws_iam_policy.node-group-role-ebs-policy.arn
  role       = aws_iam_role.node.name
}

resource "aws_eks_node_group" "system" {
  cluster_name  = aws_eks_cluster.cluster.name
  node_role_arn = aws_iam_role.node.arn
  subnet_ids = data.aws_subnets.private.ids # module.vpc.aws-private-subnets[*]["id"]

  node_group_name = null
  node_group_name_prefix = lower(format("%s-Node-Group-", var.name))

  capacity_type = "SPOT"

  labels = {
    // https://kubernetes.io/docs/reference/labels-annotations-taints

    // --> non-standard
    "node-group.x-kubernetes.io/control-plane" = "system"
  }

  version  = aws_eks_cluster.cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks-ami-release-version.value)
  // https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html#AmazonEKS-Type-Nodegroup-amiType
  ami_type = "AL2023_ARM_64_STANDARD"
  disk_size = 30

  // https://github.com/aws/amazon-vpc-cni-k8s/blob/release-1.6/pkg/awsutils/vpc_ip_resource_limit.go
  instance_types = [
    "m7g.large"
  ]

  scaling_config {
    desired_size = 4
    max_size     = 15
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  force_update_version = true

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node-role-eks-worker-policy,
    aws_iam_role_policy_attachment.node-role-cni-policy,
    aws_iam_role_policy_attachment.node-role-ecr-registry-policy,
    aws_iam_role_policy_attachment.node-role-ssm-policy,
    aws_iam_role_policy_attachment.node-role-efs-policy,
    aws_iam_role_policy_attachment.node-role-ebs-policy,
  ]

  tags = merge({
    Name = format("%s-Node-Group", var.name)
  }, {})

  lifecycle {
    create_before_destroy = true
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_iam_openid_connect_provider" "provider" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.thumbprint.certificates[0].sha1_fingerprint]
  url = data.tls_certificate.thumbprint.url
}

# resource "aws_eks_identity_provider_config" "identity-provider-configuration" {
#   cluster_name = aws_eks_cluster.cluster.name
#
#   oidc {
#     client_id                     = substr(aws_eks_cluster.cluster.identity[0].oidc[0]["issuer"], -32, -1)
#     identity_provider_config_name = lower(format("%s-identity-provider-configuration", var.name))
#     issuer_url                    = "https://${aws_iam_openid_connect_provider.provider.url}"
#   }
# }

resource "aws_eks_access_entry" "sso-user" {
  cluster_name  = aws_eks_cluster.cluster.name
  principal_arn = data.aws_iam_role.sso.arn
  kubernetes_groups = ["masters"]
}

resource "aws_eks_access_policy_association" "creator" {
  cluster_name  = aws_eks_cluster.cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_iam_session_context.session.issuer_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sso-user]
}

resource "aws_eks_access_policy_association" "sso-user" {
  cluster_name  = aws_eks_cluster.cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_iam_role.sso.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sso-user]
}

resource "aws_iam_role" "aws-node-service-account-role" {
  assume_role_policy = data.aws_iam_policy_document.aws-node-service-account-iam-assume-role-policy.json
  name_prefix = format("%s-EKS-Service-Account-IAM-Role-", var.name)

  tags = merge({
    Name = format("%s-EKS-Service-Account-IAM-Role", var.name)
  }, {})
}

resource "aws_iam_role" "cluster-service-account-role" {
  assume_role_policy = data.aws_iam_policy_document.cluster-service-account-iam-assume-role-policy.json
  name_prefix = format("%s-Cluster-Service-Account-Role-", var.name)

  tags = merge({
    Name = format("%s-Cluster-Service-Account-Role", var.name)
  })
}

resource "aws_iam_policy" "cluster-eks-pod-identity-policy" {
  name_prefix = format("%s-IAM-Pod-Identity-Policy-", var.name)
  description = "AWS IAM Policy for EKS Pod Identity Agent"
  path        = "/"

  policy = data.aws_iam_policy_document.eks-pod-identity-policy.json

  tags = merge({
    Name = format("%s-IAM-Pod-Identity-Policy", var.name)
  }, {})
}

resource "aws_iam_role_policy_attachment" "cluster-eks-pod-identity-policy-attachment" {
  policy_arn = aws_iam_policy.cluster-eks-pod-identity-policy.arn
  role       = aws_iam_role.cluster-service-account-role.name
}

resource "aws_iam_policy" "cluster-service-account-secretsmanager-iam-policy" {
  name_prefix = format("%s-Cluster-Service-Account-SM-IAM-Policy-", var.name)
  description = "AWS SecretsManager IAM Policy"
  path        = "/"

  policy = data.aws_iam_policy_document.cluster-service-account-iam-secretsmanager-policy.json

  tags = merge({
    Name = format("%s-Cluster-Service-Account-SM-IAM-Policy", var.name)
  }, {})
}

resource "aws_iam_role_policy_attachment" "cluster-service-account-secretsmanager-iam-policy-attachment" {
  policy_arn = aws_iam_policy.cluster-service-account-secretsmanager-iam-policy.arn
  role       = aws_iam_role.cluster-service-account-role.name
}

resource kubernetes_service_account "cluster-service-account" {
  metadata {
    name      = "cluster-service-account"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster-service-account-role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-service-account-secretsmanager-iam-policy-attachment,
    aws_iam_role_policy_attachment.cluster-eks-pod-identity-policy-attachment
  ]
}
