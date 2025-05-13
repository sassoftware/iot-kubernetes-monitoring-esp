<a name="top"></a>
![](https://vbr.wocr.tk/badge?page_id=page.id=@user_name.iot-kubernetes-monitoring-esp&color=55acb7&style=for-the-badge&logo=Github&left_text=Visitors)

# <ins>_Monitoring SAS Event Stream Processing on Kubernetes</ins>_

_A guide for monitoring SAS Event Stream Processing resources._

## Table of Contents

* [Overview](#overview)
* [What's New](#whats-new)
* [Preparing to Deploy the Monitoring Components](#preparing-to-deploy-the-monitoring-components)
  * [Check Prerequisites](#check-prerequisites)
  * [Prepare Your Working Directory](#prepare-your-working-directory)
  * [Review the Deployment Configuration](#review-the-deployment-configuration)
* [Deploying the Monitoring Components](#deploying-the-monitoring-components)
  * [Deploy SAS Event Stream Processing Monitoring for Kubernetes](#deploy-sas-event-stream-processing-monitoring-for-kubernetes)
  * [Deploy the SAS Viya Monitoring for Kubernetes Dashboards](#deploy-the-sas-viya-monitoring-for-kubernetes-dashboards)
  * [Deploy Custom Dashboards](#deploy-custom-dashboards)
* [Using the Monitoring Components](#using-the-monitoring-components)
  * [Access the Dashboards](#access-the-dashboards)
  * [Adding Grafana Alert Rules](#adding-grafana-alert-rules)
* [Uninstalling](#uninstalling)
* [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [License](#license)
* [Additional Resources](#additional-resources)


[&#11014;](#top) Top
## Overview

The current monitoring solution for the SAS Viya platform provides system administrators with a powerful tool to monitor deployments
as a whole. Resource oversight, coupled with the ability to aggregate log information and generate alerts, makes it
easier to administer deployments regardless of their complexity. This is helpful at a high level, within the SAS Viya platform, but
smaller ecosystems like SAS Event Stream Processing require a more specialized approach to both real time and historical
monitoring of projects.

SAS Event Stream Processing Monitoring for Kubernetes was developed to help customers address this need. SAS Event Stream Processing Monitoring for Kubernetes can be deployed when SAS Event Stream Processing is deployed with the SAS Viya platform or when standalone SAS Event Stream Processing is deployed. SAS Event Stream Processing Monitoring for Kubernetes  can be
considered as an extended version of [SAS Viya Monitoring for Kubernetes](https://github.com/sassoftware/viya4-monitoring-kubernetes),
as it shares the same code base and allows for the deployment of the same components in addition to those specific to
SAS Event Stream Processing. The main difference is that SAS Event Stream Processing Monitoring for Kubernetes does not
require the deployment of the logging layer of the SAS Viya platform, as it instead uses Loki for log aggregation.

A Grafana Lab product, Loki is a horizontally scalable, highly available, multi-tenant log aggregation system inspired
by Prometheus, designed to be cost-effective and easy to operate. Compared to other log aggregation systems, Loki has
the following benefits:

* Loki does not index the contents of the logs, but accesses log streams through a set of predefined or user-defined
  labels.
* Loki indexes and groups log streams using the same labels as Prometheus, enabling users to seamlessly switch between
  metrics and logs.
* Loki is an especially good fit for storing Kubernetes logs. Metadata labels are automatically scraped and indexed.
* Loki has native support in Grafana, which means that Prometheus and Loki panels can coexist on the same dashboards.

A Loki-based system consists of 3 components:

* Promtail, the agent responsible for gathering logs and sending them to Loki.
* The Loki server, responsible for storing logs and processing queries.
* Grafana, for querying and displaying the logs.

SAS Event Stream Processing Monitoring for Kubernetes gives system administrators metrics to accurately measure CPU
usage and memory consumption. Real-time and historical log information is also made available at the individual project
level to help debug any issues a project might encounter during its execution. The result is a faster monitoring of SAS
Event Stream Processing resources to help troubleshoot issues before they reach the potential to negatively affect the
overall performance of the environment.

[&#11014;](#top) Top
## What's New

SAS Event Stream Processing Monitoring for Kubernetes now supports configuration of the Loki retention period, allowing logs to be deleted after a specified period of time.

[&#11014;](#top) Top
## Preparing to Deploy the Monitoring Components

[&#11014;](#top) Top
### Check Prerequisites

When SAS Event Stream Processing is deployed with the SAS Viya platform or when standalone SAS Event Stream Processing is deployed, you can deploy SAS Event Stream Processing Monitoring for Kubernetes.

SAS Event Stream Processing Monitoring for Kubernetes can be deployed from Unix platforms only and, to successfully
follow this guide, the following must be installed on the local computer from which the deployment of monitoring
components in the Kubernetes cluster will be initiated:

* The [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) command-line interface (CLI);
* The [Helm](https://helm.sh/) CLI.

### Prepare Your Working Directory

Monitoring folder contains the scripts and files required to deploy SAS Event Stream Processing Monitoring for Kubernetes. 

The following is the directory structure of the folder:

```text
Monitoring
├── customizations
│   └── monitoring
│       ├── dashboards
│       │   └── ...
│       ├── grafana
│       │   └── ...
│       ├── loki
│       │   └── ...
│       ├── monitors
│       │   └── ...
│       ├── user.env
│       ├── user-values-prom-operator.yaml
│       ├── user-values-prom-operator-host-based.yaml.sample
│       └── user-values-prom-operator-path-based.yaml.sample
├── viya4-monitoring-kubernetes-x.x.xx
│   └── ...
```

Where:

* The `customizations/monitoring` directory contains Loki and Promtail artifacts, sample Grafana dashboards for SAS
  Event Stream Processing, Kubernetes ingress definitions for the monitoring components, and the `user.env`  file with
  custom deployment settings:
	* `dashboards` contains the sample Grafana dashboards.
    * `grafana` contains artifacts used to configure Grafana authentication and, optionally, deploy and configure the
      SAS Event Stream Processing Data Source Plug-in for Grafana. 
	* `loki` stores the artifacts used to deploy Loki and Promtail.
	* `monitors` contains the service monitor definition for Loki and Promtail.
	* `user.env` provides the configuration for the deployment of the monitoring components. If necessary, review
      and modify the settings before deploying.
	* The `user-values-prom-operator-*-based.yaml.sample` files contain sample settings for host-based or path-based
      access to the monitoring components. Path-based access is used for cloud-based deployments.
      * When deploying, copy the appropriate sample file to the `user-values-prom-operator.yaml` file in the same
        directory and customize it according to your needs.
* `viya4-monitoring-kubernetes-x.x.xx` is the directory created by extracting the binaries for SAS Event Stream 
  Processing Monitoring for Kubernetes. This directory contains configuration files and scripts for both the monitoring
  and logging components of the SAS Viya platform.
  * **NOTE:** The content of this directory should never be modified, and is intended to be used as-is.

### Review the Deployment Configuration

Before proceeding to the deployment step, the deployment configuration must be set to reflect your target environment.

1. Navigate to the `customization/monitoring` directory created by the unpacking of the binaries.
2. Replace or update the content of the `user-values-prom-operator.yaml` file depending on whether you need host-based
   or path-based ingresses for the monitoring components. The latter are normally used for cloud deployments.
3. Review the content of the `user.env` file and customize it as needed. For an in-depth description of the options,
   see [SAS Viya Monitoring for Kubernetes](https://github.com/sassoftware/viya4-monitoring-kubernetes) and comments
   provided in the file itself.
   * It is strongly recommended that you choose a strong password for the default Grafana `admin` user at this stage,
     which can be set using the `GRAFANA_ADMIN_PASSWORD` property. However, the default password can be changed later
     as described in the [Access the Dashboards](#access-the-dashboards) section.
   * The `GRAFANA_AUTHENTICATION` property allows you to choose `LDAP` or `OAUTH` as the authentication method.
   * For `GRAFANA_AUTHENTICATION=OAUTH`, the `GRAFANA_AUTH_PROVIDER` property allows you to choose `viya` (default),
     `uaa`, or - for SAS Event Stream Processing Standalone Installer deployments - `keycloak` as the identity
     provider to be configured for use by Grafana.
   * The `KEYCLOAK_SUBPATH` property allows you to set the path used to access Keycloak (default: `/auth/`).
   * The `ESP_GRAFANA_PLUGIN_VERSION` property allows for a specific version of the SAS Event Stream Processing Data Source Plug-in for
     Grafana to be automatically deployed. For example:
	    ```text
	    # Version of the ESP Grafana plug-in (with OAUTH authentication only).
	    # Check https://github.com/sassoftware/grafana-esp-plugin for updates
	    ESP_GRAFANA_PLUGIN_VERSION=7.44.0
	    ```
     The plug-in works only with `OAUTH` authentication, with
     the property being ignored for any other authentication method. For more information, see
     [SAS Event Stream Processing Data Source Plug-in for Grafana](https://github.com/sassoftware/grafana-esp-plugin).
   * The `LOKI_ENABLED` property must be set to `True` for SAS Event Stream Processing project logs to be monitored.
   * The `LOKI_RETENTION_PERIOD` property enables you to set the period of time logs are persisted in Loki until deletion. By default, the property is set to `24h` (24 hours); setting the property to `0` disables retention.
   * The `LOKI_LOGFMT` property must be set according to the format used by Kubernetes to write logs. As of the writing
     of this document, the format is `cri` for Microsoft Azure, and `docker` for other providers like Amazon Web
     Services (AWS).
   * The `MON_NODE_PLACEMENT_ENABLE` property must be set to `false` for SAS Event Stream Processing Standalone
     Installer deployments.
4. Depending on the method selected in the `GRAFANA_AUTHENTICATION` property there might be additional configuration
   required:
    * For `GRAFANA_AUTHENTICATION=LDAP`, review and customize the content of the files found in the `configmaps` and
      `patches` directories under `customizations/grafana/authentication/LDAP`.
    * For `GRAFANA_AUTHENTICATION=OAUTH`, no work is needed as the configuration files are created automatically.


[&#11014;](#top) Top
## Deploying the Monitoring Components

### Deploy SAS Event Stream Processing Monitoring for Kubernetes

With the contents of the `user-values-prom-operator.yaml` and `user.env` files set, the working directory is ready to
carry out the deployment process. Complete the following steps:

1. Set and export the USER_DIR environment variable to the path of the `customization` directory as shown in
   the following example, where `<target-directory>` should be replaced by the path to the directory that you used in
   the [Prepare Your Working Directory](#prepare-your-working-directory) section:  
	```shell
	export USER_DIR=<target-directory>/Monitoring/customizations
	```
2.  Set an environment variable to the value the ESP namespace:
	```shell
        export VIYA_NS=<esp-namespace>
	```
4.  Navigate to the `<target-directory>/viya4-monitoring-kubernetes-x.x.xx/monitoring/bin` directory, and deploy
   SAS Event Stream Processing Monitoring for Kubernetes using the following command:  
	```shell
	./deploy_monitoring_cluster.sh
	```
 
This results in the deployment of the following components to the target Kubernetes cluster:

| Release Name               | Helm Chart Name                | Application Version |
|----------------------------|--------------------------------|---------------------|
| `loki`                     | `loki-6.24.0`                  | 3.3.2               |
| `promtail`                 | `promtail-6.16.6`              | 3.0.0               |
| `v4m-metrics`              | `v4m-1.2.7-SNAPSHOT`           | 1.2.7-SNAPSHOT      |
| `v4m-prometheus-operator`  | `kube-prometheus-stack-41.7.3` | 0.60.1              |

[&#11014;](#top) Top
### Deploy the SAS Viya Monitoring for Kubernetes Dashboards

With SAS Event Stream Processing Monitoring for Kubernetes in place, you can optionally perform the following steps to
deploy the SAS Viya Monitoring for Kubernetes dashboards.

1. Set and export the VIYA_NS environment variable with the namespace of your deployment of the SAS Viya platform:
    ```shell
    export VIYA_NS=<viya-namespace>
    ```
2. Navigate to the `<target-directory>/viya4-monitoring-kubernetes-x.x.xx/monitoring/bin` directory and deploy
   the dashboards using the following command:
    ```shell
    ./deploy_monitoring_viya.sh
    ```

For more information about the deployment of the monitoring layer of the SAS Viya platform as well as on the optional logging
component for logs originating from applications other than SAS Event Stream Processing, see
[SAS Viya Monitoring for Kubernetes](https://github.com/sassoftware/viya4-monitoring-kubernetes).

[&#11014;](#top) Top
### Deploy Custom Dashboards

The dashboards that are deployed with SAS Event Stream Processing Monitoring for Kubernetes are intended to provide an example
of the kind of monitoring that can be achieved through Grafana. Since the dashboards are provisioned as part of the
deployment, they cannot be modified directly in Grafana. It is therefore recommended to either change their source
code, or to create copies to work on. They can be cloned and modified to create even more sophisticated dashboards to,
for example, target different metrics or trigger alerts. The source code for the sample dashboards can be found in the
`$USER_DIR/monitoring/dashboards` directory.

Whether you decide to modify the existing dashboard or create new ones in the same directory, they can be deployed into
an existing environment using the following steps:

1. Set and export the USER_DIR environment variable if not already set, where `<target-directory>` should again
   be replaced by the path to the directory used when in the
   [Prepare Your Working Directory](#prepare-your-working-directory) section:
    ```shell
    export USER_DIR=<target-directory>/Monitoring/customizations
    ```
2. Navigate to the `<target-directory>/viya4-monitoring-kubernetes-x.x.xx/monitoring/bin` directory and deploy
   your custom dashboards using the following command:
    ```shell
    ./deploy_dashboards.sh
    ```

Alternatively, dashboards can be created or cloned in Grafana, with no deployment needed once the dashboards are ready.
Either way, it is recommended to consult the Grafana documentation for best practices on how to develop dashboards.

[&#11014;](#top) Top
## Using the Monitoring Components

[&#11014;](#top) Top
### Access the Dashboards
 
You can access Grafana by using the link displayed at the bottom of the deployment log. The password for the `admin`
user can either be provided in the `user.env` file in the `$USER_DIR` directory (recommended), or set after deployment
by running the `change_grafana_admin_password.sh` script, located in the
`<target-directory>/viya4-monitoring-kubernetes-x.x.xx/monitoring/bin` directory.

When you log in to Grafana, the dashboards are displayed:

<table align="center"><tr><td align="center" width="9999">
<img src="Images/Viya_Welcome_Dashboard.png" align="center" width="9999">
</td></tr></table>

Selecting the **SAS ESP CPU, Memory, and Logs Usage** dashboard shows something similar to this:

<table align="center"><tr><td align="center" width="9999">
<img src="Images/ESP_CPU_Memory_Logs_Dashboard_1.png" align="center" width="9999">
<img src="Images/ESP_CPU_Memory_Logs_Dashboard_2.png" align="center" width="9999">
</td></tr></table>

In addition to CPU and memory metrics, the dashboard shows log aggregation information, both summarily and at the
individual project level. The cumulative numbers shown in the **Message Totals by Level** panel apply to all projects
active within the chosen time interval, whereas the **Current Projects** panel gives access to log information only for
currently active projects. Selecting log information displays a screen similar to the following:

<table align="center"><tr><td align="center" width="9999">
<img src="Images/Log_Analysis_By_Project.png" align="center" width="9999">
</td></tr></table>

On the **SAS ESP CPU, Memory, and Logs Usage** dashboard, the **Current CPU Usage By Project** panel on the left side of
the screen offers the ability to drill down to the individual pod level to access additional metrics. For example:

<table align="center"><tr><td align="center" width="9999">
<img src="Images/Compute_Resources_Pod.png" align="center" width="9999">
</td></tr></table>

[&#11014;](#top) Top
### Adding Grafana Alert Rules
Custom alert rules can be added to provide the ability to receive notifications when specific behavior happens though different channels, such as Microsoft Teams or custom webhooks. For more information, see [Alert rules](https://grafana.com/docs/grafana/latest/alerting/fundamentals/alert-rules/#:~:text=An%20alert%20rule%20consists%20of,exceed%20to%20create%20an%20alert.) in Grafana documentation.

A list of existing ESP project alert rules can be found in the [esp-project-alert-rules.yaml](https://github.com/sassoftware/iot-kubernetes-monitoring-esp/blob/main/esp-project-alert-rules.yaml) file.

To add alert rules from the provided ESP project alert rules:
1. Navigate to the **Alert rules** section in Grafana:
<table><tr><td>
<img src="Images/Alert_Rules_Main_Menu.png">
</td></tr></table>

2. Click **New Alert Rule**.
3. Using the provided ESP project alert rules, fill in the fields for the alert rule.

Here is an example for implementing the first alert rule, `ESP Project CPU >80% Threshold`. This alert rule will fire when an ESP project is using more than 80% of the requested CPU limit.

<table align="center"><tr><td align="center" width="9999">
<img src="Images/80_CPU_Threshold_1.png" align="center" width="9999">
</td></tr></table>

<table align="center"><tr><td align="center" width="9999">
<img src="Images/80_CPU_Threshold_2.png" align="center" width="9999">
</td></tr></table>

<table align="center"><tr><td align="center" width="9999">
<img src="Images/80_CPU_Threshold_3.png" align="center" width="9999">
</td></tr></table>

<table align="center"><tr><td align="center" width="9999">
<img src="Images/80_CPU_Threshold_4.png" align="center" width="9999">
</td></tr></table>

**Note**: It is important to set the **Folder** and **Evaluation group** field to `esp-project-alert-rules` and to set the **Labels** to `type=esp-project` so these rule alerts are displayed on the **ESP Overview** dashboard when the rule alerts are in a firing state. The alert rule template has been left blank for customizing. For more information, see [Notification templating](https://grafana.com/docs/grafana/latest/alerting/fundamentals/alert-rules/message-templating/) and [Labels and annotations](https://grafana.com/docs/grafana/latest/alerting/fundamentals/annotation-label/).

Contact points can be defined to specify where firing alert rules are routed to:

<table><tr><td>
<img src="Images/Alert_Rules_Contact_Point.png">
</td></tr></table>

Notification policies can be added so that alert rules with a specific label are always routed to a specific contact point.

[&#11014;](#top) Top
## Uninstalling

Uninstalling SAS Event Stream Processing Monitoring for Kubernetes is performed in the same way as for SAS Viya
Monitoring for Kubernetes:

1. Set and export the USER_DIR environment variable if not already set:
    ```shell
    export USER_DIR=<monitoring-root-directory>/Monitoring/customizations
    ```
2. Navigate to the `<target-directory>/viya4-monitoring-kubernetes-x.x.xx/monitoring/bin` directory and use the following
   command to remove the previously-deployed monitoring components:
    ```shell
    ./remove_monitoring_cluster.sh
    ```
   
This removes all Kubernetes resources created during the deployment process from the target cluster.

[&#11014;](#top) Top
## Troubleshooting

For SAS Event Stream Processing Monitoring for Kubernetes to be deployed without errors, the entire list of
prerequisites must be satisfied. Make sure to go through each one of them before attempting to deploy. When the
requirements are in place, in the event that any of the deployment tasks fail, it is recommended to remove the software
before attempting execution again.

To troubleshoot problems with the Kubernetes cluster, it is recommended that you use a tool such as
[Lens](https://k8slens.dev/), or ask someone to help you do the same if you are not familiar with Kubernetes. Finally,
always consult the documentation for SAS Viya Monitoring for Kubernetes before applying any configuration changes that
could lead to deployment errors.

[&#11014;](#top) Top
## Contributing

This project does not accept contributions.

[&#11014;](#top) Top
## License

This project uses the SAS License Agreement for Corrective Code or Additional Functionality.
Please see the license file for additional detail.

[&#11014;](#top) Top
## Additional Resources

* [SAS Help Center: Monitoring Events, Alerts, and Health with Prometheus](https://go.documentation.sas.com/doc/en/espcdc/default/espex/p012m6yncdn4e3n1wq4rroih16y0.htm#p0rwojd7hnzcymn117e1ilapqgqm )
* [SAS Viya Monitoring for Kubernetes](https://github.com/sassoftware/viya4-monitoring-kubernetes)
* [SAS Event Stream Processing Data Source Plug-in for Grafana](https://github.com/sassoftware/grafana-esp-plugin)
* [Prometheus](https://prometheus.io/)
* [Grafana](https://grafana.com/)
* [Grafana Loki](https://grafana.com/oss/loki/#:~:text=Loki%20is%20a%20horizontally%20scalable,labels%20for%20each%20log%20stream.)
