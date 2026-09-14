#!/bin/bash

# Set USER_DIR to the root folder
export USER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${USER_DIR}/monitoring"
PATCHES_DIR="${MONITORING_DIR}/patches"
DEPLOY_SCRIPT="${USER_DIR}/upstream/viya4-monitoring-kubernetes/monitoring/bin/deploy_monitoring_cluster.sh"
CONFIG_GRAFANA_SCRIPT="${USER_DIR}/upstream/grafana-esp-plugin/install/configure-grafana.sh"
GRAFANA_HTTP_PROXY="${USER_DIR}/upstream/grafana-esp-plugin/install/grafana-http-proxy.yaml"
PROCESS_TEMPLATES_SCRIPT="${USER_DIR}/process_templates.sh"
DEPLOY_SCRIPT_PATCH_FILE="${PATCHES_DIR}/deploy_monitoring_cluster.patch"
CONFIG_GRAFANA_SCRIPT_PATCH_FILE="${PATCHES_DIR}/configure-grafana.patch"
GRAFANA_HTTP_PROXY_PATCH_FILE="${PATCHES_DIR}/grafana-http-proxy.patch"
GRAFANA_MANIFESTS_DIR="${MONITORING_DIR}/grafana/manifests"
GRAFANA_INSTALL_DIR="${USER_DIR}/upstream/grafana-esp-plugin/install"
PROM_VALUES_TEMPLATE="${MONITORING_DIR}/user-values-prom-operator.yaml.template"
PROM_VALUES="${MONITORING_DIR}/user-values-prom-operator.yaml"

# Load environment variables from monitoring/user.env
userEnv=$(grep -v '^[[:blank:]]*$' "$MONITORING_DIR/user.env" | grep -v '^#' | xargs)
export $userEnv

# Initialise git submodules
git -C "${USER_DIR}" submodule update --init --recursive --force

# Process templates
bash "${PROCESS_TEMPLATES_SCRIPT}"

# Copy Grafana manifest YAMLs into the upstream install directory
cp -f "${GRAFANA_MANIFESTS_DIR}"/*.yaml "${GRAFANA_INSTALL_DIR}/"

# Generate user-values-prom-operator.yaml from template
sed "s/__HOST_NAME__/${HOST_NAME}/g" "${PROM_VALUES_TEMPLATE}" > "${PROM_VALUES}"

# Apply patches
patch "${DEPLOY_SCRIPT}" "${DEPLOY_SCRIPT_PATCH_FILE}"
patch "${CONFIG_GRAFANA_SCRIPT}" "${CONFIG_GRAFANA_SCRIPT_PATCH_FILE}"
patch "${GRAFANA_HTTP_PROXY}" "${GRAFANA_HTTP_PROXY_PATCH_FILE}"

# Execute deploy_monitoring_cluster.sh
bash "${DEPLOY_SCRIPT}"