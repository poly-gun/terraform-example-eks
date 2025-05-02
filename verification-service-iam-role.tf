data "aws_iam_policy_document" "verification-service-account-iam-assume-role-policy" {
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
        "system:serviceaccount:development:verification-service",
        "system:serviceaccount:production:verification-service",
      ]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

data "aws_iam_policy_document" "verification-service-eks-pod-identity-policy" {
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

data "aws_iam_policy_document" "verification-service-account-iam-ses-policy" {
  statement {
    effect  = "Allow"
    actions = ["ses:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "verification-service-account-role" {
  assume_role_policy = data.aws_iam_policy_document.verification-service-account-iam-assume-role-policy.json
  name_prefix               = format("%s-Verification-Service-", var.name)

  tags = merge({
    Name = format("%s-Verification-Service-", var.name)
  })
}

resource "aws_iam_policy" "verification-service-eks-pod-identity-policy" {
  name_prefix        = format("%s-Verification-Service-Pod-Identity-Policy-", var.name)
  description = "AWS IAM Policy for EKS Pod Identity Agent"
  path        = "/"

  policy = data.aws_iam_policy_document.verification-service-eks-pod-identity-policy.json

  tags = merge({
    Name = format("%s-Verification-Service-Pod-Identity-Policy", var.name)
  }, {})
}

resource "aws_iam_role_policy_attachment" "verification-service-eks-pod-identity-policy-attachment" {
  policy_arn = aws_iam_policy.verification-service-eks-pod-identity-policy.arn
  role       = aws_iam_role.verification-service-account-role.name
}

resource "aws_iam_policy" "verification-service-account-ses-iam-policy" {
  name_prefix        = format("%s-Verification-Service-SES-", var.name)
  description = "AWS SES IAM Policy"
  path        = "/"

  policy = data.aws_iam_policy_document.verification-service-account-iam-ses-policy.json

  tags = merge({
    Name = format("%s-Verification-Service-SES", var.name)
  }, {})
}

resource "aws_iam_role_policy_attachment" "verification-service-account-ses-iam-policy-attachment" {
  policy_arn = aws_iam_policy.verification-service-account-ses-iam-policy.arn
  role       = aws_iam_role.verification-service-account-role.name
}
