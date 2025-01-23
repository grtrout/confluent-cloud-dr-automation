###############################################################################
# Kafka Clusters
###############################################################################
# Provisions two single-zone Dedicated Kafka clusters (1 CKU each) in AWS 
# regions us-east-2 (East) and us-west-2 (West). Each cluster is linked to 
# its respective environment.
###############################################################################

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
