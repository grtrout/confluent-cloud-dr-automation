#!/usr/bin/env bash
#
# generate_envs.sh
# ---------------------------------------------------------
# This script automates retrieval of Terraform outputs
# and creates two env files: $PYTHON_DIR/east.env and $PYTHON_DIR/west.env
#
# Prerequisites:
#   - Ensure that `terraform apply` has been executed successfully in the
#     $TERRAFORM_DIR directory. This ensures the necessary outputs exist
#     and can be retrieved by this script.
#   - Exiting without activating an environment will not remove an existing .env file; 
#     any previously created or activated .env may still exist.
#
# Usage:
#   ./generate_envs.sh
#

set -e  # Exit on error

# Variables for directory paths
PARENT_DIR=$(pwd)
TERRAFORM_DIR="$PARENT_DIR/terraform"
PYTHON_DIR="$PARENT_DIR/python"
ENV_FILE="$PYTHON_DIR/.env"

# Configurable variables
CONSUMER_GROUP="demo-dr-consumer-group"
MESSAGE_INTERVAL="1.0"

# Ensure the Python directory exists
mkdir -p "$PYTHON_DIR"

# Function to parse Terraform outputs with soft validation
get_output() {
  local value=$(echo "$TF_OUTPUT_JSON" | jq -r ".$1.value")
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo -e "\n[WARNING] Missing Terraform output: $1. Using placeholder.\n" >&2
    value="<MISSING_VALUE>"
  fi
  echo "$value"
}

# Retrieve Terraform outputs in JSON
echo "[INFO] Retrieving Terraform outputs from $TERRAFORM_DIR..."
TF_OUTPUT_JSON=$(terraform -chdir="$TERRAFORM_DIR" output -json)

if [[ -z "$TF_OUTPUT_JSON" || "$TF_OUTPUT_JSON" == "{}" ]]; then
  echo "[ERROR] Terraform outputs are empty. Ensure 'terraform apply' has been run successfully in $TERRAFORM_DIR."
  exit 1
fi

# -----------------------------------------------------------------------------
# Parse environment variables from Terraform
# -----------------------------------------------------------------------------
EAST_BOOTSTRAP=$(get_output "east_kafka_cluster_bootstrap_url")
EAST_SASL_USERNAME=$(get_output "python_app_east_kafka_api_key_id")
EAST_SASL_PASSWORD=$(get_output "python_app_east_kafka_api_key_secret")
EAST_TOPIC_NAME=$(get_output "east_topic_name")
EAST_SCHEMA_REGISTRY_URL=$(get_output "east_env_schema_registry_endpoint")
EAST_SCHEMA_REGISTRY_API_KEY=$(get_output "python_app_east_sr_api_key_id")
EAST_SCHEMA_REGISTRY_API_SECRET=$(get_output "python_app_east_sr_api_key_secret")

WEST_BOOTSTRAP=$(get_output "west_kafka_cluster_bootstrap_url")
WEST_SASL_USERNAME=$(get_output "python_app_west_kafka_api_key_id")
WEST_SASL_PASSWORD=$(get_output "python_app_west_kafka_api_key_secret")
WEST_TOPIC_NAME=$(get_output "west_topic_name")
WEST_SCHEMA_REGISTRY_URL=$(get_output "west_env_schema_registry_endpoint")
WEST_SCHEMA_REGISTRY_API_KEY=$(get_output "python_app_west_sr_api_key_id")
WEST_SCHEMA_REGISTRY_API_SECRET=$(get_output "python_app_west_sr_api_key_secret")

# -----------------------------------------------------------------------------
# Write $PYTHON_DIR/east.env
# -----------------------------------------------------------------------------
cat <<EOF > "$PYTHON_DIR/east.env"
# .env for East Kafka cluster

# =============================================================================
# Consumer and Producer config
# =============================================================================
# Kafka Cluster Configuration
BOOTSTRAP_SERVER=$EAST_BOOTSTRAP
SASL_USERNAME=$EAST_SASL_USERNAME
SASL_PASSWORD=$EAST_SASL_PASSWORD
TOPIC_NAME=$EAST_TOPIC_NAME

# Schema Registry Configuration
SCHEMA_REGISTRY_URL=$EAST_SCHEMA_REGISTRY_URL
SCHEMA_REGISTRY_API_KEY=$EAST_SCHEMA_REGISTRY_API_KEY
SCHEMA_REGISTRY_API_SECRET=$EAST_SCHEMA_REGISTRY_API_SECRET

# =============================================================================
# Consumer config only
# =============================================================================
CONSUMER_GROUP=$CONSUMER_GROUP

# =============================================================================
# Producer config only
# =============================================================================
MESSAGE_INTERVAL=$MESSAGE_INTERVAL
EOF

# -----------------------------------------------------------------------------
# Write $PYTHON_DIR/west.env
# -----------------------------------------------------------------------------
cat <<EOF > "$PYTHON_DIR/west.env"
# .env for West Kafka cluster

# =============================================================================
# Consumer and Producer config
# =============================================================================
# Kafka Cluster Configuration
BOOTSTRAP_SERVER=$WEST_BOOTSTRAP
SASL_USERNAME=$WEST_SASL_USERNAME
SASL_PASSWORD=$WEST_SASL_PASSWORD
TOPIC_NAME=$WEST_TOPIC_NAME

# Schema Registry Configuration
SCHEMA_REGISTRY_URL=$WEST_SCHEMA_REGISTRY_URL
SCHEMA_REGISTRY_API_KEY=$WEST_SCHEMA_REGISTRY_API_KEY
SCHEMA_REGISTRY_API_SECRET=$WEST_SCHEMA_REGISTRY_API_SECRET

# =============================================================================
# Consumer config only
# =============================================================================
CONSUMER_GROUP=$CONSUMER_GROUP

# =============================================================================
# Producer config only
# =============================================================================
MESSAGE_INTERVAL=$MESSAGE_INTERVAL
EOF

echo -e "\n[INFO] Created $PYTHON_DIR/east.env and $PYTHON_DIR/west.env successfully.\n"

# -----------------------------------------------------------------------------
# Choose Environment for Activation
# -----------------------------------------------------------------------------
echo "Choose an environment to activate as .env:"
echo "1) EAST"
echo "2) WEST"
echo "3) Exit without activation"

echo -e "\n[INFO] Note: You can also run Python apps explicitly with environment parameters, which will override the activated .env file."
echo -e "Example: python avro_producer_app.py east or python avro_consumer_app.py west\n"

read -p "Enter your choice (1/2/3): " ENV_CHOICE

case "$ENV_CHOICE" in
  1)
    cp "$PYTHON_DIR/east.env" "$ENV_FILE"
    echo "[INFO] Activated east.env as .env."
    ;;
  2)
    cp "$PYTHON_DIR/west.env" "$ENV_FILE"
    echo "[INFO] Activated west.env as .env."
    ;;
  *)
    echo "[INFO] Exiting without activating any environment. Any previously activated .env file may still exist."
    ;;
esac

