#!/usr/bin/env bash
#
# simulate_outage.sh
#
# Purpose:
#   Applies DENY ACLs (READ,WRITE,DESCRIBE) for topics in either the East or
#   West cluster to simulate a full client outage. Does NOT remove them.
#   Tells users to run `restore_access.sh` if they want to remove ACLs.
#
# Prerequisites:
#   - terraform, confluent CLI, jq installed
#   - A successful 'terraform apply' so local Terraform state has valid outputs
#   - Confluent CLI logged in (confluent login)
#
# Usage Examples:
#   ./simulate_outage.sh
#     - Prompts user to pick East or West, then applies ACLs
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

###############################################################################
# Step 2: Intro Prompt
###############################################################################
cat <<OUTAGE

=====================================================
 Simulate Cluster Outage (via DENY ACLs)
=====================================================

This script applies DENY ACLs (READ,WRITE,DESCRIBE) for topics
in either the East or West cluster to simulate a full client outage.

NOTE: To restore access, you must run:  **./restore_access.sh**

Which cluster do you want to target?
1) East
2) West
3) Cancel
OUTAGE

read -p "Enter your choice (1/2/3): " CLUSTER_CHOICE
echo

if [[ "$CLUSTER_CHOICE" == "3" ]]; then
  echo "[INFO] Exiting. No ACLs applied."
  exit 0
fi

TARGET_CLUSTER=""
TARGET_ENV_ID=""
TARGET_CLUSTER_ID=""

if [[ "$CLUSTER_CHOICE" == "1" ]]; then
  TARGET_CLUSTER="East"
  TARGET_ENV_ID="$EAST_ENV_ID"
  TARGET_CLUSTER_ID="$EAST_CLUSTER_ID"
elif [[ "$CLUSTER_CHOICE" == "2" ]]; then
  TARGET_CLUSTER="West"
  TARGET_ENV_ID="$WEST_ENV_ID"
  TARGET_CLUSTER_ID="$WEST_CLUSTER_ID"
else
  echo "[ERROR] Invalid selection. Exiting."
  exit 1
fi

if [[ -z "$TARGET_ENV_ID" || -z "$TARGET_CLUSTER_ID" || "$TARGET_ENV_ID" == "null" || "$TARGET_CLUSTER_ID" == "null" ]]; then
  echo "[ERROR] Missing environment or cluster ID for $TARGET_CLUSTER. Check Terraform outputs."
  exit 1
fi

###############################################################################
# Step 3: Apply DENY ACLs to Simulate Outage
###############################################################################
echo "[INFO] Enumerating topics in $TARGET_CLUSTER cluster (ID: $TARGET_CLUSTER_ID) to APPLY DENY ACLs..."
TOPICS_JSON=$(confluent kafka topic list --environment "$TARGET_ENV_ID" --cluster "$TARGET_CLUSTER_ID" -o json || true)
TOPIC_NAMES=$(echo "$TOPICS_JSON" | jq -r '.[].name' 2>/dev/null || true)

if [[ -z "$TOPIC_NAMES" ]]; then
  echo "[WARN] No topics found or listing failed in $TARGET_CLUSTER. Possibly unreachable or empty."
  echo "[INFO] Exiting without applying ACLs."
  exit 1
fi

for T in $TOPIC_NAMES; do
  echo "Command: confluent kafka acl create --environment \"$TARGET_ENV_ID\" --cluster \"$TARGET_CLUSTER_ID\" --principal \"User:*\" --deny --operations read,write,describe --topic \"$T\""
  confluent kafka acl create \
    --environment "$TARGET_ENV_ID" \
    --cluster "$TARGET_CLUSTER_ID" \
    --principal "User:*" \
    --deny \
    --operations read,write,describe \
    --topic "$T" || true
done

echo "[INFO] DENY ACLs applied. $TARGET_CLUSTER cluster is effectively unreachable for producers/consumers."
echo "[INFO] To restore access, run:  **./restore_access.sh**"
echo "[INFO] Done."
