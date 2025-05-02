################################################################################
# Module(s)
################################################################################

# module "vpc" {
#   source = "./modules/vpc"
#
#   name   = var.name
#
#   cidr = local.cluster-ipv4-cidr
# }

module "postgres-1" {
  source = "./modules/postgres"

  vpc-id = data.aws_vpc.vpc.id # module.vpc.aws-vpc-id

  database-subnet-group-name = aws_db_subnet_group.database-public.name # module.vpc.aws-public-database-subnet-group-name

  database-identifier = "instance-1"
}
