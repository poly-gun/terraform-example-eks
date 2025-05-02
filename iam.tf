# ---
# --- aws-load-balancer-controller
# ---

data "aws_iam_policy_document" "aws-load-balancer-controller-service-account-iam-assume-role-policy" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:sub"

      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

data "aws_iam_policy_document" "aws-load-balancer-controller-service-account-policy" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions   = ["iam:CreateServiceLinkedRole"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTrustStores",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:CreateSecurityGroup"]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    actions   = ["ec2:CreateTags"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:*:security-group/*"]

    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
    ]
  }

  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
    ]

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]

    actions = ["elasticloadbalancing:AddTags"]

    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"

      values = [
        "CreateTargetGroup",
        "CreateLoadBalancer",
      ]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]

    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]
  }

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

resource "aws_iam_role" "aws-load-balancer-controller-service-account-role" {
  name_prefix        = format("%s-", "AWS-Load-Balancer-Controller")
  assume_role_policy = data.aws_iam_policy_document.aws-load-balancer-controller-service-account-iam-assume-role-policy.json

  tags = {
    Name = "AWS-Load-Balancer-Controller"
  }
}

resource "aws_iam_policy" "aws-load-balancer-controller-service-account-policy" {
  policy      = data.aws_iam_policy_document.aws-load-balancer-controller-service-account-policy.json
  name_prefix = format("%s-", "AWS-Load-Balancer-Controller-Policy")
  tags        = {
    Name = "AWS-Load-Balancer-Controller-Policy"
  }
}

resource "aws_iam_role_policy_attachment" "aws-load-balancer-controller-service-account-policy-attachment" {
  policy_arn = aws_iam_policy.aws-load-balancer-controller-service-account-policy.arn
  role       = aws_iam_role.aws-load-balancer-controller-service-account-role.name
}

# # ---
# # --- aws-gateway-api-controller
# # ---
#
# data "aws_iam_policy_document" "aws-gateway-api-controller-service-account-iam-assume-role-policy" {
# #   statement {
# #     actions = ["sts:AssumeRoleWithWebIdentity"]
# #     effect  = "Allow"
# #
# #     condition {
# #       test     = "StringEquals"
# #       variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:sub"
# #
# #       values   = ["system:serviceaccount:kube-system:aws-gateway-api-controller"]
# #     }
# #
# #     condition {
# #       test     = "StringEquals"
# #       variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:aud"
# #       values   = ["sts.amazonaws.com"]
# #     }
# #
# #     principals {
# #       identifiers = [aws_iam_openid_connect_provider.provider.arn]
# #       type        = "Federated"
# #     }
# #   }
#
#   statement {
#     sid    = ""
#     effect = "Allow"
#
#     actions = [
#       "sts:AssumeRole",
#       "sts:TagSession",
#     ]
#
#     principals {
#       type        = "Service"
#       identifiers = ["pods.eks.amazonaws.com"]
#     }
#   }
# }
#
# data "aws_iam_policy_document" "aws-gateway-api-controller-service-account-policy" {
#   statement {
#     sid       = ""
#     effect    = "Allow"
#     resources = ["*"]
#
#     actions = [
#       "vpc-lattice:*",
#       "ec2:DescribeVpcs",
#       "ec2:DescribeSubnets",
#       "ec2:DescribeTags",
#       "ec2:DescribeSecurityGroups",
#       "logs:CreateLogDelivery",
#       "logs:GetLogDelivery",
#       "logs:DescribeLogGroups",
#       "logs:PutResourcePolicy",
#       "logs:DescribeResourcePolicies",
#       "logs:UpdateLogDelivery",
#       "logs:DeleteLogDelivery",
#       "logs:ListLogDeliveries",
#       "tag:GetResources",
#       "firehose:TagDeliveryStream",
#       "s3:GetBucketPolicy",
#       "s3:PutBucketPolicy",
#     ]
#   }
#
#   statement {
#     sid       = ""
#     effect    = "Allow"
#     resources = ["arn:aws:iam::*:role/aws-service-role/vpc-lattice.amazonaws.com/AWSServiceRoleForVpcLattice"]
#     actions   = ["iam:CreateServiceLinkedRole"]
#
#     condition {
#       test     = "StringLike"
#       variable = "iam:AWSServiceName"
#       values   = ["vpc-lattice.amazonaws.com"]
#     }
#   }
#
#   statement {
#     sid       = ""
#     effect    = "Allow"
#     resources = ["arn:aws:iam::*:role/aws-service-role/delivery.logs.amazonaws.com/AWSServiceRoleForLogDelivery"]
#     actions   = ["iam:CreateServiceLinkedRole"]
#
#     condition {
#       test     = "StringLike"
#       variable = "iam:AWSServiceName"
#       values   = ["delivery.logs.amazonaws.com"]
#     }
#   }
# }
#

data "aws_iam_policy_document" "aws-gateway-api-controller-service-account-role-assume-policy" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }

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
        "system:serviceaccount:aws-application-networking-system:aws-gateway-api-controller",
      ]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws-gateway-api-controller-service-account-role" {
  name_prefix        = format("%s-", "AWS-Gateway-API-Controller")
  assume_role_policy = data.aws_iam_policy_document.aws-gateway-api-controller-service-account-role-assume-policy.json

  tags = {
    Name = "AWS-Gateway-API-Controller"
  }
}

resource "aws_iam_policy" "aws-gateway-api-controller-service-account-policy" {
  policy      = file("aws-lattice-controller-policy.json")
  name_prefix = format("%s-", "AWS-Gateway-API-Controller-Policy")
  tags        = {
    Name = "AWS-Gateway-API-Controller-Policy"
  }
}

resource "aws_iam_role_policy_attachment" "aws-gateway-api-controller-service-account-policy-attachment" {
  policy_arn = aws_iam_policy.aws-gateway-api-controller-service-account-policy.arn
  role       = aws_iam_role.aws-gateway-api-controller-service-account-role.name
}

// ---

data "aws_iam_policy_document" "external-dns-service-account-role-assume-policy" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }

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
        "system:serviceaccount:external-dns:external-dns-controller",
      ]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "external-dns-service-account-role" {
  name_prefix        = format("%s-", "External-DNS-Controller")
  assume_role_policy = data.aws_iam_policy_document.external-dns-service-account-role-assume-policy.json

  tags = {
    Name = "External-DNS-Controller"
  }
}

data "aws_iam_policy_document" "external-dns-service-account-policy-document" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/*"]
    actions   = ["route53:ChangeResourceRecordSets"]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource"
    ]
  }
}

resource "aws_iam_policy" "external-dns-service-account-policy" {
  policy      = data.aws_iam_policy_document.external-dns-service-account-policy-document.json
  name_prefix = format("%s-", "External-DNS-Controller-Policy")
  tags        = {
    Name = "External-DNS-Controller-Policy"
  }
}

resource "aws_iam_role_policy_attachment" "external-dns-service-account-policy-attachment" {
  policy_arn = aws_iam_policy.external-dns-service-account-policy.arn
  role       = aws_iam_role.external-dns-service-account-role.name
}

