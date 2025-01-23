###############################################################################
# Mirror Topics
###############################################################################
# Mirror topics replicate data from the source topics in one cluster to the 
# other cluster. These topics are read-only in the destination cluster.
###############################################################################

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
      key    = confluent_api_key.admin_west_api_key.id
      secret = confluent_api_key.admin_west_api_key.secret
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
      key    = confluent_api_key.admin_east_api_key.id
      secret = confluent_api_key.admin_east_api_key.secret
    }
  }

  depends_on = [
    confluent_cluster_link.east_to_west,
    confluent_cluster_link.west_to_east,
    confluent_kafka_topic.topic_west
  ]
}
