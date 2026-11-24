variable "region" {
  description = "AWS region to deploy the ELK stack into."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Owner tag applied to every resource via provider default_tags."
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Environment tag applied to every resource via provider default_tags."
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Prefix used for all resource names in this stack."
  type        = string
  default     = "elk"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC hosting the ELK stack."
  type        = string
  default     = "10.60.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread private subnets and OpenSearch data nodes across."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 to match OpenSearch zone awareness options."
  }
}

variable "domain_name" {
  description = "Name of the Amazon OpenSearch Service domain (Elasticsearch + Kibana/Dashboards)."
  type        = string
  default     = "elk-domain"
}

variable "engine_version" {
  description = "OpenSearch engine version for the domain."
  type        = string
  default     = "OpenSearch_2.13"
}

variable "data_instance_type" {
  description = "Instance type for OpenSearch data nodes."
  type        = string
  default     = "r6g.large.search"
}

variable "data_instance_count" {
  description = "Number of OpenSearch data nodes. Must be a multiple of az_count for even shard distribution."
  type        = number
  default     = 3
}

variable "master_instance_type" {
  description = "Instance type for OpenSearch dedicated master nodes."
  type        = string
  default     = "r6g.large.search"
}

variable "master_instance_count" {
  description = "Number of dedicated master nodes. Use 3 for a quorum."
  type        = number
  default     = 3
}

variable "data_volume_size" {
  description = "EBS volume size in GiB attached to each OpenSearch data node."
  type        = number
  default     = 100
}

variable "log_retention_days" {
  description = "Retention in days for all CloudWatch log groups in this stack."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 365
    error_message = "Platform policy requires CloudWatch log retention of at least 365 days."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the stack KMS key is deleted."
  type        = number
  default     = 30
}

variable "logstash_image_tag" {
  description = "Tag of the Logstash image in the stack ECR repository. Mirror the upstream Elastic image into this repository before deploying."
  type        = string
  default     = "8.15.3"
}

variable "logstash_desired_count" {
  description = "Number of Logstash tasks to run on Fargate."
  type        = number
  default     = 2
}

variable "logstash_cpu" {
  description = "Fargate CPU units for each Logstash task."
  type        = number
  default     = 1024
}

variable "logstash_memory" {
  description = "Fargate memory (MiB) for each Logstash task."
  type        = number
  default     = 2048
}

variable "beats_port" {
  description = "TCP port Logstash listens on for the Beats input."
  type        = number
  default     = 5044
}
