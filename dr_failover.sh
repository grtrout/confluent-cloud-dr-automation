#!/usr/bin/env bash
#
# dr_failover.sh
#
# Purpose:
#   Conduct failover from East → West. Allows either a graceful approach
#   (reverse-and-start) or a forced approach (mirror failover).
#
# Prerequisites:
#   - terraform, confluent CLI, jq installed
#   - A successful 'terraform apply' so local Terraform state has valid outputs
#   - Confluent CLI logged in (confluent login)
#   - East cluster generally reachable unless you truly want forced
#
# Usage:
#   ./dr_failover.sh
#
# Key Steps:
#   1) Validate East and West cluster IDs, environment IDs via Terraform outputs
#   2) Prompt user: graceful or forced?
#       - Graceful → attempt reverse-and-start first
#         If that fails, prompt user about forcibly failing over
#       - Forced → skip reverse, run mirror failover immediately
#   3) Inform user to re-point producers/consumers to West
#

set -euo pipefail

###############################################################################
# Step 1: Retrieve Terraform Outputs
###############################################################################
echo "[INFO] Retrieving Terraform outputs (terraform -chdir=./terraform output -json)..."
TF_OUTPUT_JSON=$(terraform -chdir=./terraform output -json 2>/dev/null || true)

if [[ -z "$TF_OUTPUT_JSON" || "$TF_OUTPUT_JSON" == "{}" ]]; then
  echo "[ERROR] Terraform outputs are empty or invalid. Ensure 'terraform apply' was successful."
  exit 1
fi

# Parse East environment/cluster
EAST_ENV_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_environment_id.value')
EAST_CLUSTER_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_kafka_cluster_id.value')

# Parse West environment/cluster
WEST_ENV_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.west_environment_id.value')
WEST_CLUSTER_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.west_kafka_cluster_id.value')

# Parse Link Name and East Topic
LINK_NAME=$(echo "$TF_OUTPUT_JSON" | jq -r '.cluster_link_east_to_west_name.value')
TOPIC_ON_EAST=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_topic_name.value')

###############################################################################
# Step 2: Basic Checks
###############################################################################
if [[ -z "$EAST_ENV_ID" || "$EAST_ENV_ID" == "null" ]]; then
  echo "[ERROR] Missing east_environment_id in Terraform outputs."
  exit 1
fi
if [[ -z "$EAST_CLUSTER_ID" || "$EAST_CLUSTER_ID" == "null" ]]; then
  echo "[ERROR] Missing east_kafka_cluster_id in Terraform outputs."
  exit 1
fi
if [[ -z "$WEST_ENV_ID" || "$WEST_ENV_ID" == "null" ]]; then
  echo "[ERROR] Missing west_environment_id in Terraform outputs."
  exit 1
fi
if [[ -z "$WEST_CLUSTER_ID" || "$WEST_CLUSTER_ID" == "null" ]]; then
  echo "[ERROR] Missing west_kafka_cluster_id in Terraform outputs."
  exit 1
fi
if [[ -z "$LINK_NAME" || "$LINK_NAME" == "null" ]]; then
  echo "[ERROR] Missing cluster link name in Terraform outputs."
  exit 1
fi
if [[ -z "$TOPIC_ON_EAST" || "$TOPIC_ON_EAST" == "null" ]]; then
  echo "[ERROR] Missing east_topic_name in Terraform outputs."
  exit 1
fi

###############################################################################
# Step 3: Prompt for Failover Mode (Graceful vs. Forced)
###############################################################################
cat <<MODES

====================================
 DR Failover: East → West
====================================

Select a failover mode:
 1) Graceful Failover
    - Attempt reverse-and-start mirror on the East topic.
    - If that fails, optionally do forced failover.
 2) Forced Failover
    - Skip reverse, forcibly fail over immediately.

MODES

read -p "Enter choice (1=Graceful, 2=Forced): " FAILOVER_MODE
echo

###############################################################################
# Step 4: Execute Failover Logic
###############################################################################
if [[ "$FAILOVER_MODE" == "1" ]]; then
  # Graceful approach
  echo "[INFO] Attempting graceful failover (reverse-and-start) for topic '$TOPIC_ON_EAST'..."
  echo "Command: confluent kafka mirror reverse-and-start $TOPIC_ON_EAST --link $LINK_NAME --cluster $WEST_CLUSTER_ID --environment $WEST_ENV_ID"

  set +e  # Allow errors
  confluent kafka mirror reverse-and-start "$TOPIC_ON_EAST" \
    --link "$LINK_NAME" \
    --cluster "$WEST_CLUSTER_ID" \
    --environment "$WEST_ENV_ID"
  REVERSE_EXIT_CODE=$?
  set -e

  if [[ $REVERSE_EXIT_CODE -ne 0 ]]; then
    echo "[WARN] reverse-and-start mirror failed. East might be unreachable or partially down."
    echo "Would you like to forcibly fail over '$TOPIC_ON_EAST'? (y/n)"
    read -r FORCED_ASK
    if [[ "$FORCED_ASK" =~ ^[Yy]$ ]]; then
      echo "Command: confluent kafka mirror failover $TOPIC_ON_EAST --link $LINK_NAME --cluster $WEST_CLUSTER_ID --environment $WEST_ENV_ID"
      confluent kafka mirror failover "$TOPIC_ON_EAST" \
        --link "$LINK_NAME" \
        --cluster "$WEST_CLUSTER_ID" \
        --environment "$WEST_ENV_ID"
      echo "[INFO] Forced failover completed."
    else
      echo "[INFO] Exiting without forced failover."
      exit 0
    fi
  else
    echo "[INFO] Reverse-and-start mirror succeeded for topic '$TOPIC_ON_EAST'."
  fi

elif [[ "$FAILOVER_MODE" == "2" ]]; then
  # Forced approach
  echo "[INFO] Performing forced failover on topic '$TOPIC_ON_EAST'. Skipping reverse."
  echo "Command: confluent kafka mirror failover $TOPIC_ON_EAST --link $LINK_NAME --cluster $WEST_CLUSTER_ID --environment $WEST_ENV_ID"
  confluent kafka mirror failover "$TOPIC_ON_EAST" \
    --link "$LINK_NAME" \
    --cluster "$WEST_CLUSTER_ID" \
    --environment "$WEST_ENV_ID"
  echo "[INFO] Forced failover completed."

else
  echo "[ERROR] Invalid choice. Exiting."
  exit 1
fi

###############################################################################
# Step 5: Instruct User to Re-point to West
###############################################################################
cat <<EOF

[INFO] East → West failover complete for topic "$TOPIC_ON_EAST".

Next steps:
  1) Re-point your producer/consumer to West:
     cd python
     python avro_producer_app.py west
     python avro_consumer_app.py west

  2) Validate failover:
     confluent kafka mirror list --cluster "$WEST_CLUSTER_ID" --environment "$WEST_ENV_ID"
     # Check that the topic is PROMOTED or STOPPED on East and that West is the new primary.

EOF

echo "[INFO] Done. You have successfully failed over from East to West."
