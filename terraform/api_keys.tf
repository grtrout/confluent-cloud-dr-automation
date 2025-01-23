###############################################################################
# API Keys
###############################################################################
# This file includes both Admin (cluster) API keys and Python app API keys 
# for Kafka and Schema Registry.
###############################################################################

# ------------------------
# Admin Kafka API Keys
# ------------------------
resource "confluent_api_key" "admin_east_api_key" {
  display_name = "admin-kafka-east-cluster-api-key"
  description  = "Admin Kafka API Key for East cluster"

  owner {
    id          = confluent_service_account.admin_kafka_east.id
    api_version = confluent_service_account.admin_kafka_east.api_version
    kind        = confluent_service_account.admin_kafka_east.kind
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
    confluent_role_binding.admin_kafka_east_admin
  ]
}

resource "confluent_api_key" "admin_west_api_key" {
  display_name = "admin-kafka-west-cluster-api-key"
  description  = "Admin Kafka API Key for West cluster"

  owner {
    id          = confluent_service_account.admin_kafka_west.id
    api_version = confluent_service_account.admin_kafka_west.api_version
    kind        = confluent_service_account.admin_kafka_west.kind
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
    confluent_role_binding.admin_kafka_west_admin
  ]
}

# ------------------------
# Python App Kafka API Keys
# ------------------------
resource "confluent_api_key" "python_app_east_kafka_api_key" {
  display_name = "python-app-east-kafka-api-key"
  description  = "Kafka API Key for Python app in East cluster"

  owner {
    id          = confluent_service_account.python_app.id
    api_version = confluent_service_account.python_app.api_version
    kind        = confluent_service_account.python_app.kind
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
    confluent_service_account.python_app
  ]
}

resource "confluent_api_key" "python_app_west_kafka_api_key" {
  display_name = "python-app-west-kafka-api-key"
  description  = "Kafka API Key for Python app in West cluster"

  owner {
    id          = confluent_service_account.python_app.id
    api_version = confluent_service_account.python_app.api_version
    kind        = confluent_service_account.python_app.kind
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
    confluent_service_account.python_app
  ]
}

# ------------------------
# Python App Schema Registry API Keys
# ------------------------
resource "confluent_api_key" "python_app_east_sr_api_key" {
  display_name = "python-app-east-sr-api-key"
  description  = "Schema Registry API Key for Python app in East cluster"

  owner {
    id          = confluent_service_account.python_app.id
    api_version = confluent_service_account.python_app.api_version
    kind        = confluent_service_account.python_app.kind
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
    confluent_service_account.python_app
  ]
}

resource "confluent_api_key" "python_app_west_sr_api_key" {
  display_name = "python-app-west-sr-api-key"
  description  = "Schema Registry API Key for Python app in West cluster"

  owner {
    id          = confluent_service_account.python_app.id
    api_version = confluent_service_account.python_app.api_version
    kind        = confluent_service_account.python_app.kind
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
    confluent_service_account.python_app
  ]
}
