###############################################################################
# Providers Configuration
###############################################################################
# This file configures Terraform itself and any providers (like Confluent).
# It ensures the correct provider versions are used and sets up global provider 
# credentials if needed.
###############################################################################

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.12.0"
    }
  }
}

provider "confluent" {
  # API credentials for Confluent Cloud must be supplied by a user or pipeline
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}
