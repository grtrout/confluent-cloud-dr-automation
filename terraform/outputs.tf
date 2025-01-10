###############################################################################
# Outputs Configuration
###############################################################################
# This file defines all the outputs that will be displayed after running
# `terraform apply`. These outputs provide essential information about the
# resources created, including IDs, endpoints, API keys, and secrets
# Sensitive outputs (like API secrets) are marked accordingly to prevent
# accidental exposure
###############################################################################

#######################################
# Environments Outputs
#######################################

output "east_environment_display_name" {
  description = "Display name of the East Confluent Cloud environment"
  value       = confluent_environment.east_env.display_name
}

output "east_environment_id" {
  description = "Environment ID for the East Confluent Cloud environment"
  value       = confluent_environment.east_env.id
}

output "west_environment_display_name" {
  description = "Display name of the West Confluent Cloud environment"
  value       = confluent_environment.west_env.display_name
}

output "west_environment_id" {
  description = "Environment ID for the West Confluent Cloud environment"
  value       = confluent_environment.west_env.id
}

#######################################
# Schema Registry Outputs
#######################################

output "east_env_schema_registry_id" {
  description = "Schema Registry ID for the East environment"
  value       = data.confluent_schema_registry_cluster.east_env_sr.id
}

output "east_env_schema_registry_endpoint" {
  description = "Schema Registry endpoint URL for the East environment"
  value       = data.confluent_schema_registry_cluster.east_env_sr.rest_endpoint
}

output "west_env_schema_registry_id" {
  description = "Schema Registry ID for the West environment"
  value       = data.confluent_schema_registry_cluster.west_env_sr.id
}

output "west_env_schema_registry_endpoint" {
  description = "Schema Registry endpoint URL for the West environment"
  value       = data.confluent_schema_registry_cluster.west_env_sr.rest_endpoint
}

#######################################
# Schema Registry API Keys Outputs
#######################################

output "east_sr_api_key_id" {
  description = "API Key ID for the East Schema Registry"
  value       = confluent_api_key.east_sr_api_key.id
}

output "east_sr_api_key_secret" {
  description = "API Key Secret for the East Schema Registry"
  value       = confluent_api_key.east_sr_api_key.secret
  sensitive   = true
}

output "west_sr_api_key_id" {
  description = "API Key ID for the West Schema Registry"
  value       = confluent_api_key.west_sr_api_key.id
}

output "west_sr_api_key_secret" {
  description = "API Key Secret for the West Schema Registry"
  value       = confluent_api_key.west_sr_api_key.secret
  sensitive   = true
}

#######################################
# Kafka Clusters Outputs
#######################################

output "east_cluster_display_name" {
  description = "Display name of the East Kafka cluster"
  value       = confluent_kafka_cluster.east_cluster.display_name
}

output "east_cluster_id" {
  description = "Kafka Cluster ID for the East Kafka cluster"
  value       = confluent_kafka_cluster.east_cluster.id
}

output "east_cluster_rest_endpoint" {
  description = "REST endpoint URL of the East Kafka cluster"
  value       = confluent_kafka_cluster.east_cluster.rest_endpoint
}

output "west_cluster_display_name" {
  description = "Display name of the West Kafka cluster"
  value       = confluent_kafka_cluster.west_cluster.display_name
}

output "west_cluster_id" {
  description = "Kafka Cluster ID for the West Kafka cluster"
  value       = confluent_kafka_cluster.west_cluster.id
}

output "west_cluster_rest_endpoint" {
  description = "REST endpoint URL of the West Kafka cluster"
  value       = confluent_kafka_cluster.west_cluster.rest_endpoint
}

#######################################
# Service Accounts Outputs
#######################################

output "east_service_account_id" {
  description = "Service Account ID managing the East Kafka cluster"
  value       = confluent_service_account.app_manager_east.id
}

output "west_service_account_id" {
  description = "Service Account ID managing the West Kafka cluster"
  value       = confluent_service_account.app_manager_west.id
}

#######################################
# API Keys Outputs
#######################################

output "east_api_key_id" {
  description = "API Key ID for the East cluster's service account"
  value       = confluent_api_key.east_api_key.id
}

output "east_api_key_secret" {
  description = "API Key Secret for the East cluster's service account"
  value       = confluent_api_key.east_api_key.secret
  sensitive   = true
}

output "west_api_key_id" {
  description = "API Key ID for the West cluster's service account"
  value       = confluent_api_key.west_api_key.id
}

output "west_api_key_secret" {
  description = "API Key Secret for the West cluster's service account"
  value       = confluent_api_key.west_api_key.secret
  sensitive   = true
}

#######################################
# Cluster Links Outputs
#######################################

output "cluster_link_east_to_west_name" {
  description = "Name of the bidirectional cluster link from East to West"
  value       = confluent_cluster_link.east_to_west.link_name
}

output "cluster_link_west_to_east_name" {
  description = "Name of the bidirectional cluster link from West to East"
  value       = confluent_cluster_link.west_to_east.link_name
}

#######################################
# Kafka Topics Outputs
#######################################

output "east_topic_name" {
  description = "Name of the source Kafka topic in the East cluster"
  value       = confluent_kafka_topic.topic_east.topic_name
}

output "west_topic_name" {
  description = "Name of the source Kafka topic in the West cluster"
  value       = confluent_kafka_topic.topic_west.topic_name
}

#######################################
# Mirror Topics Outputs
#######################################

output "mirror_topic_from_east_name" {
  description = "Name of the mirror topic in the West cluster that mirrors the East source topic"
  value       = confluent_kafka_mirror_topic.from_east.mirror_topic_name
}

output "mirror_topic_from_west_name" {
  description = "Name of the mirror topic in the East cluster that mirrors the West source topic"
  value       = confluent_kafka_mirror_topic.from_west.mirror_topic_name
}
