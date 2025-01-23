###############################################################################
# Schema Registry
###############################################################################
# Retrieves details about the Schema Registry instances automatically 
# provisioned for each environment. Includes a time_sleep resource to wait 
# for them to be fully provisioned before fetching details.
###############################################################################

resource "time_sleep" "wait_for_sr" {
  create_duration = "30s" # Delay for 30 seconds
}

data "confluent_schema_registry_cluster" "east_env_sr" {
  environment {
    id = confluent_environment.east_env.id
  }

  depends_on = [
    confluent_environment.east_env, 
    time_sleep.wait_for_sr
  ]
}

data "confluent_schema_registry_cluster" "west_env_sr" {
  environment {
    id = confluent_environment.west_env.id
  }

  depends_on = [
    confluent_environment.west_env, 
    time_sleep.wait_for_sr
  ]
}
