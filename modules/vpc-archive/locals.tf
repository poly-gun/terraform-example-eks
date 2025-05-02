################################################################################
# Terraform Runtime Variables
################################################################################

locals {
    azs     = slice(data.aws_availability_zones.available.names, 0, 3)
    subnets = {
        public      = [for k, v in local.azs : cidrsubnet(var.cidr, 4, k)]
        private     = [for k, v in local.azs : cidrsubnet(var.cidr, 4, k + 4)]
        database    = [for k, v in local.azs : cidrsubnet(var.cidr, 4, k + 8)]
        elasticache = [for k, v in local.azs : cidrsubnet(var.cidr, 4, k + 12)]
    }

    ipv6-subnets = {
        public = [
            for k, v in local.azs :cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, k)
        ]
    }
}
