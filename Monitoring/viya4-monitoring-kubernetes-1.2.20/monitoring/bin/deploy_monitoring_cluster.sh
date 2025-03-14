#! /bin/bash

# Copyright © 2020, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

cd "$(dirname $BASH_SOURCE)/../.."
source monitoring/bin/common.sh
source bin/service-url-include.sh

if [ "$OPENSHIFT_CLUSTER" == "true" ]; then
  if [ "${CHECK_OPENSHIFT_CLUSTER:-true}" == "true" ]; then
    log_error "This script should not be run on OpenShift clusters"
    log_error "Run monitoring/bin/deploy_monitoring_openshift.sh instead"
    exit 1
  fi
fi

# Fail fast on invalid auth configuration:
GRAFANA_AUTHENTICATION="${GRAFANA_AUTHENTICATION:-default}"
GRAFANA_AUTH_PROVIDER="${GRAFANA_AUTH_PROVIDER:-viya}"
GRAFANA_AUTH_TYPE="${GRAFANA_AUTH_PROVIDER,,}"
if [ "${GRAFANA_AUTHENTICATION^^}" == "OAUTH" ]; then
    VALID_AUTH_TYPES="viya keycloak uaa"
    [[ "${VALID_AUTH_TYPES}" =~ (^|[[:space:]])$GRAFANA_AUTH_TYPE($|[[:space:]]) ]] || {
        log_error "Invalid Grafana OAuth Provider: ${GRAFANA_AUTH_PROVIDER}"
        exit 1
    }
fi

source bin/tls-include.sh
if verify_cert_generator $MON_NS prometheus alertmanager grafana; then
  log_debug "cert generator check OK [$cert_generator_ok]"
else
  log_error "One or more required TLS certs do not exist and the expected certificate generator mechanism [$cert_generator] is not available to create the missing certs"
  exit 1
fi

helm2ReleaseCheck v4m-$MON_NS
helm2ReleaseCheck prometheus-$MON_NS
checkDefaultStorageClass

export HELM_DEBUG="${HELM_DEBUG:-false}"
export NGINX_NS="${NGINX_NS:-ingress-nginx}"
 
PROM_OPER_USER_YAML="${PROM_OPER_USER_YAML:-$USER_DIR/monitoring/user-values-prom-operator.yaml}"
if [ ! -f "$PROM_OPER_USER_YAML" ]; then
  log_debug "[$PROM_OPER_USER_YAML] not found. Using $TMP_DIR/empty.yaml"
  PROM_OPER_USER_YAML=$TMP_DIR/empty.yaml
fi

if [ "$HELM_DEBUG" == "true" ]; then
  helmDebug="--debug"
fi

if [ -z "$(kubectl get ns $MON_NS -o name 2>/dev/null)" ]; then
  kubectl create ns $MON_NS

  #Container Security: Disable serviceAccount Token Automounting
  disable_sa_token_automount $MON_NS default
fi

if [ "$AIRGAP_DEPLOYMENT" == "true" ]; then
  source bin/airgap-include.sh

  # Check for the image pull secret for the air gap environment and replace placeholders
  checkForAirgapSecretInNamespace "$AIRGAP_IMAGE_PULL_SECRET_NAME" "$MON_NS"
  replaceAirgapValuesInFiles "monitoring/airgap/airgap-values-prom-operator.yaml"

  airgapValuesFile=$updatedAirgapValuesFile

  if [ "$TLS_ENABLE" == "true" ]; then
    replaceAirgapValuesInFiles "monitoring/airgap/airgap-values-prom-operator-tls.yaml"
    airgapTLSValuesFile=$updatedAirgapValuesFile
  else
    airgapTLSValuesFile=$TMP_DIR/empty.yaml
  fi
else
  airgapValuesFile=$TMP_DIR/empty.yaml
  airgapTLSValuesFile=$TMP_DIR/empty.yaml
fi

set -e
log_notice "Deploying monitoring to the [$MON_NS] namespace..."

# Add the prometheus-community Helm repo
helmRepoAdd prometheus-community https://prometheus-community.github.io/helm-charts
# ESP Monitoring
log_debug "Updating Helm repositories..."
helm repo update
# ESP Monitoring

istioValuesFile=$TMP_DIR/empty.yaml
# Istio - Federate data from Istio's Prometheus instance
if [ "$ISTIO_ENABLED" == "true" ]; then
  log_verbose "Including Istio metric federation"
  istioValuesFile=$TMP_DIR/values-prom-operator-tmp.yaml
else
  log_debug "ISTIO_ENABLED flag not set"
  log_debug "Skipping deployment of federated scrape of Istio Prometheus instance"
fi

# Check if Prometheus Operator CRDs are already installed
PROM_OPERATOR_CRD_UPDATE=${PROM_OPERATOR_CRD_UPDATE:-true}
if [ "$PROM_OPERATOR_CRD_UPDATE" == "true" ]; then
  log_verbose "Updating Prometheus Operator custom resource definitions"
  crds=( alertmanagerconfigs alertmanagers prometheuses prometheusrules podmonitors servicemonitors thanosrulers probes )
  for crd in "${crds[@]}"; do
    
    ## Determine CRD URL - if in an airgap environment, look for them in USER_DIR.
    if [ "$AIRGAP_DEPLOYMENT" == "true" ]; then
      crdURL=$USER_DIR/monitoring/prometheus-operator-crd/$PROM_OPERATOR_CRD_VERSION/monitoring.coreos.com_$crd.yaml

      ## Fail if the CRDs could not be located.
      if [ ! -f "$crdURL" ]; then
        log_error "Unable to locate file: [monitoring.coreos.com_$crd.yaml] in"
        log_error "[$USER_DIR/monitoring/prometheus-operator-crd/$PROM_OPERATOR_CRD_VERSION] directory"
        log_error "Please make sure to provide all Prometheus Operator CRDs before running the deployment"
        exit 1
      fi
    else
      crdURL="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$PROM_OPERATOR_CRD_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_$crd.yaml"
    fi 

    if kubectl get crd $crd.monitoring.coreos.com 1>/dev/null 2>&1; then
      kubectl replace -f $crdURL
    else
      kubectl create -f $crdURL
    fi
  done
else
  log_debug "Prometheus Operator CRD update disabled"
fi

# Remove existing DaemonSets in case of an upgrade-in-place
kubectl delete daemonset -n $MON_NS -l app=prometheus-node-exporter --ignore-not-found

# Optional workload node placement support
MON_NODE_PLACEMENT_ENABLE=${MON_NODE_PLACEMENT_ENABLE:-${NODE_PLACEMENT_ENABLE:-false}}
if [ "$MON_NODE_PLACEMENT_ENABLE" == "true" ]; then
  log_verbose "Enabling monitoring components for workload node placement"
  wnpValuesFile="monitoring/node-placement/values-prom-operator-wnp.yaml"
else
  log_debug "Workload node placement support is disabled"
  wnpValuesFile="$TMP_DIR/empty.yaml"
fi

# Optional TLS Support
tlsValuesFile=$TMP_DIR/empty.yaml
tlsPromAlertingEndpointFile=$TMP_DIR/empty.yaml
if [ "$TLS_ENABLE" == "true" ]; then
  apps=( prometheus alertmanager grafana )
  create_tls_certs $MON_NS monitoring ${apps[@]}

  tlsValuesFile=monitoring/tls/values-prom-operator-tls.yaml
  tlsPromAlertingEndpointFile=monitoring/tls/prom-alertendpoint-host-https.yaml
  log_debug "Including TLS response file $tlsValuesFile"

  log_verbose "Provisioning TLS-enabled Prometheus datasource for Grafana"
  grafanaDS=grafana-datasource-prom-https.yaml
  if [ "$MON_TLS_PATH_INGRESS" == "true" ]; then
    grafanaDS=grafana-datasource-prom-https-path.yaml
    tlsPromAlertingEndpointFile=monitoring/tls/prom-alertendpoint-path-https.yaml
  fi
  kubectl delete cm -n $MON_NS --ignore-not-found grafana-datasource-prom-https
  kubectl create cm -n $MON_NS grafana-datasource-prom-https --from-file monitoring/tls/$grafanaDS
  kubectl label cm -n $MON_NS grafana-datasource-prom-https grafana_datasource=1 sas.com/monitoring-base=kube-viya-monitoring

  # node-exporter TLS
  log_verbose "Enabling Prometheus node-exporter for TLS"
  kubectl delete cm -n $MON_NS node-exporter-tls-web-config --ignore-not-found
  sleep 1
  kubectl create cm -n $MON_NS node-exporter-tls-web-config --from-file monitoring/tls/node-exporter-web.yaml
  kubectl label cm -n $MON_NS node-exporter-tls-web-config sas.com/monitoring-base=kube-viya-monitoring
fi

nodePortValuesFile=$TMP_DIR/empty.yaml
PROM_NODEPORT_ENABLE=${PROM_NODEPORT_ENABLE:-false}
if [ "$PROM_NODEPORT_ENABLE" == "true" ]; then
  log_debug "Enabling NodePort access for Prometheus and Alertmanager"
  nodePortValuesFile=monitoring/values-prom-nodeport.yaml
fi

if helm3ReleaseExists prometheus-operator $MON_NS; then
  promRelease=prometheus-operator
  promName=prometheus-operator
else
  promRelease=v4m-prometheus-operator
  promName=v4m
fi
log_verbose "User response file: [$PROM_OPER_USER_YAML]"
log_info "Deploying the kube-prometheus stack. This may take a few minutes ..."
if helm3ReleaseExists $promRelease $MON_NS; then
  log_verbose "Upgrading via Helm ($(date) - timeout 20m)"
else
  grafanaPwd="$GRAFANA_ADMIN_PASSWORD"
  if [ "$grafanaPwd" == "" ]; then
    log_debug "Generating random Grafana admin password"
    showPass="true"
    grafanaPwd="$(randomPassword)"
  fi
  log_verbose "Installing via Helm ($(date) - timeout 20m)"
fi

# See https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-21x-to-22x
if [ "$V4M_CURRENT_VERSION_MAJOR" == "1" ] && [[ "$V4M_CURRENT_VERSION_MINOR" =~ [0-5] ]]; then
  kubectl delete -n $MON_NS --ignore-not-found \
    deployments.apps \
    -l app.kubernetes.io/instance=v4m-prometheus-operator,app.kubernetes.io/name=kube-state-metrics
fi

TRACING_ENABLE="${TRACING_ENABLE:-false}"
if [ "$TRACING_ENABLE" == "false" ]; then
  tempoDSFile=$TMP_DIR/empty.yaml
else
  TEMPO_USER_YAML="${TEMPO_USER_YAML:-$USER_DIR/monitoring/user-values-tempo.yaml}"
  if [ ! -f "$TEMPO_USER_YAML" ]; then
    log_debug "[$TEMPO_USER_YAML] not found. Using $TMP_DIR/empty.yaml"
    TEMPO_USER_YAML=$TMP_DIR/empty.yaml
  fi
  tempoDSFile="monitoring/grafana-datasource-tempo.yaml"
fi 

# Get Helm Chart Name
log_debug "Kube-Prometheus Stack Helm Chart: repo [$KUBE_PROM_STACK_CHART_REPO] name [$KUBE_PROM_STACK_CHART_NAME] version [$KUBE_PROM_STACK_CHART_VERSION]"
chart2install="$(get_helmchart_reference $KUBE_PROM_STACK_CHART_REPO $KUBE_PROM_STACK_CHART_NAME $KUBE_PROM_STACK_CHART_VERSION)"
log_debug "Installing Helm chart from artifact [$chart2install]"

helm $helmDebug upgrade --install $promRelease \
  --namespace $MON_NS \
  -f monitoring/values-prom-operator.yaml \
  -f $airgapValuesFile \
  -f $istioValuesFile \
  -f $tlsValuesFile \
  -f $airgapTLSValuesFile \
  -f $tlsPromAlertingEndpointFile \
  -f $nodePortValuesFile \
  -f $wnpValuesFile \
  -f $PROM_OPER_USER_YAML \
  -f $tempoDSFile \
  --atomic \
  --timeout 20m \
  --set nameOverride=$promName \
  --set fullnameOverride=$promName \
  --set prometheus-node-exporter.fullnameOverride=$promName-node-exporter \
  --set kube-state-metrics.fullnameOverride=$promName-kube-state-metrics \
  --set grafana.fullnameOverride=$promName-grafana \
  --set grafana.adminPassword="$grafanaPwd" \
  --set prometheus.prometheusSpec.alertingEndpoints[0].namespace="$MON_NS" \
  --version $KUBE_PROM_STACK_CHART_VERSION \
  $chart2install

sleep 2

# ESP Monitoring
if [ "$ENABLE_LOKI" == "true" ]; then
   log_debug "Updating Helm repository for Loki"
   helmRepoAdd grafana https://grafana.github.io/helm-charts
   helm repo update

   if [ -d "$USER_DIR/monitoring/loki" ]; then
      LokiCfgDir="$USER_DIR/monitoring/loki"
   else
      LokiCfgDir="monitoring"
   fi

   log_debug "Installing Loki"
   LOKI_RETENTION_PERIOD="${LOKI_RETENTION_PERIOD:-24h}"
   helm $helmDebug upgrade --install loki grafana/loki \
        --namespace "${MON_NS}" \
        --timeout 5m \
        --values "${LokiCfgDir}/values.yaml" \
        --set loki.limits_config.retention_period=$LOKI_RETENTION_PERIOD

   sleep 5

   if [ ! -f "${LokiCfgDir}/promtail-chart-values.yaml" ] || [ ! -s "${LokiCfgDir}/promtail-chart-values.yaml" ]; then
     log_warn "No Promtail values detected, deploying with default values"
     # Ensure file exists for Helm upgrade execution.
     touch "${LokiCfgDir}/promtail-chart-values.yaml"
   fi

   LOKI_LOGFMT=${LOKI_LOGFMT:-docker}

   log_debug "Installing Promtail"
   helm $helmDebug upgrade --install promtail grafana/promtail \
     --values "${LokiCfgDir}/promtail-chart-values.yaml" \
     --set-json "config.snippets.pipelineStages=[{\"${LOKI_LOGFMT,,}\":{}}]" \
     --namespace "${MON_NS}" \
     --timeout 5m

fi
# ESP Monitoring

if [ "$TLS_ENABLE" == "true" ]; then
  log_verbose "Patching Grafana ServiceMonitor for TLS"
  kubectl patch servicemonitor -n $MON_NS $promName-grafana --type=json \
    -p='[{"op": "replace", "path": "/spec/endpoints/0/scheme", "value":"https"},{"op": "replace", "path": "/spec/endpoints/0/tlsConfig", "value":{}},{"op": "replace", "path": "/spec/endpoints/0/tlsConfig/insecureSkipVerify", "value":true}]'
fi

#Container Security: Disable serviceAccount Token Automounting
disable_sa_token_automount $MON_NS v4m-grafana
disable_sa_token_automount $MON_NS sas-ops-acct      #Used w/Prometheus
disable_sa_token_automount $MON_NS v4m-node-exporter
disable_sa_token_automount $MON_NS v4m-alertmanager

#Container Security: Disable Token Automounting at ServiceAccount; enable for Pod
disable_sa_token_automount $MON_NS v4m-kube-state-metrics
enable_pod_token_automount $MON_NS deployment v4m-kube-state-metrics
disable_sa_token_automount $MON_NS v4m-operator
enable_pod_token_automount $MON_NS deployment v4m-operator

log_info "Deploying ServiceMonitors and Prometheus rules"
log_verbose "Deploying cluster ServiceMonitors"

if [ "$TRACING_ENABLE" == "true" ]; then
  log_info "Tracing enabled..."

  ## Check for air gap deployment
  if [ "$AIRGAP_DEPLOYMENT" == "true" ]; then
    source bin/airgap-include.sh

    # Check for the image pull secret for the air gap environment and replace placeholders
    checkForAirgapSecretInNamespace "$AIRGAP_IMAGE_PULL_SECRET_NAME" "$MON_NS"
    replaceAirgapValuesInFiles "monitoring/airgap/airgap-tempo-values.yaml"

    airgapValuesFile=$updatedAirgapValuesFile
  else
    airgapValuesFile=$TMP_DIR/empty.yaml
  fi

  # Add the grafana helm chart repo
  helmRepoAdd grafana https://grafana.github.io/helm-charts
  helm repo update

  # Get Helm Chart Name
  log_debug "Tempo Helm Chart: repo [$TEMPO_CHART_REPO] name [$TEMPO_CHART_NAME] version [$TEMPO_CHART_VERSION]"
  chart2install="$(get_helmchart_reference $TEMPO_CHART_REPO $TEMPO_CHART_NAME $TEMPO_CHART_VERSION)"
  log_debug "Installing Helm chart from artifact [$chart2install]"

  log_info "Installing tempo"
  helm upgrade --install v4m-tempo \
    -n "$MON_NS" \
    -f monitoring/values-tempo.yaml \
    -f "$TEMPO_USER_YAML" \
    -f "$airgapValuesFile" \
    --version "$TEMPO_CHART_VERSION" \
    $chart2install
fi

# NGINX
set +e
kubectl get ns $NGINX_NS 2>/dev/null
if [ $? == 0 ]; then
  nginxFound=true
fi
set -e

if [ "$nginxFound" == "true" ]; then
  log_verbose "NGINX found. Deploying podMonitor to [$NGINX_NS] namespace"
  kubectl apply -n $NGINX_NS -f monitoring/monitors/kube/podMonitor-nginx.yaml 2>/dev/null
fi

# Eventrouter ServiceMonitor
kubectl apply -n $MON_NS -f monitoring/monitors/kube/podMonitor-eventrouter.yaml 2>/dev/null

# Elasticsearch ServiceMonitor
kubectl apply -n $MON_NS -f monitoring/monitors/logging/serviceMonitor-elasticsearch.yaml

# Fluent Bit ServiceMonitors
kubectl apply -n $MON_NS -f monitoring/monitors/logging/serviceMonitor-fluent-bit.yaml
kubectl apply -n $MON_NS -f monitoring/monitors/logging/serviceMonitor-fluent-bit-v2.yaml

# ESP Monitoring
USER_SERVICE_MONITORS="${USER_SERVICE_MONITORS:-false}"
if [ "$USER_SERVICE_MONITORS" == "true" ]; then
   log_verbose "Deploying user ServiceMonitors"

   userMonDir="$USER_DIR/monitoring/monitors"
   if [ -d "$userMonDir" ]; then
      log_info "Deploying user ServiceMonitors from [$userMonDir] ..."
      for f in $userMonDir/*.yaml; do
          # Need to check existence because if there are no matching files,
          # f will include the wildcard character (*)
          if [ -f "$f" ]; then
             log_debug "Deploying ServiceMonitor from file [$f]"
             kubectl apply -n $MON_NS -f $f
          fi
      done
   fi
fi
# ESP Monitoring 

# Rules
log_verbose "Adding Prometheus recording rules"
for f in monitoring/rules/viya/rules-*.yaml; do
  kubectl apply -n $MON_NS -f $f
done

kubectl get prometheusrule -n $MON_NS v4m-kubernetes-apps 2>/dev/null
if [ $? == 0 ]; then
  log_verbose "Patching KubeHpaMaxedOut rule"
  # Fixes the issue of false positives when max replicas == 1
  kubectl patch prometheusrule --type='json' -n $MON_NS v4m-kubernetes-apps --patch "$(cat monitoring/kube-hpa-alert-patch.json)"
else
  log_debug "PrometheusRule $MON_NS/v4m-kubernetes-apps does not exist"
fi

# Elasticsearch Datasource for Grafana
LOGGING_DATASOURCE="${LOGGING_DATASOURCE:-false}"
if [ "$LOGGING_DATASOURCE" == "true" ]; then
  set +e
  log_debug "Creating the logging data source using the create_logging_datasource script"
  monitoring/bin/create_logging_datasource.sh

  if (( $? == 1 )); then
    log_warn "Unable to configure the logging data source at this time."
    log_warn "Please address the errors and re-run the follow command to create the data source at a later time:"
    log_warn "monitoring/bin/create_logging_datasource.sh"
  fi
  set -e
else
  log_debug "LOGGING_DATASOURCE not set"
  log_debug "Skipping creation of logging data source for Grafana"
fi

# ESP Monitoring
ENABLE_LOKI="${ENABLE_LOKI:-false}"
if [ "$ENABLE_LOKI" == "true" ]; then
   if [ -d "$USER_DIR/monitoring/loki" ]; then
      LokiCfgDir="$USER_DIR/monitoring/loki"
   else
      LokiCfgDir="monitoring"
   fi

   log_verbose "Provisioning Loki datasource for Grafana"
   kubectl delete secret -n $MON_NS --ignore-not-found grafana-datasource-loki
   kubectl create secret generic -n $MON_NS grafana-datasource-loki --from-file $LokiCfgDir/grafana-datasource-loki.yaml
   kubectl label secret -n $MON_NS grafana-datasource-loki grafana_datasource=1 sas.com/monitoring-base=kube-viya-monitoring
else
   log_debug "LOKI_DATASOURCE not set"
   log_debug "Skipping creation of Loki datasource for Grafana"
fi

GRAFANA_AUTHENTICATION="${GRAFANA_AUTHENTICATION:-default}"
if [ "${GRAFANA_AUTHENTICATION^^}" == "LDAP" ] || [ "${GRAFANA_AUTHENTICATION^^}" == "OAUTH" ]; then
   log_verbose "Configuring Grafana authentication to [${GRAFANA_AUTHENTICATION^^}]"

   AUTH_DIR="$(realpath "${USER_DIR}")/monitoring/grafana/authentication/${GRAFANA_AUTHENTICATION^^}"
   ESP_GRAFANA_PLUGIN_VERSION="${ESP_GRAFANA_PLUGIN_VERSION:-null}"
   if [ "$ESP_GRAFANA_PLUGIN_VERSION" != "null" ]; then
      if [ "${GRAFANA_AUTHENTICATION^^}" == "OAUTH" ]; then
         $USER_DIR/monitoring/grafana/esp-plugin/grafana-esp-plugin-main/install/configure-grafana.sh "${AUTH_DIR}" "${ESP_GRAFANA_PLUGIN_VERSION}" "${GRAFANA_AUTH_TYPE}"
      else
         log_verbose "Authentication set to [${GRAFANA_AUTHENTICATION^^}]. Disabling ESP Grafana plugin installation."
      fi
   fi

   # Apply configmaps and patch Grafana
   for f in $AUTH_DIR/configmaps/*.yaml; do
       kubectl apply -n $MON_NS -f $f
   done

   for f in $AUTH_DIR/patches/*.yaml; do
       kubectl patch deployment v4m-grafana -n $MON_NS --patch-file $f
   done

   if [ "${GRAFANA_AUTHENTICATION^^}" == "OAUTH" ]; then
      if [ -d "$USER_DIR/monitoring/grafana" ]; then
         SASESPCfgDir="$USER_DIR/monitoring/grafana"
      else
         SASESPCfgDir="monitoring"
      fi

      log_verbose "Provisioning SAS Event Stream Manager datasource for Grafana"
      kubectl delete secret -n $MON_NS --ignore-not-found grafana-datasource-sas-event-stream-manager
      kubectl create secret generic -n $MON_NS grafana-datasource-sas-event-stream-manager --from-file $SASESPCfgDir/grafana-datasource-SAS-Event-Stream-Manager.yaml
      kubectl label secret -n $MON_NS grafana-datasource-sas-event-stream-manager grafana_datasource=1 sas.com/monitoring-base=kube-viya-monitoring

      log_verbose "Provisioning SAS Event Stream Processing Studio datasource for Grafana"
      kubectl delete secret -n $MON_NS --ignore-not-found grafana-datasource-sas-event-stream-processing-studio
      kubectl create secret generic -n $MON_NS grafana-datasource-sas-event-stream-processing-studio --from-file $SASESPCfgDir/grafana-datasource-SAS-Event-Stream-Processing-Studio.yaml
      kubectl label secret -n $MON_NS grafana-datasource-sas-event-stream-processing-studio grafana_datasource=1 sas.com/monitoring-base=kube-viya-monitoring

      log_verbose "Registering Grafana as an OAUTH client"
      $USER_DIR/monitoring/grafana/esp-plugin/grafana-esp-plugin-main/install/register-oauth-client-"${GRAFANA_AUTH_TYPE}".sh
   fi

   sleep 5
else
   log_verbose "Configuring Grafana with default authentication"
   AUTH_DIR="$(realpath "${USER_DIR}")/monitoring/grafana/authentication/default"

   # Apply configmaps and patch Grafana
   for f in $AUTH_DIR/patches/*.yaml; do
     kubectl patch deployment v4m-grafana -n $MON_NS --patch-file $f
   done
fi
# ESP Monitoring

echo ""
monitoring/bin/deploy_dashboards.sh

set +e
# call function to get HTTP/HTTPS ports from ingress controller
get_ingress_ports

# get URLs for Grafana, Prometheus and AlertManager
gf_url=$(get_service_url $MON_NS v4m-grafana  "$TLS_ENABLE")
# pr_url=$(get_url $MON_NS v4m-prometheus  "$TLS_ENABLE")
# am_url=$(get_url $MON_NS v4m-alertmanager  "$TLS_ENABLE")
set -e

# If a deployment with the old name exists, remove it first
if helm3ReleaseExists v4m $MON_NS; then
  log_verbose "Removing outdated SAS Viya Monitoring Helm chart release from [$MON_NS] namespace"
  helm uninstall -n "$MON_NS" "v4m"
fi

if ! deployV4MInfo "$MON_NS" "v4m-metrics"; then
  log_warn "Unable to update SAS Viya Monitoring Helm chart release"
fi

# Print URL to access web apps
log_notice ""
log_notice "GRAFANA: "
if [ ! -z "$gf_url" ]; then
   log_notice "  $gf_url"
else
   log_notice " It was not possible to determine the URL needed to access Grafana. Note  "
   log_notice " that this is not necessarily a sign of a problem; it may only reflect an "
   log_notice " ingress or network access configuration that this script does not handle."
fi
   log_notice ""

#log_notice ""
#log_notice "================================================================================"
#log_notice "==                    Accessing the monitoring applications                   =="
#log_notice "==                                                                            =="
#log_notice "== ***GRAFANA***                                                              =="
#if [ ! -z "$gf_url" ]; then
#   log_notice "==  You can access Grafana via the following URL:                             =="
#   log_notice "==   $gf_url  =="
#   log_notice "==                                                                            =="
#else
#   log_notice "== It was not possible to determine the URL needed to access Grafana. Note    =="
#   log_notice "== that this is not necessarily a sign of a problem; it may only reflect an   =="
#   log_notice "== ingress or network access configuration that this script does not handle.  =="
#   log_notice "==                                                                            =="
#fi
#log_notice "== Note: These URLs may be incorrect if your ingress and/or other network     =="
#log_notice "==       configuration includes options this script does not handle.          =="
#log_notice "================================================================================"
#log_notice ""

if [ "$showPass" == "true" ]; then
  # Find the grafana pod
 
  log_notice " Generated Grafana admin password is: $grafanaPwd"
  log_notice " To change the password, run the following script (replace myNewPassword with an updated password):"
  log_notice " monitoring/bin/change_grafana_admin_password.sh -p myNewPassword"
fi

log_message ""
log_notice " Successfully deployed components to the [$MON_NS] namespace"
