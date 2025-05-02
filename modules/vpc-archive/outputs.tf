################################################################################
# Output(s)
################################################################################

output "aws-region" {
    description = "AWS Region Name"
    value       = data.aws_region.region.name
}

output "aws-vpc-id" {
    description = "VPC Identifier"
    value       = aws_vpc.vpc.id
}

output "aws-public-subnets" {
    description = "Public VPC Subnet Identifier, Name List"
    value       = flatten([
        for subnet in aws_subnet.public : {
            id   = subnet.id
            name = lookup(subnet.tags, "Name", null)
        }
    ])
}

output "aws-private-subnets" {
    description = "Private VPC Subnet Identifier, Name List"
    value       = flatten([
        for subnet in aws_subnet.private : {
            id   = subnet.id
            name = lookup(subnet.tags, "Name", null)
        }
    ])
}

output "aws-vpc-metadata" {
    sensitive   = false
    description = "AWS VPC CIDR Range(s), Indicated via Category of Subnet"
    value       = {
        id        = aws_vpc.vpc.id
        subnets   = local.subnets
        cidr-ipv4 = aws_vpc.vpc.cidr_block
        cidr-ipv6 = aws_vpc.vpc.ipv6_cidr_block
        tags      = aws_vpc.vpc.tags
    }
}

output "aws-ssm-vpn-endpoint-security-group-id" {
    value = aws_security_group.ssm.id
}

output "aws-ssmmessages-vpn-endpoint-security-group-id" {
    value = aws_security_group.ssmmessages.id
}

output "aws-vpc-ipv4-cidr-block" {
    value = aws_vpc.vpc.cidr_block
}

output "aws-vpc-ipv6-cidr-block" {
    value = aws_vpc.vpc.ipv6_cidr_block
}

output "aws-ssm-vpc-endpoint" {
    value = [aws_vpc_endpoint.ssm.arn, aws_vpc_endpoint.ssmmessages.arn]
}

output "aws-database-subnet-group-name" {
  value = aws_db_subnet_group.database.name
}

output "aws-database-subnet-group-arn" {
  value = aws_db_subnet_group.database.arn
}

output "aws-database-subnet-group-subnet-ids" {
  value = aws_db_subnet_group.database.subnet_ids
}

output "aws-database-subnet-group-vpc-id" {
  value = aws_db_subnet_group.database.vpc_id
}

output "aws-public-database-subnet-group-name" {
  value = aws_db_subnet_group.database-public.name
}

output "aws-public-database-subnet-group-arn" {
  value = aws_db_subnet_group.database-public.arn
}

output "aws-public-database-subnet-group-subnet-ids" {
  value = aws_db_subnet_group.database-public.subnet_ids
}

output "aws-public-database-subnet-group-vpc-id" {
  value = aws_db_subnet_group.database-public.vpc_id
}
