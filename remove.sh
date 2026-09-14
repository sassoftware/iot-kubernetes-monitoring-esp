#!/bin/bash

# Set USER_DIR to the root folder
export USER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${USER_DIR}/monitoring"
PATCHES_DIR="${MONITORING_DIR}/patches"
REMOVE_SCRIPT="${USER_DIR}/upstream/viya4-monitoring-kubernetes/monitoring/bin/remove_monitoring_cluster.sh"
REMOVE_SCRIPT_PATCH_FILE="${PATCHES_DIR}/remove_monitoring_cluster.patch"

# Load environment variables from monitoring/user.env
userEnv=$(grep -v '^[[:blank:]]*$' "$MONITORING_DIR/user.env" | grep -v '^#' | xargs)
export $userEnv

# Apply patch
patch "${REMOVE_SCRIPT}" "${REMOVE_SCRIPT_PATCH_FILE}"

# Execute remove_monitoring_cluster.sh
bash "${REMOVE_SCRIPT}"