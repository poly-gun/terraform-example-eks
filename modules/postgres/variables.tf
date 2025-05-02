variable "namespace" {
  type = string
  default = "polygun"
}

variable "environment" {
  type = string
  default = "production"
}

variable "vpc-id" {
  type = string
  description = "VPC Identifier"
}

variable "database-identifier" {
  type = string
  description = "Database AWS Identifier"
}

variable "database-instance-class" {
  type = string
  description = "Database Instance Class"
  default = "db.t4g.small"
}

variable "database-name" {
  type = string
  description = "Database Name"
  default = "postgres"
}

variable "database-username" {
  type = string
  description = "Database Name"
  default = "polygun"
}

variable "database-subnet-group-name" {
  type = string
  description = "Database Subnet Group"
}

variable "database-parameter-group" {
  type = string
  default = "default.postgres16"
}

variable "database-options-group" {
  type = string
  default = "default:postgres-16"
}

variable "database-deletion-protection" {
  type = bool
  default = false
}
