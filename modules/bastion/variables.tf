################################################################################
# General
################################################################################

variable "namespace" {
    description = "Naming Partial [0] for Module Resource(s). Organization, Company-Name Prefix."
    type        = string
}

variable "environment" {
    description = "Naming Partial [1] for Module Resource(s). Environment-Name Alias."
    type        = string

    validation {
        condition     = (var.environment == "Development") ? true : (var.environment == "QA") ? true : (var.environment == "Staging") ? true : (var.environment == "UAT") ? true : (var.environment == "Production") ? true : false
        error_message = "Environment Name !:= \"Development\" | \"QA\" | \"Staging\" | \"UAT\" | \"Production\"."
    }
}

variable "application" {
    description = "Naming Partial [2] for Module Resource(s). User-Created Application Name."
    type        = string
}

variable "service" {
    description = "Naming Partial [3] for Module Resource(s). Cloud-related Service Name or Shorthand."
    type        = string
}

################################################################################
# EC2
################################################################################

variable "subnet-id" {
    description = "AWS Subnet Identifier to Associate EC2 Network Interface"
    type = string
}

variable "instance-type" {
    description = "The Launch Template Default Instance Type."
    default     = "t4g.nano"
    type        = string
}

variable "additional-security-group-ids" {
    description = "Additional Security Groups to Associate the Network Interface. Typical Usages Include VPC-Endpoints (e.g. SSM, SSMMessages to Console, SSH Access)"
    type = list(string)
    default = []
}
