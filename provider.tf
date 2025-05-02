terraform {
  backend "http" {}
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.81.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Namespace   = var.name
      TF          = "True"
    }
  }

  region = "us-east-2"
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

provider "kubernetes" {
  host                   =  aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.authentication.token
}

provider "helm" {
  kubernetes {
    host = aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
    token = data.aws_eks_cluster_auth.authentication.token
  }
}
