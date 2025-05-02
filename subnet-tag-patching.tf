resource "aws_ec2_tag" "public-subnet-tags" {
  for_each = toset(data.aws_subnets.public.ids)

  resource_id = each.key
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private-subnet-tags" {
  for_each = toset(data.aws_subnets.private.ids)

  resource_id = each.key
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
