<a name="top"></a>
![](https://visitor-badge-reloaded.herokuapp.com/badge?page_id=page.id=@user_name.iot-kubernetes-monitoring-esp&color=55acb7&style=for-the-badge&logo=Github&left_text=Visitors)

# <ins>_Monitoring SAS Event Stream Processing on Kubernetes</ins>_

A tutorial that introduces Viya_Manager, an interface to simplify the administration and management of Viya 4 environments on the Cloud.

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

The monitoring stack for SAS ESP was developed to help customers address this need. It can be considered as an extended version of the Viya4 monitoring solution, as it shares the same code base and allows for the installation of the same components in addition to SAS ESP-specific ones. The main difference is that the SAS ESP stack doesn't require the deployment of the Viya4 logging component as it uses Loki instead for log aggregation.

Loki is a horizontally-scalable, highly-available, multi-tenant log aggregation system inspired by Prometheus, designed to be cost effective and easy to operate. Compared to other log aggregation systems, Loki:

```
1. does not index the contents of the logs, but accesses log streams through a set of predefined or user-defined labels.
2. indexes and groups log streams using the same labels as Prometheus, enabling users to seamlessly switch between metrics and logs.
3. is an especially good fit for storing Kubernetes Pod logs. Metadata such as Pod labels is automatically scraped and indexed.
4. has native support in Grafana, which means that Prometheus and Loki panels can coexist on the same dashboard.
```

A Loki-based stack consists of 3 components:

- Promtail, the agent responsible for gathering logs and sending them to Loki.
- The Loki server, responsible for storing logs and processing queries.
- Grafana, for querying and displaying the logs.

<img src="Images/Viya_on_Cloud.jpeg" align="right" width="650" height="360">

[&#11014;](#top) Top
## Getting Started

Before deploying the SAS ESP monitoring stack, make sure to review the list of pre-requisites, install any software that might be required, and customize configuration files as needed.

[&#11014;](#top) Top
### Prerequisites

Viya_Manager runs on Unix platforms only. The following prerequisites must be met before it can be used:

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
 
Download the tarred ZIP [<ins>file</ins>](Code/ESP_Monitoring.tar.gz) containing the SAS ESP monitoring stack on a Unix server, and unpack it on your home folder using the following command:

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
├── github
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

- **Cloud-Providers** holds a subfolder for each supported Cloud provider (**AWS**, **Azure**, and **GCP**). Each subfolder stores three additional entries, **Clusters**, **Credentials**, and **Templates**:
	- **Clusters** contains an entry for every cluster created through Viya_Manager for that specific provider. It can also contain a folder called **Customizations** which holds customized Kubernetes manifests for Viya components. The following list of files and directories are located inside each cluster's folder:
		- Configuration files for the cluster's infrastructure and for the Viya deployment;
		- The KUBECONFIG file to access the cluster;
		- An optional **Keys** folder with the identity key to access the Jump and/or NFS servers if a public IP address was configured for them;
		- A **License-and-certificates** folder containing the license and certificates files for the SAS software order;
		- An **Order** directory storing the asset file for the software order;
		- A **sas-viya-deployment** folder storing the Kubernetes manifests for Viya;
		- An optional **sas-deployment-operator** folder storing the manifests for the Deployment Operator, if installed;
		- An optional file called **sas-viya-sasdeployment.yaml** representing the manifest generated for the Deployment Operator when Viya is deployed using that tool.
	- **Credentials** contains:
		- One or more credential files to access individual subscriptions for the Cloud provider;
		- One or more files containing tenant IDs and optional passwords for their **sasprovider** user when installing Viya in multi-tenant mode;
		- A credential file to access the SAS API portal;
	- **Templates** stores:
		- A Cloud provider configuration template used by the SAS Viya4 Infrastructure as Code tool;
		- A Viya configuration template used by the SAS Viya4 Deployment tool;
		- A file containing the list of regions for the Cloud provider where a cluster can be created.
- **Management** is the folder that stores the Viya_Manager code. The following are found inside it:
	- **Viya_Manager**;
	- A **Deployment** subfolder containing a **Manual** and an **Operator** directory, each holding a set of scripts for the manual and automated deployment of Viya (through the Deployment Operator).
- **Optional-Components** which contains instructions for the installation of extra components. Following is the default list of tools and utilities that comes with Viya_Manager:
	- Microsoft SQL Server;
	- MySQL;
	- PostgreSQL;
	- Filebrowser utility;
	- Jupyter.
- **Viya4-Github-Projects** contains a subfolder for each of the tools that are required to support the deployment and removal of Cloud resources:
 	- **viya4-deployment** stores a README.md file with step-by-step instructions on how to install SAS Viya4 Deployment on Docker;
	- **viya4-iac-aws** stores a README.md file with step-by-step instructions on how to install SAS Viya4 IaC for AWS on Docker;
	- **viya4-iac-azure** stores a README.md file with step-by-step instructions on how to install SAS Viya4 IaC for Azure on Docker;
	- **viya4-iac-gcp** stores a README.md file with step-by-step instructions on how to install SAS Viya4 IaC for GCP on Docker;
	- **viya4-orders-cli** stores a README.md file with step-by-step instructions on how to install SAS Viya4 Orders CLI on Docker.

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