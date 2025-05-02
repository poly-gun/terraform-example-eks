################################################################################
# Data
################################################################################

data "aws_partition" "arn" {}
data "aws_region" "region" {}
data "aws_caller_identity" "caller" {}
data "aws_availability_zones" "available" {}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Primary"
    values = ["True"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Primary"
    values = ["True"]
  }

  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Primary"
    values = ["True"]
  }

  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}

data "aws_ec2_managed_prefix_list" "prefix-list" {
  name = "com.amazonaws.${data.aws_region.region.name}.vpc-lattice"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_eks_cluster_auth" "authentication" {
  name = aws_eks_cluster.cluster.name
}

data "aws_iam_session_context" "session" {
  # This data source provides information on the IAM source role of an STS assumed role
  # For non-role ARNs, this data source simply passes the ARN through issuer ARN
  # Ref https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2327#issuecomment-1355581682
  # Ref https://github.com/hashicorp/terraform-provider-aws/issues/28381
  arn = data.aws_caller_identity.caller.arn
}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-arm64"]
    // values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }
}

data "aws_iam_policy_document" "cluster-eks-cluster-assume-role-policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "cluster-eks-node-group-assume-role-policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_eks_addon_version" "addon" {
  for_each = local.cluster-addons

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.cluster.version
  most_recent        = lookup(each.value, "latest", false)
}

# aws ssm get-parameters-by-path --path /aws/service/eks/
data "aws_ssm_parameter" "eks-ami-release-version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.cluster.version}/amazon-linux-2-arm64/recommended/release_version"
}

// !!! Required
data "aws_iam_policy" "node-group-role-eks-worker-policy" {
  arn = "arn:${data.aws_partition.arn.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

// !!! Required
data "aws_iam_policy" "node-group-role-cni-policy" {
  arn = "arn:${data.aws_partition.arn.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

// !!! Required
data "aws_iam_policy" "node-group-role-ecr-registry-policy" {
  arn = "arn:${data.aws_partition.arn.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

// !!! Optional
data "aws_iam_policy" "node-group-role-ssm-policy" {
  arn = "arn:${data.aws_partition.arn.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// !!! Optional
data "aws_iam_policy" "node-group-role-efs-policy" {
  arn = "arn:${data.aws_partition.arn.partition}:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

// !!! Optional
data "aws_iam_policy" "node-group-role-ebs-policy" {
  arn = "arn:${data.aws_partition.arn.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_role" "sso" {
  name = var.sso-role
}

data "aws_ssoadmin_instances" "sso" {}

data "aws_ssoadmin_permission_set" "sso" {
  instance_arn = tolist(data.aws_ssoadmin_instances.sso.arns)[0]
  name         = "AdministratorAccess"
}


data "tls_certificate" "thumbprint" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0]["issuer"]
}

data "aws_iam_policy_document" "aws-node-service-account-iam-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:aud"
      values   = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:sub"
      values   = [
        "system:serviceaccount:kube-system:aws-node"
      ]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

data "aws_iam_policy_document" "cluster-service-account-iam-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:aud"
      values   = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:sub"
      values   = [
        // "system:serviceaccount:kube-system:${kubernetes_service_account.cluster-service-account.metadata[0].name}", <-- cycle
        "system:serviceaccount:kube-system:cluster-service-account",
      ]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

data "aws_iam_policy_document" "eks-pod-identity-policy" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = [
      "eks-auth:AssumeRoleForPodIdentity",
    ]

    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "cluster-service-account-iam-secretsmanager-policy" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:*"]
    resources = ["*"]
  }
}
