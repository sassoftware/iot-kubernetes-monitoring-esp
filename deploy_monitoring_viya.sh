#!/bin/bash

# Set USER_DIR to the root folder
export USER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="${USER_DIR}/upstream/viya4-monitoring-kubernetes/monitoring/bin/deploy_monitoring_viya.sh"

# Load environment variables from monitoring/user.env
userEnv=$(grep -v '^[[:blank:]]*$' "$MONITORING_DIR/user.env" | grep -v '^#' | xargs)
export $userEnv

# Execute deploy_monitoring_viya.sh
bash "${DEPLOY_SCRIPT}"