#!/usr/bin/env bash
#
# generate_envs.sh
#
# Purpose:
#   This script retrieves Terraform outputs and creates environment files for
#   East and West clusters: $PYTHON_DIR/east.env and $PYTHON_DIR/west.env.
#
# Prerequisites:
#   - terraform, confluent CLI, jq installed
#   - A successful 'terraform apply' so local Terraform state has valid outputs
#
# Usage:
#   ./generate_envs.sh
#

set -euo pipefail

###############################################################################
# Step 1: Define Directory Variables
###############################################################################
PARENT_DIR=$(pwd)
TERRAFORM_DIR="$PARENT_DIR/terraform"
PYTHON_DIR="$PARENT_DIR/python"
ENV_FILE="$PYTHON_DIR/.env"

# User-configurable defaults
CONSUMER_GROUP="demo-dr-consumer-group"
MESSAGE_INTERVAL="1.0"

# Ensure Python directory exists
mkdir -p "$PYTHON_DIR"

###############################################################################
# Step 2: Helper Function to Parse Terraform Outputs
###############################################################################
get_output() {
  local key="$1"
  local value
  value=$(echo "$TF_OUTPUT_JSON" | jq -r ".$key.value")

  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "[WARNING] Missing Terraform output: $key. Using placeholder." >&2
    value="<MISSING_VALUE>"
  fi
  echo "$value"
}

###############################################################################
# Step 3: Retrieve Terraform Outputs
###############################################################################
echo "[INFO] Retrieving Terraform outputs from $TERRAFORM_DIR..."
TF_OUTPUT_JSON=$(terraform -chdir="$TERRAFORM_DIR" output -json 2>/dev/null || true)

if [[ -z "$TF_OUTPUT_JSON" || "$TF_OUTPUT_JSON" == "{}" ]]; then
  echo "[ERROR] Terraform outputs are empty or invalid. Ensure 'terraform apply' was successful."
  exit 1
fi

###############################################################################
# Step 4: Parse Environment Variables from Terraform
###############################################################################
# East cluster info
EAST_BOOTSTRAP=$(get_output "east_kafka_cluster_bootstrap_url")
EAST_SASL_USERNAME=$(get_output "python_app_east_kafka_api_key_id")
EAST_SASL_PASSWORD=$(get_output "python_app_east_kafka_api_key_secret")
EAST_TOPIC_NAME=$(get_output "east_topic_name")  # Reuse East topic for West mirror
EAST_SCHEMA_REGISTRY_URL=$(get_output "east_env_schema_registry_endpoint")
EAST_SCHEMA_REGISTRY_API_KEY=$(get_output "python_app_east_sr_api_key_id")
EAST_SCHEMA_REGISTRY_API_SECRET=$(get_output "python_app_east_sr_api_key_secret")

# West cluster info
WEST_BOOTSTRAP=$(get_output "west_kafka_cluster_bootstrap_url")
WEST_SASL_USERNAME=$(get_output "python_app_west_kafka_api_key_id")
WEST_SASL_PASSWORD=$(get_output "python_app_west_kafka_api_key_secret")
WEST_SCHEMA_REGISTRY_URL=$(get_output "west_env_schema_registry_endpoint")
WEST_SCHEMA_REGISTRY_API_KEY=$(get_output "python_app_west_sr_api_key_id")
WEST_SCHEMA_REGISTRY_API_SECRET=$(get_output "python_app_west_sr_api_key_secret")

###############################################################################
# Step 5: Create east.env
###############################################################################
cat <<EOF > "$PYTHON_DIR/east.env"
# .env for East Kafka cluster

# =============================================================================
# Kafka Cluster Configuration
# =============================================================================
BOOTSTRAP_SERVER=$EAST_BOOTSTRAP
SASL_USERNAME=$EAST_SASL_USERNAME
SASL_PASSWORD=$EAST_SASL_PASSWORD
TOPIC_NAME=$EAST_TOPIC_NAME

# =============================================================================
# Schema Registry Configuration
# =============================================================================
SCHEMA_REGISTRY_URL=$EAST_SCHEMA_REGISTRY_URL
SCHEMA_REGISTRY_API_KEY=$EAST_SCHEMA_REGISTRY_API_KEY
SCHEMA_REGISTRY_API_SECRET=$EAST_SCHEMA_REGISTRY_API_SECRET

# =============================================================================
# Consumer Configuration
# =============================================================================
CONSUMER_GROUP=$CONSUMER_GROUP

# =============================================================================
# Producer Configuration
# =============================================================================
MESSAGE_INTERVAL=$MESSAGE_INTERVAL
EOF

echo "[INFO] Created $PYTHON_DIR/east.env"

###############################################################################
# Step 6: Create west.env
###############################################################################
cat <<EOF > "$PYTHON_DIR/west.env"
# .env for West Kafka cluster

# =============================================================================
# Kafka Cluster Configuration
# =============================================================================
BOOTSTRAP_SERVER=$WEST_BOOTSTRAP
SASL_USERNAME=$WEST_SASL_USERNAME
SASL_PASSWORD=$WEST_SASL_PASSWORD
TOPIC_NAME=$EAST_TOPIC_NAME  # Same East topic name, mirrored in West

# =============================================================================
# Schema Registry Configuration
# =============================================================================
SCHEMA_REGISTRY_URL=$WEST_SCHEMA_REGISTRY_URL
SCHEMA_REGISTRY_API_KEY=$WEST_SCHEMA_REGISTRY_API_KEY
SCHEMA_REGISTRY_API_SECRET=$WEST_SCHEMA_REGISTRY_API_SECRET

# =============================================================================
# Consumer Configuration
# =============================================================================
CONSUMER_GROUP=$CONSUMER_GROUP

# =============================================================================
# Producer Configuration
# =============================================================================
MESSAGE_INTERVAL=$MESSAGE_INTERVAL
EOF

echo "[INFO] Created $PYTHON_DIR/west.env"

###############################################################################
# Step 7: Optionally Activate Environment
###############################################################################
echo -e "\n[INFO] Environment files generated successfully."
echo "Choose an environment to activate as .env (or skip):"
echo "1) EAST"
echo "2) WEST"
echo "3) Exit without activation"
read -p "Enter choice (1/2/3): " ENV_CHOICE

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
    echo "[INFO] No environment activated. Any previously activated .env remains."
    ;;
esac

echo "[INFO] Done."
