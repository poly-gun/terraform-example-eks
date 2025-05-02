################################################################################
# General
################################################################################

variable "name" {
  description = "Naming Partial for Module Resource(s). Organization, Company-Name Prefix."
  default     = "Polygun"
  type        = string
}

variable "mail-identity-domain" {
  description = "Used to establish the SES Mail Identity."
  default = "polygun.com"
  type = string
}

################################################################################
# Cluster
################################################################################

variable "cluster-version" {
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.27`)"
  type        = string
  default     = "1.31"
}

variable "cluster-log-types" {
  description = "A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  type        = list(string)
  default     = [] # ["audit", "api", "authenticator", "controllerManager", "scheduler"]
}

# variable "cluster-additional-log-group-ids" {
#   description = "List of additional, externally created security group IDs to attach to the cluster control plane"
#   type        = list(string)
#   default     = []
# }

variable "cluster-timeouts" {
  description = "Create, update, and delete timeout configurations for the cluster"
  type        = map(string)
  default = {}
}

variable "sso-role" {
  type    = string
  default = "AWSReservedSSO*"
}

variable "vpc-name" {
  type = string
  default = "Polygun-Development-Global-Network-VPC"
}

# variable "devops-user" {
#   type = string
#   default = "devops"
# }
