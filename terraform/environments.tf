###############################################################################
# Environments
###############################################################################
# Creates two distinct Confluent Cloud environments: "east-env" and "west-env".
# The stream_governance block assigns the governance package to "ADVANCED".
###############################################################################

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
