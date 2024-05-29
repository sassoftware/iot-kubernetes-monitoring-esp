#!/usr/bin/env bash

# Environment variables
AUTH_DIR=${1}
ESP_NAMESPACE=`kubectl get casdeployment -A | grep -v NAMESPACE | head -1 2>/dev/null | grep -v NAMESPACE | awk '{print $1}'`
GRAFANA_NAMESPACE=`kubectl get deploy -A -l app.kubernetes.io/name=grafana | tail -1 | awk '{print $1}'`

if [ -z ${ESP_NAMESPACE} ] || [ -z ${GRAFANA_NAMESPACE} ];then
   echo -ne "- Either Viya or Grafana do not seem to be running on the cluster...\n"
   exit -1
fi

OAUTH_TYPE="${3:-viya}";
ESP_PLUGIN_VERSION="${2:-7.44.0}"; export ESP_PLUGIN_VERSION
OAUTH_CLIENT_ID="${OAUTH_CLIENT_ID:-sv_client}"; export OAUTH_CLIENT_ID
OAUTH_CLIENT_SECRET="${OAUTH_CLIENT_SECRET:-secret}"; export OAUTH_CLIENT_SECRET
KEYCLOAK_SUBPATH="${KEYCLOAK_SUBPATH:-auth}"; export KEYCLOAK_SUBPATH

function generate_manifests() {
  EXTENSION=
  if [ -z `echo $(sed --version 2>/dev/null | head -1 | awk '{print $NF}')` ];then
     EXTENSION=.bak
  fi

  for file in `find . -name "*.template"` ; do
      filename=$(basename -- "$file")
      filename="${filename%.*}.yaml"

      if [ "${filename}" == "v4m-grafana-config.yaml" ]; then
         filename=${AUTH_DIR}/configmaps/${filename}
      else
         filename=${AUTH_DIR}/patches/${filename}
      fi

      cp -f $file $filename

      sed -i $EXTENSION 's|TEMPLATE_AUTH_URL|'$TEMPLATE_AUTH_URL'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_TOKEN_URL|'$TEMPLATE_TOKEN_URL'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_API_URL|'$TEMPLATE_API_URL'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_SIGNOUT_REDIRECT_URL|'$TEMPLATE_SIGNOUT_REDIRECT_URL'|g' $filename

      sed -i $EXTENSION 's|TEMPLATE_GRAFANA_DOMAIN|'$GRAFANA_DOMAIN'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_ESP_DOMAIN|'$ESP_DOMAIN'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_ESP_NAMESPACE|'$ESP_NAMESPACE'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_OAUTH_CLIENT_ID|'$OAUTH_CLIENT_ID'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_OAUTH_CLIENT_SECRET|'$OAUTH_CLIENT_SECRET'|g' $filename
      sed -i $EXTENSION 's|TEMPLATE_ESP_PLUGIN_SOURCE|'$ESP_PLUGIN_SOURCE'|g' $filename

      rm -rf ${filename}.bak
  done
}

ESP_DOMAIN=$(kubectl -n "${ESP_NAMESPACE}" get ingress --output json | jq -r '.items[0].spec.rules[0].host')
GRAFANA_DOMAIN=$(kubectl -n "${GRAFANA_NAMESPACE}" get ingress --output json | jq -r '.items[0].spec.rules[0].host')
ESP_PLUGIN_SOURCE="https://github.com/sassoftware/grafana-esp-plugin/releases/download/v$ESP_PLUGIN_VERSION/sasesp-plugin-$ESP_PLUGIN_VERSION.zip"

if [ "${OAUTH_TYPE}" == "viya" ]; then
   TEMPLATE_AUTH_URL="https://${ESP_DOMAIN}/SASLogon/oauth/authorize"
   TEMPLATE_TOKEN_URL="https://${ESP_DOMAIN}/SASLogon/oauth/token"
   TEMPLATE_API_URL="https://${ESP_DOMAIN}/SASLogon/userinfo"
   TEMPLATE_SIGNOUT_REDIRECT_URL="https://${ESP_DOMAIN}/SASLogon/logout.do"
elif [ "${OAUTH_TYPE}" == "keycloak" ]; then
     TEMPLATE_AUTH_URL="https://${ESP_DOMAIN}/${KEYCLOAK_SUBPATH}/realms/sas-esp/protocol/openid-connect/auth"
     TEMPLATE_TOKEN_URL="https://${ESP_DOMAIN}/${KEYCLOAK_SUBPATH}/realms/sas-esp/protocol/openid-connect/token"
     TEMPLATE_API_URL="https://${ESP_DOMAIN}/${KEYCLOAK_SUBPATH}/realms/sas-esp/protocol/openid-connect/userinfo"
     TEMPLATE_SIGNOUT_REDIRECT_URL="https://${ESP_DOMAIN}/${KEYCLOAK_SUBPATH}/realms/sas-esp/protocol/openid-connect/logout?client_id=${OAUTH_CLIENT_ID}\&post_logout_redirect_uri=https://${ESP_DOMAIN}/grafana/login"
  else
     TEMPLATE_AUTH_URL="https://${ESP_DOMAIN}/uaa/oauth/authorize"
     TEMPLATE_TOKEN_URL="https://${ESP_DOMAIN}/uaa/oauth/token?token_format=jwt"
     TEMPLATE_API_URL="https://${ESP_DOMAIN}/uaa/userinfo"
     TEMPLATE_SIGNOUT_REDIRECT_URL="https://${ESP_DOMAIN}/oauth2/sign_out?rd=https://${ESP_DOMAIN}/uaa/logout.do?redirect=https://${ESP_DOMAIN}/uaa/login"
fi

cat <<EOF
ESP Grafana plug-in deployment details:
  Viya domain:         ${ESP_DOMAIN}
  Grafana domain:      ${GRAFANA_DOMAIN}
  OAuth client ID:     ${OAUTH_CLIENT_ID}
  OAuth client secret: ****
  Plug-in:             ${ESP_PLUGIN_SOURCE}
EOF

generate_manifests
