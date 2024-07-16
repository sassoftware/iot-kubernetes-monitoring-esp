#!/usr/bin/env bash

set -e -o pipefail -o nounset

# Environment variables
ESP_NAMESPACE="${ESP_NAMESPACE:-$(kubectl get deploy -A | grep sas-esp-operator | head -1 2>/dev/null | awk '{print $1}')}"

if [ -z "${GRAFANA_NAMESPACE}" ]; then
    GRAFANA_NAMESPACE="${MON_NS:-$(kubectl get deploy -A -l app.kubernetes.io/name=grafana | tail -1 | awk '{print $1}')}"
fi

if [ -z "${ESP_NAMESPACE}" ] || [ -z "${GRAFANA_NAMESPACE}" ];then
   echo -ne "- Either Viya or Grafana do not seem to be running on the cluster...\n"
   exit 1
fi

if [ -z "${OAUTH_CLIENT_ID}" ]; then
    OAUTH_CLIENT_ID="$(kubectl -n "${GRAFANA_NAMESPACE}" get configmap v4m-grafana -o yaml | grep client_id | head -1 2>/dev/null | awk '{print $3}')"
fi
export OAUTH_CLIENT_ID

if [ -z "${OAUTH_CLIENT_SECRET}" ]; then
    OAUTH_CLIENT_SECRET="$(kubectl -n "${GRAFANA_NAMESPACE}" get configmap v4m-grafana -o yaml | grep client_secret | head -1 2>/dev/null | awk '{print $3}')"
fi
export OAUTH_CLIENT_SECRET

[ -z "${ESP_NAMESPACE}" ] && {
    echo "ESP_NAMESPACE environment variable unset and auto-detect failed." >&2
    exit 1
}

ESP_DOMAIN=$(kubectl -n "${ESP_NAMESPACE}" get ingress --output json | jq -r '.items[0].spec.rules[0].host')
GRAFANA_DOMAIN=$(kubectl -n "${GRAFANA_NAMESPACE}" get ingress --output json | jq -r '.items[0].spec.rules[0].host')

# Fetch access token to perform admin tasks:
function fetch_uaa_admin_token() {
    _resp=$(curl "https://${ESP_DOMAIN}/uaa/oauth/token" -k -X POST \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -H 'Accept: application/json' \
        -d "client_id=${UAA_ADMIN}&client_secret=${UAA_SECRET}&grant_type=client_credentials&response_type=token")

    echo "${_resp}" | jq -r '.access_token'
}

# Add Grafana generic OAuth to allowed auth redirects:
function add_grafana_auth_redirect_uaa() {
    _token="$(fetch_uaa_admin_token)"
    _redirect="https://${GRAFANA_DOMAIN}/grafana/login/generic_oauth"

    _config=$(curl -k -X GET "https://${ESP_DOMAIN}/uaa/oauth/clients/${OAUTH_CLIENT_ID}" -H "Authorization: Bearer ${_token}")

    _update_body=$(echo "${_config}" | jq -c -r --arg redirect "${_redirect}" \
        '.redirect_uri += [$redirect] | {client_id: .client_id, redirect_uri: .redirect_uri}')

    _resp=$(curl "https://${ESP_DOMAIN}/uaa/oauth/clients/${OAUTH_CLIENT_ID}" -k -X PUT \
        -o /dev/null -w "%{http_code}" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${_token}" \
        -H 'Accept: application/json' \
        -d "${_update_body}")

    if [ "${_resp}" == '200' ]; then
        echo "  Grafana OAuth redirect added."
    else
        echo >&2 "ERROR: OAuth client redirect update failed with status code ${_resp}."
        exit 1
    fi
}

_uaa_secret_data=$(kubectl -n "${ESP_NAMESPACE}" get secret uaa-secret --output json)
UAA_ADMIN=$(echo "${_uaa_secret_data}" | jq -r '.data.username | @base64d')
export UAA_ADMIN
UAA_SECRET=$(echo "${_uaa_secret_data}" | jq -r '.data.password | @base64d')
export UAA_SECRET

cat <<EOF
OAuth details:
  ESP Domain:          ${ESP_DOMAIN}
  Grafana Domain:      ${GRAFANA_DOMAIN}
  OAuth client ID:     ${OAUTH_CLIENT_ID}
  OAuth client secret: ****
  UAA Admin:           ${UAA_ADMIN}
  UAA secret:          ****
EOF

add_grafana_auth_redirect_uaa
