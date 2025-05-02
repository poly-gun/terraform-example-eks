################################################################################
# Input
################################################################################

variable "name" {
    description = "Naming Partial [0] for Module Resource(s). Organization, Company-Name Prefix."
    type        = string
}

variable "cidr" {
    description = "The IPv4 CIDR block for the VPC."
    type        = string
    // default     = "10.128.0.0/16" // Default (Public) CIDR Block
}
