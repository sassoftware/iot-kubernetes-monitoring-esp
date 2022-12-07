<a name="top"></a>
![](https://visitor-badge-reloaded.herokuapp.com/badge?page_id=page.id=@user_name.iot-kubernetes-monitoring-esp&color=55acb7&style=for-the-badge&logo=Github&left_text=Visitors)

# <ins>_Monitoring SAS Event Stream Processing on Kubernetes</ins>_

<img src="Images/Viya_on_Cloud.jpeg" align="right" width="1000" height="530">
<b></b>
A tutorial about a solution to monitor SAS Event Processing projects.

## Table of Contents

* [Overview](#overview)
* [Getting Started](#getting-started)
	* [Prerequisites](#prerequisites)
	* [Installation](#installation)
  	* [Viya4 Tools](#viya4-tools)
		* [Cloud Provider Credentials](#cloud-providers-credentials)
		* [SAS API Portal Credentials](#sas-api-portal-credentials)
	* [Running Viya_Manager](#running-viya_manager)
		* [Cloud Infrastructure Tasks](#cloud-infrastructure)
			* [-Apply](#cloud-infrastructure)
			* [-Destroy](#cloud-infrastructure)
			* [-Output](#cloud-infrastructure)
			* [-Plan](#cloud-infrastructure)
		* [Viya Installation Tasks](#viya-installation)
			* [-Install](#viya-installation)
			* [-Uninstall](#viya-installation)
		* [Viya Management Tasks](#viya-management)
			* [-Gencert](#viya-management)		
			* [-Operator](#viya-management)
			* [-Start](#viya-management)
			* [-Stop](#viya-management)
			* [-Status](#viya-management)
			* [-Version](#viya-management)
	* [Examples](#examples)
	* [Troubleshooting](#troubleshooting)
* [Conclusion](#conclusion)
* [Contributing](#contributing)
* [License](#license)
* [Additional Resources](#additional-resources)

[&#11014;](#top) Top
## Overview

The current Viya4 monitoring solution provides system administrators with a powerful tool to monitor installations as a whole. Resource oversight, coupled with the ability to aggregate log information and generate alerts make it easier to admnister deployments regardless of their complexity. While this is helpful at a high level, within Viya, smaller ecosystems like the SAS Event Stream Processing (SAS ESP) require a more specialized approach to  both real time and historical monitoring of projects.

The monitoring stack for SAS ESP was developed to help customers address this need. It can be considered as an extended version of the [Viya4 Monitoring](https://github.com/sassoftware/viya4-monitoring-kubernetes) solution, as it shares the same code base and allows for the installation of the same components in addition to SAS ESP-specific ones. The main difference is that the SAS ESP stack doesn't require the deployment of the Viya4 logging component as it uses Loki instead for log aggregation.

A Grafana Lab product, Loki is a horizontally-scalable, highly-available, multi-tenant log aggregation system inspired by Prometheus, designed to be cost effective and easy to operate. Compared to other log aggregation systems, Loki:

```
- does not index the contents of the logs, but accesses log streams through a set of predefined or user-defined labels.
- indexes and groups log streams using the same labels as Prometheus, enabling users to seamlessly switch between metrics and logs.
- is an especially good fit for storing Kubernetes logs. Metadata labels are automatically scraped and indexed.
- has native support in Grafana, which means that Prometheus and Loki panels can coexist on the same dashboards.
```

A Loki-based stack consists of 3 components:

- Promtail, the agent responsible for gathering logs and sending them to Loki.
- The Loki server, responsible for storing logs and processing queries.
- Grafana, for querying and displaying the logs.

[&#11014;](#top) Top
## Getting Started

Before deploying the SAS ESP monitoring stack, make sure to review the list of pre-requisites, install any software that might be required, and customize configuration files as needed.

[&#11014;](#top) Top
### Prerequisites

The SAS ESP Monitoring stack can be deployed from Unix platforms only. The following prerequisites must be met before it can be used:

- The **kubectl** utility must be installed on the server where the monitoring stack will be installed;
- A local instance of **Helm** is required for the deployment of the monitoring components.
- The deployment includes:
```
	loki                       	loki-simple-scalable-1.8.11          	2.6.1
	prometheus-pushgateway         	prometheus-pushgateway-1.11.0        	1.3.0
	promtail                       	promtail-6.7.1                       	2.7.0
	v4m-metrics                    	v4m-1.2.7-SNAPSHOT                   	1.2.7-SNAPSHOT
	v4m-prometheus-operator        	kube-prometheus-stack-41.7.3         	0.60.1
	
	[based on the current chart names and versions]
```

[&#11014;](#top) Top
### Installation
 
Download the tarred ZIP [<ins>file</ins>](Code/ESP_Monitoring.tar.gz) containing the SAS ESP monitoring stack on a Unix server, and unpack it in a folder of your choice using the following command:

**tar -xzv ESP_Monitor.tar.gz --dir=${HOME}**

<details><summary><b><i>Click</i></b> to view the directory structure generated by the execution of the command:</summary>
<p>

```
Monitoring
├── customizations
│   └── monitoring
│       ├── dashboards
│       ├── loki
│       └── monitors
└── viya4-monitoring-kubernetes-main
    ├── bin
    ├── img
    ├── logging
    │   ├── bin
    │   ├── esexporter
    │   ├── eventrouter
    │   ├── fb
    │   ├── node-placement
    │   ├── opensearch
    │   │   ├── bin
    │   │   ├── rbac
    │   │   └── securityconfig
    │   ├── openshift
    │   ├── osd
    │   │   ├── cluster_admins
    │   │   ├── common
    │   │   ├── namespace
    │   │   └── tenant
    │   └── tls
    ├── monitoring
    │   ├── bin
    │   ├── dashboards
    │   │   ├── istio
    │   │   ├── kube
    │   │   ├── logging
    │   │   ├── nginx
    │   │   ├── pgmonitor
    │   │   │   └── disabled
    │   │   ├── rabbitmq
    │   │   ├── viya
    │   │   ├── viya-logs
    │   │   └── welcome
    │   ├── monitors
    │   │   ├── kube
    │   │   ├── logging
    │   │   └── viya
    │   ├── multitenant
    │   │   ├── dashboards
    │   │   ├── openshift
    │   │   └── tls
    │   ├── node-placement
    │   ├── openshift
    │   ├── rules
    │   │   └── viya
    │   └── tls
    ├── samples
    │   ├── azure-deployment
    │   │   ├── logging
    │   │   └── monitoring
    │   ├── azure-monitor
    │   ├── cloudwatch
    │   ├── external-alertmanager
    │   │   └── monitoring
    │   ├── generic-base
    │   │   ├── logging
    │   │   └── monitoring
    │   │       └── dashboards
    │   ├── gke-monitoring
    │   ├── ingress
    │   │   ├── host-based-ingress
    │   │   │   ├── logging
    │   │   │   └── monitoring
    │   │   └── path-based-ingress
    │   │       ├── logging
    │   │       └── monitoring
    │   ├── namespace-monitoring
    │   │   └── monitoring
    │   └── tls
    │       ├── host-based-ingress
    │       │   ├── logging
    │       │   └── monitoring
    │       └── path-based-ingress
    │           ├── logging
    │           └── monitoring
    ├── v4m-chart
    │   └── templates
    └── v4m-container
        ├── kubeconfig
        └── user_dir
```
Where:

- **customizations** is the folder that contains the Loki/Promtail artifacts, the sample Grafana dashboards for ESP, the Kubernetes ingress definitions for the monitoring components, and the **user.env** with custom install options settings:
	- **user.env** contains custom option settings for the deployment of the monitoring components. If necessary, review and modify the settings before deploying. A couple of considerations apply:
		- **LOKI_ENABLED** must be set to **True** for SAS ESP project logs to be monitored;
		- **LOKI_LOGFMT** must be set according to the format used by Kubernetes to write logs. As of the writing of this document, the format is **cri** for Azure, and **docker** for other providers like AWS.
	- **user-values-prom-operator-host/path-based.yaml.sample** contain sample settings for host or path-based access to the monitoring components. Path-based access is used for cloud-based deployments. When installing, copy the appropriate sample file to **user-values-prom-operator.yaml** in the same folder and customize it according to your needs.
	- **dashboards** contains the sample Grafana dashboards.
	- **loki** stores the artifacts used to install Loki/Promtail.
	- **monitors** contains the service monitor definition for Loki/Promtail.
- **viya4-monitoring-kubernetes-main** is the folder created by untarring the monitoring stack binaries. It contains configuration files and scripts for both the monitoring and logging components of Viya. The content of this folder should never be modified.

</p>
</details>

Proceed with the install as follows:

- Navigate to the "customization/monitoring" folder created by the unpacking of the binaries;
- Replace/update the content of the **user-values-prom-operator.yaml** file based on whether you need host or path-based ingresses for the monitoring components. The latter are normally used for cloud deployments;
- Review the content of the **user.env** file and customize it as needed. For a description of the options, please refer to the [Viya4 Monitoring for Kubernetes](https://github.com/sassoftware/viya4-monitoring-kubernetes) page;
- Set the USER_DIR= environment variable to the full path of the **customization** folder and export it as shown in the following example:

  export USER_DIR=/root/Monitoring/customizations
 
- Navigate to the **<monitoring stack root folder>/viya4-monitoring-kubernetes-main/monitoring/bin** folder, and install the monitoring stack using the following command:

  ./deploy_monitoring_cluster

<details><summary><b><i>Click</i></b> to view the a sample installation log:</summary>
<p>
User root   Host myserver   Current directory /root/Viya_Manager/Optional-Components/Monitoring/viya4-monitoring-kubernetes-main/monitoring/bin
> export USER_DIR=/root/Viya_Manager/Optional-Components/Monitoring/customizations

User root   Host myserver   Current directory /root/Viya_Manager/Optional-Components/Monitoring/viya4-monitoring-kubernetes-main/monitoring/bin
> ./deploy_monitoring_cluster.sh
INFO User directory: /root/Viya_Manager/Optional-Components/Monitoring/customizations
INFO Helm client version: 3.7.1
INFO Kubernetes client version: v1.23.8
INFO Kubernetes server version: v1.23.8
INFO Loading user environment file: /root/Viya_Manager/Optional-Components/Monitoring/customizations/monitoring/user.env

namespace/monitoring created
Deploying monitoring to the [monitoring] namespace...
"prometheus-community" already exists with the same configuration, skipping
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "nfs" chart repository
...Successfully got an update from the "opensearch" chart repository
...Successfully got an update from the "fluent" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "jupyterhub" chart repository
...Successfully got an update from the "gitlab" chart repository
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "prometheus-community" chart repository
...Successfully got an update from the "nginx" chart repository
Update Complete. ⎈Happy Helming!⎈
INFO Updating Prometheus Operator custom resource definitions
customresourcedefinition.apiextensions.k8s.io/alertmanagerconfigs.monitoring.coreos.com replaced
customresourcedefinition.apiextensions.k8s.io/alertmanagers.monitoring.coreos.com replaced
customresourcedefinition.apiextensions.k8s.io/prometheuses.monitoring.coreos.com replaced
customresourcedefinition.apiextensions.k8s.io/prometheusrules.monitoring.coreos.com replaced
customresourcedefinition.apiextensions.k8s.io/podmonitors.monitoring.coreos.com replaced
customresourcedefinition.apiextensions.k8s.io/servicemonitors.monitoring.coreos.com replaced
customresourcedefinition.apiextensions.k8s.io/thanosrulers.monitoring.coreos.com replaced
customresourcedefinition.apiextensions.k8s.io/probes.monitoring.coreos.com replaced
No resources found
INFO Enabling monitoring components for workload node placement
INFO User response file: [/root/Viya_Manager/Optional-Components/Monitoring/customizations/monitoring/user-values-prom-operator.yaml]
INFO Deploying the kube-prometheus stack. This may take a few minutes ...
INFO Installing via Helm (Wed Dec 7 12:53:50 UTC 2022 - timeout 20m)
Release "v4m-prometheus-operator" does not exist. Installing it now.
NAME: v4m-prometheus-operator
LAST DEPLOYED: Wed Dec  7 12:53:53 2022
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=v4m-prometheus-operator"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.
"grafana" already exists with the same configuration, skipping
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "nfs" chart repository
...Successfully got an update from the "opensearch" chart repository
...Successfully got an update from the "fluent" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "gitlab" chart repository
...Successfully got an update from the "jupyterhub" chart repository
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "prometheus-community" chart repository
...Successfully got an update from the "nginx" chart repository
Update Complete. ⎈Happy Helming!⎈
Release "loki" does not exist. Installing it now.
NAME: loki
LAST DEPLOYED: Wed Dec  7 12:54:37 2022
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
NOTES:
***********************************************************************
 Welcome to Grafana Loki
 Chart version: 1.8.11
 Loki version: 2.6.1
***********************************************************************

Installed components:
* gateway
* read
* write

This chart requires persistence and object storage to work correctly.
Queries will not work unless you provide a `loki.config.common.storage` section with
a valid object storage (and the default `filesystem` storage set to `null`), as well
as a valid `loki.config.schema_config.configs` with an `object_store` that
matches the common storage section.

For example, to use MinIO as your object storage backend:

loki:
  config:
    common:
      storage:
        filesystem: null
        s3:
          endpoint: minio.minio.svc.cluster.local:9000
          insecure: true
          bucketnames: loki-data
          access_key_id: loki
          secret_access_key: supersecret
          s3forcepathstyle: true
    schema_config:
      configs:
        - from: "2020-09-07"
          store: boltdb-shipper
          object_store: s3
          schema: v11
          index:
            period: 24h
            prefix: loki_index_
Release "promtail" does not exist. Installing it now.
NAME: promtail
LAST DEPLOYED: Wed Dec  7 12:55:02 2022
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
***********************************************************************
 Welcome to Grafana Promtail
 Chart version: 6.7.1
 Promtail version: 2.7.0
***********************************************************************

Verify the application is working by running these commands:
* kubectl --namespace monitoring port-forward daemonset/promtail 3101
* curl http://127.0.0.1:3101/metrics
configmap/promtail created
daemonset.apps "promtail" deleted
daemonset.apps/promtail created
service/promtail created
INFO Deploying ServiceMonitors and Prometheus rules
INFO Deploying cluster ServiceMonitors
NAME            STATUS   AGE
ingress-nginx   Active   48d
INFO NGINX found. Deploying podMonitor to [ingress-nginx] namespace
podmonitor.monitoring.coreos.com/ingress-nginx configured
podmonitor.monitoring.coreos.com/eventrouter created
servicemonitor.monitoring.coreos.com/elasticsearch created
servicemonitor.monitoring.coreos.com/fluent-bit created
servicemonitor.monitoring.coreos.com/fluent-bit-v2 created
INFO Deploying user ServiceMonitors
INFO Deploying user ServiceMonitors from [/root/Viya_Manager/Optional-Components/Monitoring/customizations/monitoring/monitors] ...
servicemonitor.monitoring.coreos.com/sas-esp-server created
INFO Adding Prometheus recording rules
prometheusrule.monitoring.coreos.com/sas-launcher-job-rules created
NAME                  AGE
v4m-kubernetes-apps   71s
INFO Patching KubeHpaMaxedOut rule
prometheusrule.monitoring.coreos.com/v4m-kubernetes-apps patched
INFO Provisioning Loki datasource for Grafana
secret/grafana-datasource-loki created
secret/grafana-datasource-loki labeled

INFO Deploying dashboards to the [monitoring] namespace ...
INFO Deploying welcome dashboards
configmap/viya-welcome-dashboard created
configmap/viya-welcome-dashboard labeled
INFO Deploying Kubernetes cluster dashboards
configmap/k8s-cluster-dashboard created
configmap/k8s-cluster-dashboard labeled
configmap/k8s-deployment-dashboard created
configmap/k8s-deployment-dashboard labeled
configmap/perf-k8s-container-util created
configmap/perf-k8s-container-util labeled
configmap/perf-k8s-headroom created
configmap/perf-k8s-headroom labeled
configmap/perf-k8s-node-util-detail created
configmap/perf-k8s-node-util-detail labeled
configmap/perf-k8s-node-util created
configmap/perf-k8s-node-util labeled
configmap/prometheus-alerts created
configmap/prometheus-alerts labeled
INFO Deploying Logging dashboards
configmap/elasticsearch-dashboard created
configmap/elasticsearch-dashboard labeled
configmap/fluent-bit created
configmap/fluent-bit labeled
INFO Deploying SAS Viya dashboards
configmap/cas-dashboard created
configmap/cas-dashboard labeled
configmap/go-service-dashboard created
configmap/go-service-dashboard labeled
configmap/java-service-dashboard created
configmap/java-service-dashboard labeled
configmap/postgres-dashboard created
configmap/postgres-dashboard labeled
configmap/sas-launched-jobs-node created
configmap/sas-launched-jobs-node labeled
configmap/sas-launched-jobs-users created
configmap/sas-launched-jobs-users labeled
INFO Deploying Postgres dashboards
configmap/pg-details created
configmap/pg-details labeled
INFO Deploying RabbitMQ dashboards
configmap/erlang-memory-allocators created
configmap/erlang-memory-allocators labeled
configmap/rabbitmq-overview created
configmap/rabbitmq-overview labeled
INFO Deploying NGINX dashboards
configmap/nginx-dashboard created
configmap/nginx-dashboard labeled
INFO Deploying user dashboards from [/root/Viya_Manager/Optional-Components/Monitoring/customizations/monitoring/dashboards]
configmap/cpu-memory-and-logs-usage created
configmap/cpu-memory-and-logs-usage labeled
configmap/log-analysis-by-project created
configmap/log-analysis-by-project labeled
configmap/viya-welcome-dashboard configured
configmap/viya-welcome-dashboard unlabeled
INFO Deployed dashboards to the [monitoring] namespace
INFO Updating Viya Monitoring for Kubernetes version information
Release "v4m-metrics" does not exist. Installing it now.
NAME: v4m-metrics
LAST DEPLOYED: Wed Dec  7 12:55:32 2022
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Viya Monitoring for Kubernetes 1.2.7-SNAPSHOT is installed

GRAFANA:
  http://iot.viya-azure-3.unx.sas.com/grafana

 Successfully deployed components to the [monitoring] namespace
</p>
</details>





# Set Up a Kubernetes Monitoring Stack for SAS Event Stream Processing on Kubernetes
 
## Table of Contents

* [Overview](#overview)
* [Kubernetes Overview](#kubernetes-overview)
	* [Master Components](#master-components)
		* [kube-apiserver](#kube-apiserver)
		* [etcd](#etcd)
		* [kube-scheduler](#kube-scheduler)
		* [kube-controller-manager](#kube-controller-manager)
		* [cloud-controller-manager](#cloud-controller-manager)
	* [Node Components](#node-components)
		* [kubelet](#kubelet)
		* [kube-proxy](#kube-proxy)
		* [Container Runtime](#container-runtime)
* [What to Monitor](#what-to-monitor)
	* [Kubernetes Cluster](#kubernetes-cluster)
	* [Pods](#pods)
* [Monitoring Options](#monitoring-options)
	* [DaemonSets](#daemonsets)
	* [Prometheus](#prometheus)
* [Operators](#operators)
	* [Kubernetes Operator](#kubernetes-operator)
	* [Prometheus Operator](#prometheus-operator)
		* [Helm](#helm)
* [How to Monitor](#how-to-monitor)
	* [Prometheus exporters](#prometheus-exporters)
	* [Grafana](#grafana)
	* [Loki](#loki)
	* [SAS Event Stream Processing and Prometheus](#sas-event-stream-processing-and-prometheus)
* [Contributing](#contributing)
* [License](#license)

# SAS® Viya® Monitoring for Kubernetes

SAS® Viya® Monitoring for Kubernetes provides simple scripts and customization
options to deploy monitoring, alerts, and log aggregation for SAS Viya 4.

Monitoring and logging can be deployed independently or together. There are
no hard dependencies between the two.

## Monitoring - Metrics and Alerts

The monitoring solution includes these components and your right to use each
such component is governed by its applicable open source license:

- [Prometheus Operator](https://github.com/coreos/prometheus-operator)
  - [Prometheus](https://prometheus.io/docs/introduction/overview/)
  - [Alertmanager](https://prometheus.io/docs/alerting/alertmanager/)
  - [Grafana](https://grafana.com/)
- Prometheus Exporters
  - [node-exporter](https://github.com/prometheus/node_exporter)
  - [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
  - [Prometheus Adapter for Kubernetes Metrics APIs](https://github.com/DirectXMan12/k8s-prometheus-adapter)
  - [Prometheus Pushgateway](https://github.com/prometheus/pushgateway)
- Alert definitions
- Grafana dashboards
  - Kubernetes cluster monitoring
  - SAS CAS Overview
  - SAS Java Services
  - SAS Go Services
  - RabbitMQ
  - Postgres
  - Fluent Bit
  - Elasticsearch
  - Istio
  - NGINX

This is an example of a Grafana dashboard for cluster monitoring.
![Grafana - Cluster Monitoring](img/screenshot-grafana-cluster.png)

This is an example of a Grafana dashboard for SAS CAS monitoring.
![Grafana - SAS CAS Monitoring](img/screenshot-grafana-cas.png)

See the documentation at [SAS Viya: Monitoring](https://documentation.sas.com/?cdcId=sasadmincdc&cdcVersion=default&docsetId=calmonitoring&docsetTarget=titlepage.htm)
for more information about using the monitoring components.

## Logging - Aggregation, Searching, & Filtering

  This is an example of OpenSearch Dashboards displaying log message volumes.

  ![OpenSearch Dashboards - Log Message Volume Dashboard](img/screenshot-logs-dashboard.png)

For information about the application components deployed by the log-monitoring solution, the prerequisites, and more, see [Getting Started](https://documentation.sas.com/?cdcId=sasadmincdc&cdcVersion=default&docsetId=callogging&docsetTarget=p069v6xx0f500zn12n18vel967w3.htm) in the SAS Viya Administration Help Center.

## Installation

### Monitoring

See the [monitoring README](monitoring/README.md) to deploy the monitoring
components, including Prometheus Operator, Prometheus, Alertmanager, Grafana,
metric exporters, service monitors, and custom dashboards.

### Logging

See the documentation at [SAS Viya: Logging](https://documentation.sas.com/?cdcId=sasadmincdc&cdcVersion=default&docsetId=callogging&docsetTarget=titlepage.htm)
for information about deployment.

## Customization

For most deployment scenarios, the process of customizing the monitoring and
logging deployments consists of:

- creating the location for your local customization files
- using the `USER_DIR` environment variable to specify the location of the
  customization files
- copying the customization files from one of the provided samples to your
  local directory
- specifying customization variables and parameters in the customization files

Other scenarios use different customization steps that are specific to each scenario.

Samples are provided for several common deployment scenarios. Each sample
includes detailed information about the customization process and values for
the scenario.

See the [monitoring README](monitoring/README.md) and [SAS Viya: Logging](https://documentation.sas.com/?cdcId=sasadmincdc&cdcVersion=default&docsetId=callogging&docsetTarget=titlepage.htm)
for detailed information about the customization process and about determining
valid customization values. See the README file for each [sample](samples/README.md)
for detailed information about customization for each deployment scenario.

### Default StorageClass

The default cluster StorageClass is used for both monitoring and logging
unless the value is overidden in the  `user-*.yaml` files for monitoring or
logging. The deployment scripts issue a warning if no default StorageClass is
available, even if the value is properly set by the user. In this case,
you can safely ignore the warning.
