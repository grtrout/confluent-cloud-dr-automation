#!/usr/bin/env bash
#
# restore_access.sh
#
# Purpose:
#   Removes specific DENY ACLs (READ, WRITE, DESCRIBE) that were previously
#   applied by `simulate_outage.sh`. This script:
#   - Queries existing DENY ACLs via `confluent kafka acl list`
#   - Groups them by topic and combines operations into a single delete call
#   - Shows the user exactly what would be removed
#   - Prompts for confirmation before deletion
#
# Prerequisites:
#   - Terraform, Confluent CLI, jq installed
#   - A successful 'terraform apply' so local Terraform state has valid outputs
#   - Confluent CLI logged in (confluent login)
#
# Usage:
#   ./restore_access.sh
#     - Prompts user to pick East, West, or Both, then shows existing DENY ACLs
#       and asks for confirmation before removal.
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
cat <<INTRO

==================================
Restore Access (Remove DENY ACLs)
==================================

This script removes the DENY ACLs (READ, WRITE, DESCRIBE) that were previously
applied by simulate_outage.sh. It queries existing ACLs using
\`confluent kafka acl list\` and removes those matching "User:*" with
"permission": "DENY".

Which region(s) do you want to restore (remove ACLs from)?
1) East
2) West
3) Both
4) Cancel
INTRO

read -p "Enter your choice: " REG_CHOICE
echo

if [[ "$REG_CHOICE" == "4" ]]; then
  echo "[INFO] Exiting. No ACLs removed."
  exit 0
fi

###############################################################################
# Step 3: Determine Target Regions
###############################################################################
SELECTED_REGIONS=()
case "$REG_CHOICE" in
  1) SELECTED_REGIONS=("East") ;;
  2) SELECTED_REGIONS=("West") ;;
  3) SELECTED_REGIONS=("East" "West") ;;
  *)
    echo "[ERROR] Invalid option. Aborting."
    exit 1
    ;;
esac

###############################################################################
# Step 4: For Each Selected Region, Show & Potentially Remove DENY ACLs
###############################################################################
ACL_REMOVAL_OCCURRED=false  # Flag to track if ACLs were actually removed

function remove_acls_for_region() {
  local env_id="$1"
  local cluster_id="$2"
  local region_label="$3"

  if [[ -z "$env_id" || "$env_id" == "null" || -z "$cluster_id" || "$cluster_id" == "null" ]]; then
    echo "[WARN] Missing environment or cluster ID for $region_label. Skipping..."
    return
  fi

  echo "[INFO] Checking existing DENY ACLs in $region_label (Cluster ID: $cluster_id)..."
  local acl_list
  acl_list=$(confluent kafka acl list --environment "$env_id" --cluster "$cluster_id" --output json || true)

  # Filter out only DENY ACLs
  local deny_list
  deny_list=$(echo "$acl_list" | jq -c 'map(select(.permission == "DENY"))' 2>/dev/null || true)

  if [[ "$deny_list" == "[]" || -z "$deny_list" ]]; then
    echo "[INFO] No DENY ACLs found in $region_label. Nothing to remove."
    echo
    return
  fi

  echo "[INFO] The following DENY ACLs were found in $region_label:"
  echo "$deny_list" | jq .

  # Prompt user for confirmation
  echo
  read -p "Remove these DENY ACLs from $region_label? (y/n) " -r CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[INFO] Skipping ACL removal in $region_label."
    echo
    return
  fi

  # Group ACLs by topic and aggregate operations
  local topic_acl_map
  topic_acl_map=$(echo "$deny_list" | jq -c 'group_by(.resource_name) | map({topic: .[0].resource_name, operations: map(.operation) | unique | join(",")})')

  local total_acls_removed=0  # Track total ACLs removed

  while read -r entry; do
    local res_name
    res_name=$(echo "$entry" | jq -r '.topic')
    local operations
    operations=$(echo "$entry" | jq -r '.operations')

    # Count how many operations are being removed in this command
    local num_operations
    num_operations=$(echo "$operations" | awk -F',' '{print NF}')

    ((total_acls_removed+=num_operations)) || true  # Increment by the number of operations

    echo "Command: confluent kafka acl delete --environment \"$env_id\" --cluster \"$cluster_id\" --principal \"User:*\" --deny --operations \"$operations\" --topic \"$res_name\" --force"
    confluent kafka acl delete \
      --environment "$env_id" \
      --cluster "$cluster_id" \
      --principal "User:*" \
      --deny \
      --operations "$operations" \
      --topic "$res_name" \
      --force || true
  done <<< "$(echo "$topic_acl_map" | jq -cr '.[]')"

  if [[ $total_acls_removed -gt 0 ]]; then
    echo "[INFO] Removed $total_acls_removed DENY ACL entries in $region_label."
    ACL_REMOVAL_OCCURRED=true  # Mark that ACLs were actually removed
  else
    echo "[INFO] No relevant TOPIC-based DENY ACLs removed in $region_label."
  fi
  echo

}

for region in "${SELECTED_REGIONS[@]}"; do
  if [[ "$region" == "East" ]]; then
    remove_acls_for_region "$EAST_ENV_ID" "$EAST_CLUSTER_ID" "East"
  elif [[ "$region" == "West" ]]; then
    remove_acls_for_region "$WEST_ENV_ID" "$WEST_CLUSTER_ID" "West"
  fi
done

###############################################################################
# Step 5: Final Status Message
###############################################################################
if [[ "$ACL_REMOVAL_OCCURRED" == true ]]; then
  echo "[INFO] Completed DENY ACL removal for the chosen region(s)."
  echo "[INFO] Access should now be restored!"
else
  echo "[INFO] No ACLs were removed. No changes were made."
fi
