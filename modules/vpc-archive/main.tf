################################################################################
# VPC (Resource)
################################################################################

resource "aws_vpc" "vpc" {
    cidr_block = var.cidr

    assign_generated_ipv6_cidr_block = true

    instance_tenancy = "default"

    enable_dns_support                   = true
    enable_dns_hostnames                 = true
    enable_network_address_usage_metrics = false

    tags = merge({}, {
        Name = format("%s-VPC", var.name)
    })
}

################################################################################
# VPC Endpoint(s) - SSM
################################################################################
# - Allows Console User(s) Access to EC2 Session-Manager + Private SSM Service(s)
#   - Successfully Replaces Requirements for an SSH Bastion Host, SSH Access
#

data "aws_vpc_endpoint_service" "ssm" {
    service = "ssm"
}

resource "aws_security_group" "ssm" {
    name        = format("%s-SSM-SG", var.name)
    description = "SSM VPC Endpoint Security Group"
    vpc_id      = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-SSM-SG", var.name)
    })

    timeouts {
        delete = "2m"
    }
}

resource "aws_vpc_endpoint" "ssm" {
    service_name      = data.aws_vpc_endpoint_service.ssm.service_name
    vpc_id            = aws_vpc.vpc.id
    vpc_endpoint_type = "Interface"

    security_group_ids  = [aws_security_group.ssm.id]
    subnet_ids          = aws_subnet.private[*].id
    private_dns_enabled = true

    tags = merge({}, {
        Name = format("%s-SSM-VPC-Endpoint", var.name)
    })
}

// https://repost.aws/knowledge-center/ec2-systems-manager-vpc-endpoints
resource "aws_security_group_rule" "ssm-vpc-http-sg-rule-ingress" {
    description       = "VPC Service Endpoint Access for SSM to Query Against Internal Resource(s)"
    type              = "ingress"
    protocol          = "tcp"
    from_port         = 443
    to_port           = 443
    security_group_id = aws_security_group.ssm.id

    cidr_blocks = [
        aws_vpc.vpc.cidr_block
    ]
}

################################################################################
# VPC Endpoint(s) - SSM-Messages
################################################################################
# - Allows Console User(s) Access to SSM, Internal Service(s) + Function
#

data "aws_vpc_endpoint_service" "ssmmessages" {
    service = "ssmmessages"
}

resource "aws_vpc_endpoint" "ssmmessages" {
    vpc_id            = aws_vpc.vpc.id
    service_name      = data.aws_vpc_endpoint_service.ssmmessages.service_name
    vpc_endpoint_type = "Interface"

    security_group_ids  = [aws_security_group.ssmmessages.id]
    subnet_ids          = aws_subnet.private[*].id
    private_dns_enabled = true

    tags = merge({}, {
        Name = format("%s-SSMM-VPC-Endpoint", var.name)
    })
}

resource "aws_security_group" "ssmmessages" {
    name        = format("%s-SSMM-SG", var.name)
    description = "SSMM VPC Endpoint Security Group"
    vpc_id      = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-SSMM-SG", var.name)
    })

    timeouts {
        delete = "2m"
    }
}

resource "aws_security_group_rule" "ssmmessages-vpc-http-sg-rule-ingress" {
    description = "VPC Service Endpoint Access for SSMM to Query Against Internal Resource(s)"

    type              = "ingress"
    protocol          = "tcp"
    from_port         = 443
    to_port           = 443
    security_group_id = aws_security_group.ssmmessages.id

    cidr_blocks = [
        aws_vpc.vpc.cidr_block
    ]
}

################################################################################
# DHCP Options Set
################################################################################

resource "aws_vpc_dhcp_options" "dhcp" {
    domain_name_servers = ["AmazonProvidedDNS"]
    domain_name         = "${data.aws_region.region.name}.compute.internal"

    tags = merge({}, {
        Name = format("%s-VPC-DHCP-Options", var.name)
    })
}

resource "aws_vpc_dhcp_options_association" "dhcp-association" {
    vpc_id          = aws_vpc.vpc.id
    dhcp_options_id = aws_vpc_dhcp_options.dhcp.id
}

################################################################################
# Publiс Subnets
################################################################################

resource "aws_subnet" "public" {
    count = length(local.subnets.public)

    enable_dns64                                   = false
    assign_ipv6_address_on_creation                = false
    enable_resource_name_dns_aaaa_record_on_launch = false

    map_customer_owned_ip_on_launch = null

    availability_zone = (length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null)

    cidr_block = element(concat(local.subnets.public, [""]), count.index)

    ipv6_cidr_block = element(concat(local.ipv6-subnets.public, [""]), count.index)

    enable_resource_name_dns_a_record_on_launch = true
    map_public_ip_on_launch                     = true
    vpc_id                                      = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-Public-Subnet-%d", var.name, count.index + 1)

        "kubernetes.io/role/elb" = "1"
    })

    lifecycle {
        ignore_changes = [
            map_customer_owned_ip_on_launch
        ]
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-Public-Route-Table", var.name)
    })
}

resource "aws_route_table_association" "public" {
    count          = length(local.azs)
    subnet_id      = element(aws_subnet.public[*].id, count.index)
    route_table_id = aws_route_table.public.id
}

resource "aws_route" "public-internet-gateway-ipv4" {
    route_table_id         = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.ig.id

    timeouts {
        create = "5m"
    }
}

resource "aws_route" "public-internet-gateway-ipv6" {
    route_table_id              = aws_route_table.public.id
    destination_ipv6_cidr_block = "::/0"
    gateway_id                  = aws_internet_gateway.ig.id
}

################################################################################
# Private Subnets
################################################################################
# Generally the best practice is to have each availability-zone mapped to its own NAT device; such
# prevents devices in other zones from being unable to connect to the internet if that particular
# nat's own availability-zone is facing issues.
#
# Therefore, relating to route-tables, subnets, and nat devices, resource(s) should be established as a function
# of total availability-zones, and then mapped to one-another accordingly.
#
resource "aws_subnet" "private" {
    count = length(local.azs)

    assign_ipv6_address_on_creation                = false
    enable_dns64                                   = false
    enable_resource_name_dns_aaaa_record_on_launch = false

    map_customer_owned_ip_on_launch = null

    availability_zone                           = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
    cidr_block                                  = element(concat(local.subnets.private, [""]), count.index)
    enable_resource_name_dns_a_record_on_launch = true
    map_public_ip_on_launch                     = false
    vpc_id                                      = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-Private-Subnet-%d", var.name, count.index + 1)

        "kubernetes.io/role/internal-elb" = "1"
    })
}

resource "aws_route_table" "private" {
    count = length(local.azs)

    vpc_id = aws_vpc.vpc.id
    tags   = merge({}, {
        Name = format("%s-Private-Route-Table-%d", var.name, count.index + 1)
    })
}

resource "aws_route_table_association" "private" {
    count = length(local.azs)

    subnet_id      = element(aws_subnet.private[*].id, count.index)
    route_table_id = element(aws_route_table.private[*].id, count.index)
}

# Provides Internet Access to Resource(s) within Private Subnet(s), Availability Zone(s)
#   - Note that the `destination_cidr_block` value MUST be "0.0.0.0/0"; specifying only a WAN
#     CIDR will allow Internet access.

resource "aws_route" "private-nat-gateway" {
    count = length(local.azs)

    route_table_id         = element(aws_route_table.private[*].id, count.index)
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = element(aws_nat_gateway.nat-gateway[*].id, count.index)

    timeouts {
        create = "5m"
    }
}

################################################################################
# Database Subnets
################################################################################

resource "aws_subnet" "database" {
    count = length(local.azs)

    assign_ipv6_address_on_creation                = false
    enable_dns64                                   = false
    enable_resource_name_dns_aaaa_record_on_launch = false

    map_customer_owned_ip_on_launch = null

    availability_zone = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null

    cidr_block = element(concat(local.subnets.database, [""]), count.index)
    enable_resource_name_dns_a_record_on_launch = true
    map_public_ip_on_launch                     = false
    vpc_id                                      = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-DB-Subnet-%d", var.name, count.index + 1)
    })
}

resource "aws_network_acl" "database" {
    count = length(aws_subnet.database)

    vpc_id = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-Database-NACL-%d", var.name,count.index + 1)
    })
}

resource "aws_network_acl_association" "database" {
    count          = length(aws_subnet.database)
    network_acl_id = aws_network_acl.database[count.index].id
    subnet_id      = aws_subnet.database[count.index].id
}

resource "aws_network_acl_rule" "database-nacl-allow-postgresql-inbound-ipv4" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    cidr_block = aws_vpc.vpc.cidr_block

    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    rule_action = "allow"
    rule_number = 100
}

resource "aws_network_acl_rule" "database-nacl-allow-postgresql-inbound-ipv6" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    ipv6_cidr_block = aws_vpc.vpc.ipv6_cidr_block

    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    rule_action = "allow"
    rule_number = 105
}

resource "aws_network_acl_rule" "database-nacl-allow-mysql-inbound-ipv4" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    cidr_block = aws_vpc.vpc.cidr_block

    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    rule_action = "allow"
    rule_number = 110
}

resource "aws_network_acl_rule" "database-nacl-allow-mysql-inbound-ipv6" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    ipv6_cidr_block = aws_vpc.vpc.ipv6_cidr_block

    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    rule_action = "allow"
    rule_number = 115
}

resource "aws_network_acl_rule" "database-nacl-allow-documentdb-inbound-ipv4" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    cidr_block = aws_vpc.vpc.cidr_block

    protocol    = "tcp"
    from_port   = 27017
    to_port     = 27017
    rule_action = "allow"
    rule_number = 120
}

resource "aws_network_acl_rule" "database-nacl-allow-documentdb-inbound-ipv6" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    ipv6_cidr_block = aws_vpc.vpc.ipv6_cidr_block

    protocol    = "tcp"
    from_port   = 27017
    to_port     = 27017
    rule_action = "allow"
    rule_number = 125
}

resource "aws_network_acl_rule" "database-nacl-deny-all-inbound-ipv4" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    cidr_block = "0.0.0.0/0"

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1000
}

resource "aws_network_acl_rule" "database-nacl-deny-all-inbound-ipv6" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    ipv6_cidr_block = "::/0"

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1005
}

// The server-client connection usually makes dynamically allocated port
// outbound responses; all ports need to be enabled, but can be more limited
// to that of the VPC
resource "aws_network_acl_rule" "database-nacl-allow-outbound-ipv4" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    cidr_block = aws_vpc.vpc.cidr_block

    egress = true

    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    rule_action = "allow"
    rule_number = 100
}

// The server-client connection usually makes dynamically allocated port
// outbound responses; all ports need to be enabled, but can be more limited
// to that of the VPC
resource "aws_network_acl_rule" "database-nacl-allow-outbound-ipv6" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    ipv6_cidr_block = aws_vpc.vpc.ipv6_cidr_block

    egress = true

    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    rule_action = "allow"
    rule_number = 105
}

resource "aws_network_acl_rule" "database-nacl-deny-all-outbound-ipv4" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    cidr_block = "0.0.0.0/0"

    egress = true

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1000
}

resource "aws_network_acl_rule" "database-nacl-deny-all-outbound-ipv6" {
    count = length(aws_subnet.database)

    network_acl_id = aws_network_acl.database[count.index].id

    ipv6_cidr_block = "::/0"

    egress = true

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1005
}

resource "aws_db_subnet_group" "database" {
    name        = lower(format("%s-DB-Subnet-Group", var.name))
    description = "Database Subnet Group"
    subnet_ids  = aws_subnet.database[*].id

    tags = merge({}, {
        Name = format("%s-DB-Subnet-Group", var.name)
    })
}

resource "aws_db_subnet_group" "database-public" {
  name        = lower(format("%s-DB-Public-Subnet-Group", var.name, ))
  description = "Public Database Subnet Group"
  subnet_ids  = aws_subnet.public[*].id

  tags = merge({}, {
    Name = format("%s-DB-Public-Subnet-Group", var.name)
  })
}

# resource "aws_route_table" "database" {
#     count = length(local.azs)
#
#     vpc_id = aws_vpc.vpc.id
#
#     tags = merge({}, {
#         Name = format("%s-%s-DB-Route-Table-%d", var.name, var.environment, count.index + 1)
#     })
# }
#
# resource "aws_route_table_association" "database" {
#     count          = length(local.azs)
#     subnet_id      = element(aws_subnet.database[*].id, count.index)
#     route_table_id = aws_route_table.database[count.index].id
# }

################################################################################
# Elasticache Subnets
################################################################################

resource "aws_subnet" "elasticache" {
    count = length(local.azs)

    assign_ipv6_address_on_creation                = false
    enable_dns64                                   = false
    enable_resource_name_dns_aaaa_record_on_launch = false

    map_customer_owned_ip_on_launch = null

    availability_zone = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
    cidr_block = element(concat(local.subnets.elasticache, [""]), count.index)
    enable_resource_name_dns_a_record_on_launch = true
    map_public_ip_on_launch                     = false
    vpc_id                                      = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-EC-Subnet-%d", var.name, count.index + 1)
    })
}

resource "aws_network_acl" "elasticache" {
    count = length(aws_subnet.elasticache)

    vpc_id = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-EC-NACL-%d", var.name, count.index + 1)
    })
}

resource "aws_network_acl_association" "elasticache" {
    count          = length(aws_subnet.elasticache)
    network_acl_id = aws_network_acl.elasticache[count.index].id
    subnet_id      = aws_subnet.elasticache[count.index].id
}

resource "aws_network_acl_rule" "elasticache-nacl-allow-redis-inbound-ipv4" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    cidr_block = aws_vpc.vpc.cidr_block

    protocol    = "tcp"
    from_port   = 6379
    to_port     = 6379
    rule_action = "allow"
    rule_number = 100
}

resource "aws_network_acl_rule" "elasticache-nacl-allow-redis-inbound-ipv6" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    ipv6_cidr_block = aws_vpc.vpc.ipv6_cidr_block

    protocol    = "tcp"
    from_port   = 6379
    to_port     = 6379
    rule_action = "allow"
    rule_number = 105
}

resource "aws_network_acl_rule" "elasticache-nacl-deny-all-inbound-ipv4" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    cidr_block = "0.0.0.0/0"

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1000
}

resource "aws_network_acl_rule" "elasticache-nacl-deny-all-inbound-ipv6" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    ipv6_cidr_block = "::/0"

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1005
}

// The server-client connection usually makes dynamically allocated port
// outbound responses; all ports need to be enabled, but can be more limited
// to that of the VPC
resource "aws_network_acl_rule" "elasticache-nacl-allow-redis-outbound-ipv4" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    cidr_block = aws_vpc.vpc.cidr_block

    egress = true

    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    rule_action = "allow"
    rule_number = 100
}

// The server-client connection usually makes dynamically allocated port
// outbound responses; all ports need to be enabled, but can be more limited
// to that of the VPC
resource "aws_network_acl_rule" "elasticache-nacl-allow-redis-outbound-ipv6" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    ipv6_cidr_block = aws_vpc.vpc.ipv6_cidr_block

    egress = true

    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    rule_action = "allow"
    rule_number = 105
}

resource "aws_network_acl_rule" "elasticache-nacl-deny-all-outbound-ipv4" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    cidr_block = "0.0.0.0/0"

    egress = true

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1000
}

resource "aws_network_acl_rule" "elasticache-nacl-deny-all-outbound-ipv6" {
    count = length(aws_subnet.elasticache)

    network_acl_id = aws_network_acl.elasticache[count.index].id

    ipv6_cidr_block = "::/0"

    egress = true

    from_port = -1
    to_port   = -1

    protocol    = "all"
    rule_action = "deny"
    rule_number = 1005
}

resource "aws_elasticache_subnet_group" "elasticache" {
    name        = format("%s-EC-Subnet-Group", var.name)
    description = "EC Subnet Group"
    subnet_ids  = aws_subnet.elasticache[*].id

    tags = merge({}, {
        Name = format("%s-EC-Subnet-Group", var.name)
    })
}

# resource "aws_route_table" "elasticache" {
#     count = length(local.azs)
#
#     vpc_id = aws_vpc.vpc.id
#
#     tags = merge({}, {
#         Name = format("%s-%s-EC-Route-Table-%d", var.name, var.environment, count.index + 1)
#     })
# }
#
# resource "aws_route_table_association" "elasticache" {
#     count          = length(local.azs)
#     subnet_id      = element(aws_subnet.elasticache[*].id, count.index)
#     route_table_id = aws_route_table.elasticache[count.index].id
# }

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "ig" {
    vpc_id = aws_vpc.vpc.id

    tags = merge({}, {
        Name = format("%s-Public-IG", var.name)
    })
}

################################################################################
# NAT Gateway
################################################################################

resource "aws_nat_gateway" "nat-gateway" {
    count = length(local.azs)

    allocation_id = element(aws_eip.nat-elastic-ip[*].id, count.index)

    subnet_id  = element(aws_subnet.public[*].id, count.index)
    depends_on = [aws_internet_gateway.ig]

    tags = merge({}, {
        Name = format("%s-NAT-%d", var.name, count.index + 1)
    })
}

resource "aws_eip" "nat-elastic-ip" {
    count = length(local.azs)

    tags = merge({}, {
        Name = format("%s-Public-NAT-EIP-%d", var.name, count.index + 1)
    })
}
