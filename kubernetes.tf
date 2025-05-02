# ---
# --- aws-load-balancer-controller
# ---

resource kubernetes_service_account "aws-load-balancer-controller-service-account" {
  metadata {
    name        = "aws-load-balancer-controller"
    namespace   = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws-load-balancer-controller-service-account-role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws-load-balancer-controller-service-account-policy-attachment
  ]
}

# ---
# --- aws-gateway-api-controller
# ---

resource "kubernetes_namespace" "aws-application-networking-system" {
  metadata {
    name = "aws-application-networking-system"
    labels = {
      control-plane= "gateway-api-controller"
    }
  }
}

resource kubernetes_service_account "aws-gateway-api-controller-service-account" {
  metadata {
    name        = "aws-gateway-api-controller"
    namespace   = kubernetes_namespace.aws-application-networking-system.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws-gateway-api-controller-service-account-role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws-gateway-api-controller-service-account-policy-attachment
  ]
}


# ---
# --- external-dns-controller
# ---

resource "kubernetes_namespace" "external-dns" {
  metadata {
    name = "external-dns"
    labels = {
      istio-injection = "disabled"
    }
  }
}

resource kubernetes_service_account "external-dns-controller-service-account" {
  metadata {
    name        = "external-dns-controller"
    namespace   = kubernetes_namespace.external-dns.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external-dns-service-account-role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.external-dns-service-account-policy-attachment
  ]
}


