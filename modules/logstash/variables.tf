variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC that hosts the Logstash service."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the Logstash tasks run in."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used for log groups, the image registry and execute-command logging."
  type        = string
}

variable "opensearch_endpoint" {
  description = "VPC endpoint hostname of the OpenSearch domain."
  type        = string
}

variable "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain the task role may write to."
  type        = string
}

variable "opensearch_security_group_id" {
  description = "Security group of the OpenSearch domain, used as the egress destination."
  type        = string
}

variable "vpc_endpoint_security_group_id" {
  description = "Security group of the interface VPC endpoints, used as an egress destination."
  type        = string
}

variable "s3_prefix_list_id" {
  description = "Managed prefix list ID of the regional S3 gateway endpoint."
  type        = string
}

variable "archive_bucket_arn" {
  description = "ARN of the archive bucket Logstash may write to under the logstash/ prefix."
  type        = string
}

variable "image_tag" {
  description = "Immutable tag of the Logstash image to run."
  type        = string
}

variable "task_cpu" {
  description = "Fargate CPU units per task."
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Fargate memory in MiB per task."
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Number of Logstash tasks to run."
  type        = number
  default     = 2
}

variable "beats_ingest_cidr_blocks" {
  description = "CIDR blocks allowed to ship logs to Logstash on port 5044."
  type        = list(string)
}

variable "service_namespace" {
  description = "Private DNS namespace for service discovery, for example elk.internal."
  type        = string
}

variable "log_retention_in_days" {
  description = "Retention for the service's CloudWatch log groups."
  type        = number
  default     = 365
}
