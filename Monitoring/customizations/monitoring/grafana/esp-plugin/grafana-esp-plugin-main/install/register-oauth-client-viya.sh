#!/usr/bin/env bash

set -e -o pipefail

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

ESP_DOMAIN=$(kubectl -n "${ESP_NAMESPACE}" get ingress --output json | jq -r '.items[0].spec.rules[0].host')
GRAFANA_DOMAIN=$(kubectl -n "${GRAFANA_NAMESPACE}" get ingress --output json | jq -r '.items[0].spec.rules[0].host')

function fetch_consul_token () {
    _token=$(kubectl -n "${ESP_NAMESPACE}" get secret sas-consul-client -o go-template='{{ .data.CONSUL_TOKEN | base64decode}}')

    echo "${_token}"
}

function fetch_saslogon_token () {
    _token=$(fetch_consul_token)
    _resp=$(curl -k -X POST "https://$ESP_DOMAIN/SASLogon/oauth/clients/consul?callback=false&serviceId=app" -H "X-Consul-Token: ${_token}" 2>/dev/null)

    echo "${_resp}" | jq -r '.access_token'
}

function patch_saslogon_csp () {
  _patch_json=$(cat <<EOF
[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "SAS_COMMONS_WEB_SECURITY_CONTENTSECURITYPOLICY",
      "value": "default-src 'self'; style-src 'self'; font-src 'self' data:; frame-ancestors 'self'; form-action 'self' ${GRAFANA_DOMAIN};"
    }
  }
]
EOF
)
  kubectl patch deployment sas-logon-app \
    --namespace "${ESP_NAMESPACE}" \
    --type='json' --patch="${_patch_json}"
}

function register_oauth_client () {
    _token="$(fetch_saslogon_token)"

    _redirecturl="https://${GRAFANA_DOMAIN}/grafana/login/generic_oauth"

    _body='{
        "scope": ["*"],
        "client_id": "'"${OAUTH_CLIENT_ID}"'",
        "client_secret": "'"${OAUTH_CLIENT_SECRET}"'",
        "authorized_grant_types": ["authorization_code"],
        "redirect_uri": ["'"${_redirecturl}"'"],
        "autoapprove": ["true"],
        "name": "Grafana"
    }'

    # Delete existing client definition if found
    _resp=$(curl -k -X DELETE "https://$ESP_DOMAIN/SASLogon/oauth/clients/${OAUTH_CLIENT_ID}" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${_token}" \
        -d "${_body}" 2>/dev/null)
    regex_error="error"
    if [[ "${_resp}" =~ $regex_error ]]; then
       error=$(echo "${_resp}" | jq -r '.error')
       error_description=$(echo "${_resp}" | jq -r '.error_description')
       echo >&2 "Failed to delete Grafana as OAuth client"
       echo >&2 "${error}: ${error_description}"
    else
       echo "Grafana deleted as OAuth client"
    fi

    _resp=$(curl -k -X POST "https://$ESP_DOMAIN/SASLogon/oauth/clients" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${_token}" \
        -d "${_body}" 2>/dev/null)

    regex_error="error"
    if [[ "${_resp}" =~ $regex_error ]]; then
       error=$(echo "${_resp}" | jq -r '.error')
       error_description=$(echo "${_resp}" | jq -r '.error_description')
       echo >&2 "Failed to register Grafana as OAuth client"
       echo >&2 "${error}: ${error_description}"
    else
       echo "Grafana registered as OAuth client"
    fi

    if [[ "${GRAFANA_DOMAIN}" != "${ESP_DOMAIN}" ]]; then
      echo "Patching SAS Logon Content Security Policy..."
      patch_saslogon_csp
    fi

}

cat <<EOF

OAUTH details:
  Viya Domain:         ${ESP_DOMAIN}
  Grafana Domain:      ${GRAFANA_DOMAIN}
  OAuth client ID:     ${OAUTH_CLIENT_ID}
  OAuth client secret: ****

EOF

register_oauth_client
