# output "bastion-ssh-key" {
#     value = module.bastion.private-ssh-key
#     sensitive = true
# }

output "cluster-id" {
  value = local.cluster-identifier
}

output "cluster-identity-oidc-issuer" {
  value = aws_eks_cluster.cluster.identity[0].oidc[0]["issuer"]
}

# output "identity-provider-urls" {
#     value = {
#         uri = aws_iam_openid_connect_provider.openid-provider.url
#         url = "https://${aws_iam_openid_connect_provider.openid-provider.url}"
#     }
# }

output "cluster-name" {
  value = aws_eks_cluster.cluster.name
}

output "vpc" {
  value = data.aws_vpc.vpc
}

output "aws-sso-instances" {
  value = data.aws_ssoadmin_instances.sso
}

output "aws-sso-permission-sets" {
  value = data.aws_ssoadmin_permission_set.sso
}

output "verification-service-account-iam-annotation" {
  value = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.verification-service-account-role.arn
  }
}
