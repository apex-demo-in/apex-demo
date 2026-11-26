variable "region" {
  description = "Cloud region"
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Network name"
  type        = string
  default     = "xyz-abc"
  validation {
    condition     = can(regex("^(?:[a-z][a-z0-9-]{2,40})$", var.name))
    error_message = "Must match [a-z][a-z0-9-]{2,40}."
  }
}

variable "cidr" {
  description = "Address range. IPv4 CIDR block for the whole VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(regex("^(?:\\d{1,3}(\\.\\d{1,3}){3}/\\d{1,2})$", var.cidr))
    error_message = "Must match \\d{1,3}(\\.\\d{1,3}){3}/\\d{1,2}."
  }
}

variable "availability_zones" {
  description = "Availability zones. Two or more zones in the region the stack deploys to"
  type        = list(string)
  default     = [
    "us-east-1a",
    "us-east-1b",
  ]
}

variable "private_subnets" {
  description = "Private subnets. One per zone"
  type        = list(string)
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
}

variable "public_subnets" {
  description = "Public subnets. One per zone"
  type        = list(string)
  default     = [
    "10.0.101.0/24",
    "10.0.102.0/24",
  ]
}
