resource "aws_db_subnet_group" "database-public" {
  name        = lower(format("%s-DB-Public-Subnet-Group", var.name))
  description = "Public Database Subnet Group"
  subnet_ids  = data.aws_subnets.public.ids

  tags = merge({}, {
    Name = format("%s-DB-Public-Subnet-Group", var.name)
  })
}
