#!/usr/bin/env bash
#
# dr_status.sh
#
# Purpose:
#   Display the current Disaster Recovery (DR) situation:
#   - Which cluster is primary, which is secondary
#   - Cluster link and mirror topic statuses
#   - Any active DENY ACLs simulating an outage
#
# Prerequisites:
#   - Terraform, Confluent CLI, jq installed
#   - Successful 'terraform apply' to populate outputs
#   - Confluent CLI logged in
#
# Usage:
#   ./dr_status.sh
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

# Parse cluster details
EAST_ENV_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_environment_id.value')
EAST_CLUSTER_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_kafka_cluster_id.value')
WEST_ENV_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.west_environment_id.value')
WEST_CLUSTER_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.west_kafka_cluster_id.value')
LINK_NAME=$(echo "$TF_OUTPUT_JSON" | jq -r '.cluster_link_east_to_west_name.value')
TOPIC_ON_EAST=$(echo "$TF_OUTPUT_JSON" | jq -r '.east_topic_name.value')

###############################################################################
# Step 2: Check if ACLs are Blocking Access (Outage Simulation)
###############################################################################
function check_outage_acl() {
  local env_id="$1"
  local cluster_id="$2"
  local cluster_label="$3"

  echo "[INFO] Checking ACLs for $cluster_label cluster (ID=$cluster_id)..."
  local acl_list
  acl_list=$(confluent kafka acl list --environment "$env_id" --cluster "$cluster_id" --output json 2>/dev/null || true)

  if [[ -z "$acl_list" || "$acl_list" == "[]" ]]; then
    echo "[INFO] No ACL denies detected for $cluster_label. Cluster is accessible."
    return 1  # No ACL denies → cluster is UP
  fi

  local deny_count
  deny_count=$(echo "$acl_list" | jq '[.[] | select(.permission=="DENY" and .principal=="User:*")] | length')

  if [[ "$deny_count" -gt 0 ]]; then
    echo "[INFO] $cluster_label is DENIED for User:* (outage simulated)."
    return 0  # Cluster has DENY ACLs
  else
    return 1  # No denies, cluster is up
  fi
}

EAST_DOWN=false
WEST_DOWN=false

if check_outage_acl "$EAST_ENV_ID" "$EAST_CLUSTER_ID" "East"; then
  EAST_DOWN=true
fi

if check_outage_acl "$WEST_ENV_ID" "$WEST_CLUSTER_ID" "West"; then
  WEST_DOWN=true
fi

###############################################################################
# Step 3: Retrieve Mirror Topic Statuses
###############################################################################
EAST_MIRROR_STATUS="UNKNOWN"
WEST_MIRROR_STATUS="UNKNOWN"
EAST_MIRROR_FETCHED=false
WEST_MIRROR_FETCHED=false

function get_mirror_status() {
  local env_id="$1"
  local cluster_id="$2"
  local cluster_label="$3"

  if [[ "$cluster_label" == "East" && "$EAST_DOWN" == "true" ]]; then
    echo "[WARN] Skipping East mirror topic check because East is down."
    return
  fi
  if [[ "$cluster_label" == "West" && "$WEST_DOWN" == "true" ]]; then
    echo "[WARN] Skipping West mirror topic check because West is down."
    return
  fi

  echo "[INFO] Checking Mirror Topics in $cluster_label cluster (ID=$cluster_id)..."
  local mirror_list
  mirror_list=$(confluent kafka mirror list --cluster "$cluster_id" --environment "$env_id" -o json 2>/dev/null || true)

  if [[ -z "$mirror_list" || "$mirror_list" == "[]" ]]; then
    echo "[INFO] No mirror topics found for $cluster_label."
    return
  fi

  # Extract mirror topic details
  local status
  status=$(echo "$mirror_list" | jq -r --arg topic "$TOPIC_ON_EAST" '.[] | select(.mirror_topic_name==$topic) | .mirror_status')

  if [[ -z "$status" || "$status" == "null" ]]; then
    echo "[INFO] No mirror topic named $TOPIC_ON_EAST found in $cluster_label."
  else
    echo "[INFO] Mirror topic '$TOPIC_ON_EAST' in $cluster_label is $status."
    if [[ "$cluster_label" == "East" ]]; then
      EAST_MIRROR_STATUS="$status"
      EAST_MIRROR_FETCHED=true
    else
      WEST_MIRROR_STATUS="$status"
      WEST_MIRROR_FETCHED=true
    fi
  fi
}

get_mirror_status "$EAST_ENV_ID" "$EAST_CLUSTER_ID" "East"
get_mirror_status "$WEST_ENV_ID" "$WEST_CLUSTER_ID" "West"

###############################################################################
# Step 4: Determine Primary & Secondary Cluster
###############################################################################
PRIMARY_CLUSTER="UNKNOWN"
SECONDARY_CLUSTER="UNKNOWN"

# **Updated Logic**
if [[ "$EAST_DOWN" == "true" && "$WEST_DOWN" == "false" ]]; then
  PRIMARY_CLUSTER="West"
  SECONDARY_CLUSTER="East"
elif [[ "$WEST_DOWN" == "true" && "$EAST_DOWN" == "false" ]]; then
  PRIMARY_CLUSTER="East"
  SECONDARY_CLUSTER="West"
elif [[ "$WEST_MIRROR_STATUS" == "ACTIVE" && "$EAST_MIRROR_STATUS" == "UNKNOWN" ]]; then
  PRIMARY_CLUSTER="East"
elif [[ "$EAST_MIRROR_STATUS" == "ACTIVE" && "$WEST_MIRROR_STATUS" == "UNKNOWN" ]]; then
  PRIMARY_CLUSTER="West"
fi

###############################################################################
# Step 5: Summarize DR State
###############################################################################
echo "[INFO] DR Situation Summary:"
echo "---------------------------------"

if [[ "$PRIMARY_CLUSTER" == "West" ]]; then
  echo "- **West is PRIMARY** (producers should connect to West)."
elif [[ "$PRIMARY_CLUSTER" == "East" ]]; then
  echo "- **East is PRIMARY** (producers should connect to East)."
else
  echo "- **No clear primary cluster detected. Check failover/failback state.**"
fi

if $EAST_DOWN; then
  echo "- [ALERT] **East is simulated DOWN** (DENY ACLs active)."
fi

if $WEST_DOWN; then
  echo "- [ALERT] **West is simulated DOWN** (DENY ACLs active)."
fi

echo "---------------------------------"
echo "[INFO] Run 'simulate_outage.sh' to apply deny ACLs or 'restore_access.sh' to clear deny ACLs."
echo "[INFO] For failover/failback, see 'dr_failover.sh' or 'dr_failback.sh'."
echo "[INFO] Done."