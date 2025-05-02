data "aws_iam_policy_document" "authentication-service-account-iam-assume-role-policy" {
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
        "system:serviceaccount:development:authentication-service",
        "system:serviceaccount:production:authentication-service",
      ]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

data "aws_iam_policy_document" "authentication-service-eks-pod-identity-policy" {
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

data "aws_iam_policy_document" "authentication-service-account-iam-ses-policy" {
  statement {
    effect  = "Allow"
    actions = ["ses:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "authentication-service-account-role" {
  assume_role_policy = data.aws_iam_policy_document.authentication-service-account-iam-assume-role-policy.json
  name_prefix               = format("%s-Authentication-Service-", var.name)

  tags = merge({
    Name = format("%s-Authentication-Service-", var.name)
  })
}

resource "aws_iam_policy" "authentication-service-eks-pod-identity-policy" {
  name_prefix        = format("%s-Authentication-Service-Pod-Identity-Policy-", var.name)
  description = "AWS IAM Policy for EKS Pod Identity Agent"
  path        = "/"

  policy = data.aws_iam_policy_document.authentication-service-eks-pod-identity-policy.json

  tags = merge({
    Name = format("%s-Authentication-Service-Pod-Identity-Policy", var.name)
  }, {})
}

resource "aws_iam_role_policy_attachment" "authentication-service-eks-pod-identity-policy-attachment" {
  policy_arn = aws_iam_policy.authentication-service-eks-pod-identity-policy.arn
  role       = aws_iam_role.authentication-service-account-role.name
}

resource "aws_iam_policy" "authentication-service-account-ses-iam-policy" {
  name_prefix        = format("%s-Authentication-Service-SES-", var.name)
  description = "AWS SES IAM Policy"
  path        = "/"

  policy = data.aws_iam_policy_document.authentication-service-account-iam-ses-policy.json

  tags = merge({
    Name = format("%s-Authentication-Service-SES", var.name)
  }, {})
}

resource "aws_iam_role_policy_attachment" "authentication-service-account-ses-iam-policy-attachment" {
  policy_arn = aws_iam_policy.authentication-service-account-ses-iam-policy.arn
  role       = aws_iam_role.authentication-service-account-role.name
}
