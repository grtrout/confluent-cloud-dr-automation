###############################################################################
# Terraform and Confluent Provider Configuration
###############################################################################
# Defines the Terraform provider for Confluent, specifying the required version
# and ensuring API credentials are securely provided via variables.

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

###############################################################################
# Environments Creation
###############################################################################
# Creates two distinct Confluent Cloud environments: "east-env" and "west-env".
# The stream_governance block assigns the governance package to "ADVANCED".

resource "confluent_environment" "east_env" {
  display_name = var.east_env_display_name

  stream_governance {
    package = var.stream_governance_package
  }
}

resource "confluent_environment" "west_env" {
  display_name = var.west_env_display_name

  stream_governance {
    package = var.stream_governance_package
  }
}

###############################################################################
# Kafka Clusters Creation
###############################################################################
# Provisions two single-zone Dedicated Kafka clusters (1 CKU each) in AWS regions
# us-east-2 (East) and us-west-2 (West), linked to their respective environments.

resource "confluent_kafka_cluster" "east_cluster" {
  display_name = var.east_cluster_display_name
  cloud        = var.cloud_provider
  region       = var.east_region
  availability = var.availability

  dedicated {
    cku = var.cku_east
  }

  environment {
    id = confluent_environment.east_env.id
  }
}

resource "confluent_kafka_cluster" "west_cluster" {
  display_name = var.west_cluster_display_name
  cloud        = var.cloud_provider
  region       = var.west_region
  availability = var.availability

  dedicated {
    cku = var.cku_west
  }

  environment {
    id = confluent_environment.west_env.id
  }
}

###############################################################################
# Schema Registry Configuration
###############################################################################
# Retrieves details about the Schema Registry instances automatically provisioned
# for each environment. These data sources fetch their IDs and endpoints.

resource "time_sleep" "wait_for_sr" {
  create_duration = "30s" # Delay for 30 seconds
}

data "confluent_schema_registry_cluster" "east_env_sr" {
  environment {
    id = confluent_environment.east_env.id
  }

  depends_on = [confluent_environment.east_env, time_sleep.wait_for_sr]
}

data "confluent_schema_registry_cluster" "west_env_sr" {
  environment {
    id = confluent_environment.west_env.id
  }

  depends_on = [confluent_environment.west_env, time_sleep.wait_for_sr]
}

###############################################################################
# Service Accounts Creation
###############################################################################
# Creates service accounts to manage each Kafka cluster. The display_name is used
# for identification, and the description provides additional context.

resource "confluent_service_account" "app_manager_east" {
  display_name = "app-manager-east-cluster"
  description  = "Service account to manage the East Kafka cluster"
}

resource "confluent_service_account" "app_manager_west" {
  display_name = "app-manager-west-cluster"
  description  = "Service account to manage the West Kafka cluster"
}

###############################################################################
# Cluster Admin Role Bindings
###############################################################################
# Binds each service account to the "CloudClusterAdmin" role for its corresponding
# Kafka cluster, granting administrative privileges.

resource "confluent_role_binding" "app_manager_east_admin" {
  principal   = "User:${confluent_service_account.app_manager_east.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.east_cluster.rbac_crn
}

resource "confluent_role_binding" "app_manager_west_admin" {
  principal   = "User:${confluent_service_account.app_manager_west.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.west_cluster.rbac_crn
}

###############################################################################
# Kafka API Keys Creation
###############################################################################
# Creates Kafka API keys for each cluster, allowing interaction through
# external processes or Terraform.

resource "confluent_api_key" "east_api_key" {
  display_name = "app-manager-east-cluster-api-key"
  description  = "Kafka API Key for East cluster"

  owner {
    id          = confluent_service_account.app_manager_east.id
    api_version = confluent_service_account.app_manager_east.api_version
    kind        = confluent_service_account.app_manager_east.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.east_cluster.id
    api_version = confluent_kafka_cluster.east_cluster.api_version
    kind        = confluent_kafka_cluster.east_cluster.kind

    environment {
      id = confluent_environment.east_env.id
    }
  }

  depends_on = [
    confluent_role_binding.app_manager_east_admin
  ]
}

resource "confluent_api_key" "west_api_key" {
  display_name = "app-manager-west-cluster-api-key"
  description  = "Kafka API Key for West cluster"

  owner {
    id          = confluent_service_account.app_manager_west.id
    api_version = confluent_service_account.app_manager_west.api_version
    kind        = confluent_service_account.app_manager_west.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.west_cluster.id
    api_version = confluent_kafka_cluster.west_cluster.api_version
    kind        = confluent_kafka_cluster.west_cluster.kind

    environment {
      id = confluent_environment.west_env.id
    }
  }

  depends_on = [
    confluent_role_binding.app_manager_west_admin
  ]
}

###############################################################################
# Schema Registry API Keys Creation
###############################################################################
# Creates API keys for accessing the Schema Registry instances in each environment.
# These keys are tied to the respective service account and Schema Registry instance.

resource "confluent_api_key" "east_sr_api_key" {
  display_name = "east-schema-registry-api-key"
  description  = "API Key for East Schema Registry"

  owner {
    id          = confluent_service_account.app_manager_east.id
    api_version = confluent_service_account.app_manager_east.api_version
    kind        = confluent_service_account.app_manager_east.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.east_env_sr.id
    api_version = data.confluent_schema_registry_cluster.east_env_sr.api_version
    kind        = data.confluent_schema_registry_cluster.east_env_sr.kind

    environment {
      id = confluent_environment.east_env.id
    }
  }

  depends_on = [
    data.confluent_schema_registry_cluster.east_env_sr,
    confluent_service_account.app_manager_east
  ]
}

resource "confluent_api_key" "west_sr_api_key" {
  display_name = "west-schema-registry-api-key"
  description  = "API Key for West Schema Registry"

  owner {
    id          = confluent_service_account.app_manager_west.id
    api_version = confluent_service_account.app_manager_west.api_version
    kind        = confluent_service_account.app_manager_west.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.west_env_sr.id
    api_version = data.confluent_schema_registry_cluster.west_env_sr.api_version
    kind        = data.confluent_schema_registry_cluster.west_env_sr.kind

    environment {
      id = confluent_environment.west_env.id
    }
  }

  depends_on = [
    data.confluent_schema_registry_cluster.west_env_sr,
    confluent_service_account.app_manager_west
  ]
}

###############################################################################
# Bi-Directional Cluster Link
###############################################################################
# Establishes a bidirectional link for data replication between the East and
# West Kafka clusters. The "east_to_west" link references the West cluster as
# local and the East cluster as remote. Similarly, "west_to_east" reverses the
# direction. These links enable seamless data flow between the two clusters.

resource "confluent_cluster_link" "east_to_west" {
  link_name       = var.link_name
  link_mode       = "BIDIRECTIONAL"
  connection_mode = "INBOUND"

  local_kafka_cluster {
    id            = confluent_kafka_cluster.west_cluster.id
    rest_endpoint = confluent_kafka_cluster.west_cluster.rest_endpoint
    credentials {
      key    = confluent_api_key.west_api_key.id
      secret = confluent_api_key.west_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.east_cluster.id
    bootstrap_endpoint = confluent_kafka_cluster.east_cluster.bootstrap_endpoint
  }
}

resource "confluent_cluster_link" "west_to_east" {
  link_name       = var.link_name
  link_mode       = "BIDIRECTIONAL"

  local_kafka_cluster {
    id            = confluent_kafka_cluster.east_cluster.id
    rest_endpoint = confluent_kafka_cluster.east_cluster.rest_endpoint
    credentials {
      key    = confluent_api_key.east_api_key.id
      secret = confluent_api_key.east_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.west_cluster.id
    bootstrap_endpoint = confluent_kafka_cluster.west_cluster.bootstrap_endpoint
    credentials {
      key    = confluent_api_key.west_api_key.id
      secret = confluent_api_key.west_api_key.secret
    }
  }

  # Ensure the "east_to_west" link is established before creating the "west_to_east" link.
  depends_on = [
    confluent_cluster_link.east_to_west
  ]
}

###############################################################################
# Source Topics in Each Cluster
###############################################################################
# Creates source topics in the East and West Kafka clusters. These topics are
# the origin points for data that will be mirrored to the opposite cluster.

resource "confluent_kafka_topic" "topic_east" {
  kafka_cluster {
    id = confluent_kafka_cluster.east_cluster.id
  }
  topic_name       = var.east_topic_name
  partitions_count = var.default_partition_count
  rest_endpoint    = confluent_kafka_cluster.east_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.east_api_key.id
    secret = confluent_api_key.east_api_key.secret
  }
}

resource "confluent_kafka_topic" "topic_west" {
  kafka_cluster {
    id = confluent_kafka_cluster.west_cluster.id
  }
  topic_name       = var.west_topic_name
  partitions_count = var.default_partition_count
  rest_endpoint    = confluent_kafka_cluster.west_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.west_api_key.id
    secret = confluent_api_key.west_api_key.secret
  }
}

###############################################################################
# Mirror Topics
###############################################################################
# Mirror topics replicate data from the source topics in one cluster to the
# other cluster. The topics are read-only in the destination cluster.

resource "confluent_kafka_mirror_topic" "from_east" {
  source_kafka_topic {
    topic_name = var.east_topic_name
  }
  cluster_link {
    link_name = confluent_cluster_link.east_to_west.link_name
  }
  kafka_cluster {
    id            = confluent_kafka_cluster.west_cluster.id
    rest_endpoint = confluent_kafka_cluster.west_cluster.rest_endpoint
    credentials {
      key    = confluent_api_key.west_api_key.id
      secret = confluent_api_key.west_api_key.secret
    }
  }

  depends_on = [
    confluent_cluster_link.east_to_west,
    confluent_cluster_link.west_to_east,
    confluent_kafka_topic.topic_east
  ]
}

resource "confluent_kafka_mirror_topic" "from_west" {
  source_kafka_topic {
    topic_name = var.west_topic_name
  }
  cluster_link {
    link_name = confluent_cluster_link.west_to_east.link_name
  }
  kafka_cluster {
    id            = confluent_kafka_cluster.east_cluster.id
    rest_endpoint = confluent_kafka_cluster.east_cluster.rest_endpoint
    credentials {
      key    = confluent_api_key.east_api_key.id
      secret = confluent_api_key.east_api_key.secret
    }
  }

  depends_on = [
    confluent_cluster_link.east_to_west,
    confluent_cluster_link.west_to_east,
    confluent_kafka_topic.topic_west
  ]
}
