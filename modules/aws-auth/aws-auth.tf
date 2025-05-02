locals {
  data = {
    mapRoles = yamlencode([
      {
        rolearn  = data.aws_iam_role.sso.arn
        username = "{{SessionName}}"
        groups   = ["system:masters"]
      },
    ])
    mapUsers    = yamlencode([{}])
    mapAccounts = yamlencode([
      data.aws_caller_identity.caller.account_id
    ])
  }
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.data

  lifecycle {
    # We are ignoring the data here since we will manage it with the resource below
    # This is only intended to be used in scenarios where the configmap does not exist
    ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.data

  depends_on = [
    # Required for instances where the configmap does not exist yet to avoid race condition
    kubernetes_config_map.aws_auth,
  ]
}
