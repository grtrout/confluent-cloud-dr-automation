###############################################################################
# Bi-Directional Cluster Links
###############################################################################
# Establishes a bidirectional link for data replication between the East 
# and West Kafka clusters. The "east_to_west" link references the West cluster 
# as local and the East cluster as remote; "west_to_east" is the reverse.
###############################################################################

resource "confluent_cluster_link" "east_to_west" {
  link_name       = var.link_name
  link_mode       = "BIDIRECTIONAL"
  connection_mode = "INBOUND"

  local_kafka_cluster {
    id            = confluent_kafka_cluster.west_cluster.id
    rest_endpoint = confluent_kafka_cluster.west_cluster.rest_endpoint
    credentials {
      key    = confluent_api_key.admin_west_api_key.id
      secret = confluent_api_key.admin_west_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.east_cluster.id
    bootstrap_endpoint = confluent_kafka_cluster.east_cluster.bootstrap_endpoint
  }

  config = {
    "consumer.offset.sync.enable" = true
    "consumer.offset.sync.ms"     = var.consumer_offset_sync_ms
    "consumer.offset.group.filters" = jsonencode({
      groupFilters = [
        {
          name        = "*"
          patternType = "LITERAL"
          filterType  = "INCLUDE"
        }
      ]
    })
  }

}

resource "confluent_cluster_link" "west_to_east" {
  link_name       = var.link_name
  link_mode       = "BIDIRECTIONAL"

  local_kafka_cluster {
    id            = confluent_kafka_cluster.east_cluster.id
    rest_endpoint = confluent_kafka_cluster.east_cluster.rest_endpoint
    credentials {
      key    = confluent_api_key.admin_east_api_key.id
      secret = confluent_api_key.admin_east_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.west_cluster.id
    bootstrap_endpoint = confluent_kafka_cluster.west_cluster.bootstrap_endpoint
    credentials {
      key    = confluent_api_key.admin_west_api_key.id
      secret = confluent_api_key.admin_west_api_key.secret
    }
  }

  config = {
    "consumer.offset.sync.enable" = true
    "consumer.offset.sync.ms"     = var.consumer_offset_sync_ms
    "consumer.offset.group.filters" = jsonencode({
      groupFilters = [
        {
          name        = "*"
          patternType = "LITERAL"
          filterType  = "INCLUDE"
        }
      ]
    })
  }

  # Ensure the "east_to_west" link is established before creating the "west_to_east" link.
  depends_on = [
    confluent_cluster_link.east_to_west
  ]
}
