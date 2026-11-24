variable "region" {
  description = "AWS region that hosts the ELK stack."
  type        = string
  default     = "us-east-1"
}

variable "replica_region" {
  description = "AWS region that holds the cross-region replica of the archive bucket."
  type        = string
  default     = "us-west-2"
}

variable "name_prefix" {
  description = "Prefix applied to the names of all resources in this stack."
  type        = string
  default     = "elk"
}

variable "environment" {
  description = "Environment name, applied as the `environment` tag on every resource."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owning team, applied as the `owner` tag on every resource."
  type        = string
  default     = "platform-engineering"
}

variable "vpc_cidr" {
  description = "CIDR block for the ELK VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread the stack across. OpenSearch zone awareness requires 3."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count == 3
    error_message = "This stack pins zone awareness to 3 availability zones; az_count must be 3."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before a scheduled KMS key deletion takes effect."
  type        = number
  default     = 30
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention. Platform policy requires at least 365 days."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_in_days >= 365
    error_message = "log_retention_in_days must be at least 365 to satisfy platform policy."
  }
}

# --- OpenSearch (Elasticsearch + Kibana/Dashboards) ---------------------------

variable "opensearch_engine_version" {
  description = "OpenSearch engine version for the domain."
  type        = string
  default     = "OpenSearch_2.11"
}

variable "opensearch_data_instance_type" {
  description = "Instance type for OpenSearch data nodes."
  type        = string
  default     = "r6g.large.search"
}

variable "opensearch_data_instance_count" {
  description = "Number of OpenSearch data nodes. Must be a multiple of the AZ count."
  type        = number
  default     = 3
}

variable "opensearch_master_instance_type" {
  description = "Instance type for the three dedicated OpenSearch master nodes."
  type        = string
  default     = "m6g.large.search"
}

variable "opensearch_volume_size" {
  description = "EBS volume size in GiB attached to each OpenSearch data node."
  type        = number
  default     = 100
}

variable "opensearch_master_user_name" {
  description = "Username of the OpenSearch Dashboards master user in the internal user database."
  type        = string
  default     = "elk-admin"
}

variable "dashboards_admin_principal_arns" {
  description = "IAM principals allowed to assume the OpenSearch domain access role. Defaults to the account root when empty."
  type        = list(string)
  default     = []
}

variable "opensearch_client_cidr_blocks" {
  description = "Extra CIDR blocks allowed to reach the OpenSearch HTTPS endpoint, for example a VPN range. Defaults to the VPC CIDR when empty."
  type        = list(string)
  default     = []
}

# --- Logstash -----------------------------------------------------------------

variable "logstash_image_tag" {
  description = "Immutable image tag for the Logstash image in the stack ECR repository."
  type        = string
  default     = "1.0.0"
}

variable "logstash_task_cpu" {
  description = "Fargate CPU units for each Logstash task."
  type        = number
  default     = 1024
}

variable "logstash_task_memory" {
  description = "Fargate memory (MiB) for each Logstash task."
  type        = number
  default     = 2048
}

variable "logstash_desired_count" {
  description = "Number of Logstash tasks to run."
  type        = number
  default     = 2
}

variable "beats_ingest_cidr_blocks" {
  description = "CIDR blocks allowed to ship logs to Logstash on port 5044. Defaults to the VPC CIDR when empty."
  type        = list(string)
  default     = []
}
