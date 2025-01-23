###############################################################################
# Variables Declaration
###############################################################################
# This file defines all variables used throughout the Terraform configuration.
# Variables with default values represent current resource settings. 
# Sensitive variables are marked to prevent accidental exposure.
###############################################################################

# Confluent Cloud API Credentials
variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key with OrgAdmin or similar privileges."
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret."
  type        = string
  sensitive   = true
}

###############################################################################
# Environment Configuration
###############################################################################
variable "east_env_display_name" {
  description = "Display name for the East Confluent Cloud environment."
  type        = string
  default     = "east-env"
}

variable "west_env_display_name" {
  description = "Display name for the West Confluent Cloud environment."
  type        = string
  default     = "west-env"
}

variable "stream_governance_package" {
  description = "Stream Governance package type (e.g., STANDARD, ADVANCED)."
  type        = string
  default     = "ADVANCED"
}

###############################################################################
# Kafka Cluster Configuration
###############################################################################
variable "cloud_provider" {
  description = "Cloud provider for Kafka clusters (e.g., AWS, GCP, AZURE)."
  type        = string
  default     = "AWS"
}

variable "east_region" {
  description = "Cloud region for the East Kafka cluster."
  type        = string
  default     = "us-east-2"
}

variable "west_region" {
  description = "Cloud region for the West Kafka cluster."
  type        = string
  default     = "us-west-2"
}

variable "availability" {
  description = "Availability zone configuration (SINGLE_ZONE or MULTI_ZONE)."
  type        = string
  default     = "SINGLE_ZONE"
}

variable "east_cluster_display_name" {
  description = "Display name for the East Kafka cluster."
  type        = string
  default     = "east-cluster"
}

variable "west_cluster_display_name" {
  description = "Display name for the West Kafka cluster."
  type        = string
  default     = "west-cluster"
}

variable "cku_east" {
  description = "Number of CKUs allocated to the East dedicated cluster."
  type        = number
  default     = 1
}

variable "cku_west" {
  description = "Number of CKUs allocated to the West dedicated cluster."
  type        = number
  default     = 1
}

###############################################################################
# Cluster Link Configuration
###############################################################################
variable "link_name" {
  description = "Name for the bidirectional cluster link."
  type        = string
  default     = "bidirectional-link"
}

###############################################################################
# Kafka Topics Configuration
###############################################################################
variable "east_topic_name" {
  description = "Name of the source topic in the East Kafka cluster."
  type        = string
  default     = "public.topic-on-east"
}

variable "west_topic_name" {
  description = "Name of the source topic in the West Kafka cluster."
  type        = string
  default     = "public.topic-on-west"
}

variable "default_partition_count" {
  description = "Number of partitions for new Kafka topics."
  type        = number
  default     = 3
}
