################################################################################
# EC2
################################################################################

resource "aws_launch_template" "template" {
    name          = format("%s-Bastion-Launch-Template", module.parameter.application)
    image_id      = data.aws_ami.ami.id
    instance_type = data.aws_ec2_instance_type.type.instance_type

    disable_api_stop        = false
    disable_api_termination = false
    update_default_version  = true
    ebs_optimized           = true

    key_name = aws_key_pair.key.key_name

    metadata_options {
        http_tokens = "required"
        http_endpoint = "enabled"
        http_put_response_hop_limit = 3

        instance_metadata_tags = "enabled"
    }

    user_data = base64encode(templatefile(join("/", [path.module, "user-script.bash"]), {
        AWS-Region = data.aws_region.region.name
    }))

    instance_initiated_shutdown_behavior = "terminate"

    private_dns_name_options {
        enable_resource_name_dns_aaaa_record = false
        enable_resource_name_dns_a_record    = true
        hostname_type                        = "resource-name"
    }

    network_interfaces {
        // associate_public_ip_address = "false"
        associate_public_ip_address = "true"
        delete_on_termination       = "true"
        description                 = "Bastion Elastic Network Interface"

        subnet_id = data.aws_subnet.subnet.id

        security_groups = flatten([
            [aws_security_group.sg.id], var.additional-security-group-ids
        ])
    }

    iam_instance_profile {
        name = aws_iam_instance_profile.service-profile.name
    }

    block_device_mappings {
        device_name = "/dev/xvda"

        ebs {
            iops                  = 3000
            volume_size           = 30 // Free Tier
            delete_on_termination = "true"
            volume_type           = "gp3"
            encrypted             = "false"
        }
    }

    monitoring {
        enabled = true
    }

    tags = merge({}, {
        Name = format("%s-Bastion-Launch-Template", module.parameter.application)
    })

    depends_on = [
        aws_iam_role_policy_attachment.attachment
    ]
}

resource "aws_security_group" "sg" {
    name   = format("%s-Bastion-SG", module.parameter.application)
    vpc_id = data.aws_subnet.subnet.vpc_id

    description = "Bastion Security Group"

    tags = merge({}, {
        Name = format("%s-Bastion-SG", module.parameter.application)
    })

    timeouts {
        delete = "2m"
    }
}

resource "aws_security_group_rule" "ec2-sg-all-sg-rule-egress" {
    description = "Allow Associated Resource(s) External, Internet Access"

    security_group_id = aws_security_group.sg.id
    protocol          = "all"
    from_port         = 0
    to_port           = 0
    type              = "egress"

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "ec2-external-ssh-sg-rule-ingress" {
    security_group_id = aws_security_group.sg.id

    description = "Public SSH Ingress Traffic Access to Instance"

    protocol = "tcp"

    from_port = 22
    to_port   = 22

    type = "ingress"

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

################################################################################
# IAM
################################################################################

resource "aws_iam_role" "service-role" {
    name = format("%s-Bastion-IAM-Role", module.parameter.application)

    assume_role_policy = jsonencode({
        Version : "2012-10-17",
        Statement : [
            {
                Action : "sts:AssumeRole",
                Effect : "allow",
                Principal : {
                    Service : [
                        "ec2.amazonaws.com",
                    ]
                }
            }
        ]
    })

    tags = merge({
        Name = format("%s-Bastion-IAM-Role", module.parameter.application)
    }, {})
}

resource "aws_iam_policy" "secrets-manager-iam-policy" {
    name = format("%s-Bastion-IAM-SM-Policy", module.parameter.application)

    policy = jsonencode({
        Version   = "2012-10-17"
        Statement = [
            {
                Action   = ["secretsmanager:GetSecretValue"]
                Effect   = "Allow"
                Resource = "*"
            },
        ]
    })

    tags = merge({
        Name = format("%s-Bastion-IAM-SM-Policy", module.parameter.application)
    }, {})
}

resource "aws_iam_policy" "ecr-iam-policy" {
    name = format("%s-Bastion-IAM-ECR-Policy", module.parameter.application)

    policy = jsonencode({
        Version   = "2012-10-17"
        Statement = [
            {
                Action = [
                    "ecr:*"
                ]
                Effect   = "Allow"
                Resource = "*"
            },
        ]
    })

    tags = merge({
        Name = format("%s-Bastion-IAM-ECR-Policy", module.parameter.application)
    }, {})
}

resource "aws_iam_policy" "eks-iam-policy" {
    name = format("%s-Bastion-IAM-EKS-Policy", module.parameter.application)

    policy = jsonencode({
        Version   = "2012-10-17"
        Statement = [
            {
                Action = [
                    "eks:*"
                ]
                Effect   = "Allow"
                Resource = "*"
            },
        ]
    })

    tags = merge({
        Name = format("%s-Bastion-IAM-ECR-Policy", module.parameter.application)
    }, {})
}

locals {
    attachments = {
        secrets-manager = {
            role = aws_iam_role.service-role.name
            policy_arn = aws_iam_policy.secrets-manager-iam-policy.arn
        }
        ssm = {
            role = aws_iam_role.service-role.name
            policy_arn = "arn:${data.aws_partition.arn.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
        }
        ecr = {
            role = aws_iam_role.service-role.name
            policy_arn = aws_iam_policy.ecr-iam-policy.arn
        }
        eks = {
            role = aws_iam_role.service-role.name
            policy_arn = aws_iam_policy.eks-iam-policy.arn
        }
    }
}

resource "aws_iam_role_policy_attachment" "attachment" {
    for_each = local.attachments

    role       = lookup(each.value, "role")
    policy_arn = lookup(each.value, "policy_arn")
}

resource "aws_iam_instance_profile" "service-profile" {
    name = format("%s-Bastion-IAM-Instance-Profile", module.parameter.application)

    role = aws_iam_role.service-role.name
    tags = merge({
        Name = format("%s-Bastion-IAM-Instance-Profile", module.parameter.application)
    }, {})

    depends_on = [
        aws_iam_role_policy_attachment.attachment
    ]

}

resource "aws_instance" "instance" {
    iam_instance_profile = aws_iam_instance_profile.service-profile.name

    launch_template {
        id      = aws_launch_template.template.id
        version = "$Latest"
        // version = aws_launch_template.template.latest_version
    }

    tags = merge({
        Name = format("%s-Bastion", module.parameter.application)
    }, {})

    depends_on = [
        aws_iam_role_policy_attachment.attachment
    ]
}
