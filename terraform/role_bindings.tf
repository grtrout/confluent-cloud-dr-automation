###############################################################################
# Role Bindings (RBAC)
###############################################################################
# Binds each service account to appropriate roles:
#   - CloudClusterAdmin for the cluster admin accounts
#   - DeveloperRead/DeveloperWrite for the Python App
###############################################################################

# ------------------------
# Admin Role Bindings
# ------------------------
resource "confluent_role_binding" "admin_kafka_east_admin" {
  principal   = "User:${confluent_service_account.admin_kafka_east.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.east_cluster.rbac_crn
}

resource "confluent_role_binding" "admin_kafka_west_admin" {
  principal   = "User:${confluent_service_account.admin_kafka_west.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.west_cluster.rbac_crn
}

# ------------------------
# Python App Role Bindings
# ------------------------
# Kafka Topics - East
resource "confluent_role_binding" "python_app_east_topic_read_topics" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.east_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.east_cluster.id}/topic=*"

  depends_on = [
    confluent_api_key.python_app_east_kafka_api_key
  ]
}

resource "confluent_role_binding" "python_app_east_topic_read_groups" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.east_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.east_cluster.id}/group=*"

  depends_on = [
    confluent_api_key.python_app_east_kafka_api_key
  ]
}

resource "confluent_role_binding" "python_app_east_topic_write_topics" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.east_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.east_cluster.id}/topic=*"

  depends_on = [
    confluent_api_key.python_app_east_kafka_api_key
  ]
}

# Kafka Topics - West
resource "confluent_role_binding" "python_app_west_topic_read_topics" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.west_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.west_cluster.id}/topic=*"

  depends_on = [
    confluent_api_key.python_app_west_kafka_api_key
  ]
}

resource "confluent_role_binding" "python_app_west_topic_read_groups" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.west_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.west_cluster.id}/group=*"

  depends_on = [
    confluent_api_key.python_app_west_kafka_api_key
  ]
}

resource "confluent_role_binding" "python_app_west_topic_write_topics" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.west_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.west_cluster.id}/topic=*"

  depends_on = [
    confluent_api_key.python_app_west_kafka_api_key
  ]
}

# Schema Registry - East
resource "confluent_role_binding" "python_app_east_sr_read" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.east_env_sr.resource_name}/subject=*"

  depends_on = [
    confluent_api_key.python_app_east_sr_api_key
  ]
}

resource "confluent_role_binding" "python_app_east_sr_write" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.east_env_sr.resource_name}/subject=*"

  depends_on = [
    confluent_api_key.python_app_east_sr_api_key
  ]
}

resource "confluent_role_binding" "python_app_east_sr_manage" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperManage"
  crn_pattern = "${data.confluent_schema_registry_cluster.east_env_sr.resource_name}/subject=*"

  depends_on = [
    confluent_api_key.python_app_east_sr_api_key
  ]
}

# Schema Registry - West
resource "confluent_role_binding" "python_app_west_sr_read" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.west_env_sr.resource_name}/subject=*"

  depends_on = [
    confluent_api_key.python_app_west_sr_api_key
  ]
}

resource "confluent_role_binding" "python_app_west_sr_write" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.west_env_sr.resource_name}/subject=*"

  depends_on = [
    confluent_api_key.python_app_west_sr_api_key
  ]
}

resource "confluent_role_binding" "python_app_west_sr_manage" {
  principal   = "User:${confluent_service_account.python_app.id}"
  role_name   = "DeveloperManage"
  crn_pattern = "${data.confluent_schema_registry_cluster.west_env_sr.resource_name}/subject=*"

  depends_on = [
    confluent_api_key.python_app_west_sr_api_key
  ]
}
