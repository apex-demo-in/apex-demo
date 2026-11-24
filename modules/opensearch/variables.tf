variable "domain_name" {
  description = "Name of the OpenSearch domain. Lowercase, 28 characters or fewer."
  type        = string
}

variable "engine_version" {
  description = "OpenSearch engine version, for example OpenSearch_2.11."
  type        = string
}

variable "tls_security_policy" {
  description = "Minimum TLS policy for the domain endpoint."
  type        = string
  default     = "Policy-Min-TLS-1-2-2019-07"
}

variable "vpc_id" {
  description = "VPC that hosts the domain."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the domain attaches to, one per availability zone."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used for encryption at rest and log group encryption."
  type        = string
}

variable "master_user_name" {
  description = "Username of the fine-grained access control master user in the internal user database."
  type        = string
}

variable "master_user_password" {
  description = "Password of the fine-grained access control master user. Held in OpenTofu state; store the canonical copy in SSM."
  type        = string
  sensitive   = true
}

variable "access_principal_arns" {
  description = "IAM principals allowed to call the domain HTTP API. Each still needs a role mapping in the OpenSearch security plugin."
  type        = list(string)
}

variable "client_security_group_ids" {
  description = "Security groups allowed to reach the domain on port 443."
  type        = list(string)
  default     = []
}

variable "client_cidr_blocks" {
  description = "CIDR blocks allowed to reach the domain on port 443."
  type        = list(string)
  default     = []
}

variable "data_instance_type" {
  description = "Instance type for data nodes."
  type        = string
}

variable "data_instance_count" {
  description = "Number of data nodes."
  type        = number
}

variable "master_instance_type" {
  description = "Instance type for the three dedicated master nodes."
  type        = string
}

variable "volume_size" {
  description = "EBS volume size in GiB per data node."
  type        = number
}

variable "availability_zone_count" {
  description = "Number of availability zones for zone awareness."
  type        = number
  default     = 3
}

variable "log_retention_in_days" {
  description = "Retention for the domain's CloudWatch log groups."
  type        = number
  default     = 365
}
