resource "aws_ecr_repository" "repository" {
  name = "authentication-service"

  force_delete         = true
  image_tag_mutability = "MUTABLE"

  tags = merge({
    Name = "authentication-service"
  }, {})
}

resource "aws_ecr_repository" "user-service-repository" {
  name = "user-service"

  force_delete         = true
  image_tag_mutability = "MUTABLE"

  tags = merge({
    Name = "user-service"
  }, {})
}

# resource "aws_ecr_repository" "discord-auth2-service-repository" {
#   name = "discord-oauth2-service"
#
#   force_delete         = true
#   image_tag_mutability = "MUTABLE"
#
#   tags = merge({
#     Name = "discord-oauth2-service"
#   }, {})
# }

resource "aws_ecr_repository" "verification-service-repository" {
  name = "verification-service"

  force_delete         = true
  image_tag_mutability = "MUTABLE"

  tags = merge({
    Name = "verification-service"
  }, {})
}

resource "aws_ecr_repository" "reconnaissance-service" {
  name = "reconnaissance-service"

  force_delete         = true
  image_tag_mutability = "MUTABLE"

  tags = merge({
    Name = "reconnaissance-service"
  }, {})
}

# resource "aws_ecr_repository" "customer-service-repository" {
#   name = "customer-service"
#
#   force_delete         = true
#   image_tag_mutability = "MUTABLE"
#
#   tags = merge({
#     Name = "customer-service"
#   }, {})
# }

# resource "aws_ecr_repository" "gsm-service-repository" {
#   name = "gsm-service"
#
#   force_delete         = true
#   image_tag_mutability = "MUTABLE"
#
#   tags = merge({
#     Name = "gsm-service"
#   }, {})
# }

resource "aws_ecr_repository" "health-service-repository" {
  name = "health-service"

  force_delete         = true
  image_tag_mutability = "MUTABLE"

  tags = merge({
    Name = "health-service"
  }, {})
}
#
#
# resource "aws_ecr_repository" "billing-service-repository" {
#   name = "billing-service"
#
#   force_delete         = true
#   image_tag_mutability = "MUTABLE"
#
#   tags = merge({
#     Name = "billing-service"
#   }, {})
# }
