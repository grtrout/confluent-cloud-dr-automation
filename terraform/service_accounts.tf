###############################################################################
# Service Accounts
###############################################################################
# Creates service accounts for administering each Kafka cluster and one 
# for the Python application.
###############################################################################

resource "confluent_service_account" "admin_kafka_east" {
  display_name = "admin-kafka-east-sa"
  description  = "Service account to manage the East Kafka cluster"
}

resource "confluent_service_account" "admin_kafka_west" {
  display_name = "admin-kafka-west-sa"
  description  = "Service account to manage the West Kafka cluster"
}

resource "confluent_service_account" "python_app" {
  display_name = "python-app-sa"
  description  = "Service account for producer and consumer applications"
}
