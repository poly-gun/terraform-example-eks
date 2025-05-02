################################################################################
# Data
################################################################################

data "aws_partition" "arn" {}
data "aws_region" "region" {}
data "aws_caller_identity" "caller" {}
data "aws_availability_zones" "available" {}

data "aws_subnet" "subnet"{
    id = var.subnet-id
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

data "aws_ec2_instance_type" "type" {
    instance_type = var.instance-type
}
