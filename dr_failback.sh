#!/usr/bin/env bash
#
# dr_failback.sh
#
# Purpose:
#   Conduct failback from West → East. Handles both a graceful scenario (reverse-and-start)
#   or a forced scenario (truncate-and-restore + failover).
#
# Prerequisites:
#   - terraform, confluent CLI, jq installed
#   - A successful 'terraform apply' so local Terraform state has valid outputs
#   - Confluent CLI logged in (confluent login)
#   - West cluster generally reachable unless you truly want forced approach
#
# Usage:
#   ./dr_failback.sh
#
# Key Steps:
#   1) Validate West and East cluster IDs, environment IDs via Terraform outputs
#   2) Prompt user: graceful or forced failback?
#       - Graceful → run reverse-and-start from West to East
#       - Forced → possibly run truncate-and-restore, then failover or reverse
#   3) Prompt user to re-point producers/consumers to East
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

# Parse West environment/cluster
WEST_ENV_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.west_environment_id.value')
WEST_CLUSTER_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.west_kafka_cluster_id.value')

# Parse East environment/cluster
EAST_ENV_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_environment_id.value')
EAST_CLUSTER_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_kafka_cluster_id.value')

# Parse Link Name and East Topic
LINK_NAME=$(echo "$TF_OUTPUT_JSON" | jq -r '.cluster_link_east_to_west_name.value')
TOPIC_ON_EAST=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_topic_name.value')

###############################################################################
# Step 2: Basic Checks
###############################################################################
if [[ -z "$WEST_ENV_ID" || "$WEST_ENV_ID" == "null" ]]; then
  echo "[ERROR] Missing west_environment_id in Terraform outputs."
  exit 1
fi
if [[ -z "$WEST_CLUSTER_ID" || "$WEST_CLUSTER_ID" == "null" ]]; then
  echo "[ERROR] Missing west_kafka_cluster_id in Terraform outputs."
  exit 1
fi
if [[ -z "$EAST_ENV_ID" || "$EAST_ENV_ID" == "null" ]]; then
  echo "[ERROR] Missing east_environment_id in Terraform outputs."
  exit 1
fi
if [[ -z "$EAST_CLUSTER_ID" || "$EAST_CLUSTER_ID" == "null" ]]; then
  echo "[ERROR] Missing east_kafka_cluster_id in Terraform outputs."
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
# Step 3: Prompt for Failback Mode (Graceful vs. Forced)
###############################################################################
cat <<MODES

====================================
 DR Failback: West → East
====================================

Select a failback mode:
 1) Graceful Failback
    - Run reverse-and-start from West to East.
    - East becomes primary again if successful.
 2) Forced Failback
    - If East was forcibly failed over, we may need to:
      a) truncate-and-restore or do partial sync
      b) then forcibly failover West → East

MODES

read -p "Enter choice (1=Graceful, 2=Forced): " FAILBACK_MODE
echo

###############################################################################
# Step 4: Execute Failback Logic
###############################################################################
if [[ "$FAILBACK_MODE" == "1" ]]; then
  # Graceful approach
  echo "[INFO] Attempting graceful failback (reverse-and-start) from West to East for topic '$TOPIC_ON_EAST'..."
  echo "Command: confluent kafka mirror reverse-and-start $TOPIC_ON_EAST --link $LINK_NAME --cluster $EAST_CLUSTER_ID --environment $EAST_ENV_ID"

  set +e
  confluent kafka mirror reverse-and-start "$TOPIC_ON_EAST" \
    --link "$LINK_NAME" \
    --cluster "$EAST_CLUSTER_ID" \
    --environment "$EAST_ENV_ID"
  REVERSE_EXIT_CODE=$?
  set -e

  if [[ $REVERSE_EXIT_CODE -ne 0 ]]; then
    echo "[WARN] reverse-and-start mirror failed. Possibly East is unreachable or partial data mismatch."
    echo "Would you like to do a forced failback with possible truncate-and-restore? (y/n)"
    read -r FORCED_ASK
    if [[ "$FORCED_ASK" =~ ^[Yy]$ ]]; then
      # Attempt forced approach
      echo "[INFO] Proceeding with forced approach..."
      # (See forced logic below)
      FORCED_MODE=true
    else
      echo "[INFO] Exiting without forced failback."
      exit 0
    fi
  else
    echo "[INFO] Reverse-and-start mirror successful for '$TOPIC_ON_EAST'. East is now primary."
    FORCED_MODE=false
  fi

elif [[ "$FAILBACK_MODE" == "2" ]]; then
  # Forced approach selected immediately
  FORCED_MODE=true
else
  echo "[ERROR] Invalid choice. Exiting."
  exit 1
fi

###############################################################################
# Step 5: Handle Forced Failback (Truncate-and-Restore, or direct failover)
###############################################################################
if [[ "$FORCED_MODE" == true ]]; then

  cat <<FORCED

[INFO] Forced Failback Steps:
  1) Possibly run truncate-and-restore on East if it diverged from West.
  2) Then forcibly fail over from West → East.

Would you like to do a "truncate-and-restore" first? This is typically needed if
East missed writes that occurred in West while East was down or forcibly failed.

FORCED

  read -p "Truncate-and-restore first? (y/n): " TRUNCATE_FIRST
  echo

  if [[ "$TRUNCATE_FIRST" =~ ^[Yy]$ ]]; then
    echo "[INFO] Running truncate-and-restore on East for '$TOPIC_ON_EAST'..."
    echo "Command: confluent kafka mirror truncate-and-restore $TOPIC_ON_EAST --link $LINK_NAME --cluster $EAST_CLUSTER_ID --environment $EAST_ENV_ID"
    confluent kafka mirror truncate-and-restore "$TOPIC_ON_EAST" \
      --link "$LINK_NAME" \
      --cluster "$EAST_CLUSTER_ID" \
      --environment "$EAST_ENV_ID"
    echo "[INFO] Truncate-and-restore done. East topic should now be a mirror of West."
  else
    echo "[INFO] Skipping truncate-and-restore. Continuing with forced failback..."
  fi

  echo "[INFO] Now forcibly failing over from West → East for topic '$TOPIC_ON_EAST'..."
  echo "Command: confluent kafka mirror failover $TOPIC_ON_EAST --link $LINK_NAME --cluster $EAST_CLUSTER_ID --environment $EAST_ENV_ID"
  confluent kafka mirror failover "$TOPIC_ON_EAST" \
    --link "$LINK_NAME" \
    --cluster "$EAST_CLUSTER_ID" \
    --environment "$EAST_ENV_ID"
  echo "[INFO] Forced failback complete. East is primary again."
fi

###############################################################################
# Step 6: Instruct User to Re-point to East
###############################################################################
cat <<EOF

[INFO] West → East failback complete for topic "$TOPIC_ON_EAST".

Next steps:
  1) Re-point your producer/consumer to East:
     cd python
     python avro_producer_app.py east
     python avro_consumer_app.py east

  2) Validate failback:
     confluent kafka mirror list --cluster "$EAST_CLUSTER_ID" --environment "$EAST_ENV_ID"
     # Check that the topic is PROMOTED or STOPPED on West and that East is the new primary.

EOF

echo "[INFO] Done. You have successfully failed back to East."

