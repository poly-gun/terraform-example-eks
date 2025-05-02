################################################################################
# Data
################################################################################

data "aws_partition" "arn" {}
data "aws_region" "region" {}
data "aws_caller_identity" "caller" {}
data "aws_availability_zones" "available" {}
