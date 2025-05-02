locals {
  cluster-ipv4-cidr         = "10.128.0.0/16"
  cluster-iam-policy-prefix = "arn:${data.aws_partition.arn.partition}:iam::aws:policy"

  cluster-identifier = split(".", trimprefix(aws_eks_cluster.cluster.endpoint, "https://"))[0]

  aws-loadbalancer-controller-iam-policy                    = file("iam-policy.json")
  cluster-node-group-aws-loadbalancer-controller-iam-policy = file("node-group-iam-policy.json")

  cluster-addons = {
    // https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
    aws-ebs-csi-driver = {
      latest = true
    }

    eks-pod-identity-agent = {
      latest = true
    }

    aws-mountpoint-s3-csi-driver = {
      latest = true
    }

    // amazon-cloudwatch-observability = {
    //     latest  = true
    // }

    // snapshot-controller = {
    //     latest  = true
    // }

  }
}
