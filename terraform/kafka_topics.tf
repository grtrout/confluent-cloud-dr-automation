###############################################################################
# Source Topics
###############################################################################
# Creates source topics in the East and West Kafka clusters. These topics 
# will be mirrored to the opposite cluster as read-only mirror topics.
###############################################################################

resource "confluent_kafka_topic" "topic_east" {
  kafka_cluster {
    id = confluent_kafka_cluster.east_cluster.id
  }
  topic_name       = var.east_topic_name
  partitions_count = var.default_partition_count
  rest_endpoint    = confluent_kafka_cluster.east_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.admin_east_api_key.id
    secret = confluent_api_key.admin_east_api_key.secret
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
    key    = confluent_api_key.admin_west_api_key.id
    secret = confluent_api_key.admin_west_api_key.secret
  }
}
