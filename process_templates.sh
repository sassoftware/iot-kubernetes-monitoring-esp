#!/usr/bin/env bash

set -e -o pipefail -o nounset

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${ROOT_DIR}/monitoring"
DASHBOARD_TEMPLATE_DIR="${MONITORING_DIR}/dashboards/templates"
DASHBOARD_OUTPUT_DIR="${MONITORING_DIR}/dashboards"
LOKI_TEMPLATE_DIR="${MONITORING_DIR}/loki/templates"
LOKI_OUTPUT_DIR="${MONITORING_DIR}/loki"
MONITORS_TEMPLATE_DIR="${MONITORING_DIR}/monitors/templates"
MONITORS_OUTPUT_DIR="${MONITORING_DIR}/monitors"
METRICS_TYPE="${METRICS_TYPE:-v2}"

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

configure_metric_mappings() {
  case "${METRICS_TYPE}" in
	v1)
	  METRIC_PROJECT_STATE="esp_project_state"
    METRIC_PROJECT_NAME="project_name"
    METRIC_CONNECTOR_STATE="esp_connector_state"
	  METRIC_WINDOW_CPU="esp_window_cpu_usage"
	  METRIC_WINDOW_NAME="window_name"
	  METRIC_MEMORY="esp_mem_usage"
	  METRIC_MEM_TYPE="mem_type"
	  METRIC_CONNECTOR_RATE="esp_connector_cur_rate"
	  METRICS_ENDPOINT="/SASESP/metrics"
	  ;;
	v2)
	  METRIC_PROJECT_STATE="project_state"
    METRIC_PROJECT_NAME="project"
    METRIC_CONNECTOR_STATE="connector_state"
	  METRIC_WINDOW_CPU="window_cpu"
	  METRIC_WINDOW_NAME="window"
	  METRIC_MEMORY="memory"
	  METRIC_MEM_TYPE="memtype"
	  METRIC_CONNECTOR_RATE="connector_rate"
	  METRICS_ENDPOINT="/eventStreamProcessing/v2/metrics"
	  ;;
	*)
	  echo "ERROR: Unsupported METRICS_TYPE '${METRICS_TYPE}'. Expected 'v1' or 'v2'." >&2
	  exit 1
	  ;;
  esac
}

render_template_dir() {
  local template_dir="$1"
  local output_dir="$2"
  local glob="$3"

  [ -d "${template_dir}" ] || {
  echo "ERROR: Template directory not found: ${template_dir}" >&2
  exit 1
  }

  mkdir -p "${output_dir}"

  local template
  for template in "${template_dir}"/${glob}; do
	[ -e "${template}" ] || continue

	# Only render the pod-level dashboard when using v2 metrics.
	if [ "$(basename "${template}")" = "dashboard-pod-level.json.template" ] && [ "${METRICS_TYPE}" != "v2" ]; then
	  continue
	fi

	local output_file
  output_file="${output_dir}/$(basename "${template}" .template)"

	sed \
	  -e "s|__METRIC_PROJECT_STATE__|$(escape_sed_replacement "${METRIC_PROJECT_STATE}")|g" \
	  -e "s|__METRIC_PROJECT_NAME__|$(escape_sed_replacement "${METRIC_PROJECT_NAME}")|g" \
	  -e "s|__METRIC_CONNECTOR_STATE__|$(escape_sed_replacement "${METRIC_CONNECTOR_STATE}")|g" \
	  -e "s|__METRIC_WINDOW_CPU__|$(escape_sed_replacement "${METRIC_WINDOW_CPU}")|g" \
	  -e "s|__METRIC_WINDOW_NAME__|$(escape_sed_replacement "${METRIC_WINDOW_NAME}")|g" \
	  -e "s|__METRIC_MEMORY__|$(escape_sed_replacement "${METRIC_MEMORY}")|g" \
	  -e "s|__METRIC_MEM_TYPE__|$(escape_sed_replacement "${METRIC_MEM_TYPE}")|g" \
	  -e "s|__METRIC_CONNECTOR_RATE__|$(escape_sed_replacement "${METRIC_CONNECTOR_RATE}")|g" \
	  -e "s|__METRICS_ENDPOINT__|$(escape_sed_replacement "${METRICS_ENDPOINT}")|g" \
	  "${template}" > "${output_file}"

	if grep -Eq '__METRIC_|__METRICS_ENDPOINT__' "${output_file}"; then
	  echo "ERROR: Unresolved template placeholders remain in ${output_file}" >&2
	  exit 1
	fi

	echo "Generated ${output_file}"
  done
}

configure_metric_mappings
render_template_dir "${DASHBOARD_TEMPLATE_DIR}" "${DASHBOARD_OUTPUT_DIR}" '*.json.template'
render_template_dir "${LOKI_TEMPLATE_DIR}" "${LOKI_OUTPUT_DIR}" '*.yaml.template'
render_template_dir "${MONITORS_TEMPLATE_DIR}" "${MONITORS_OUTPUT_DIR}" '*.yaml.template'

