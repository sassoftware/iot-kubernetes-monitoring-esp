This folder contains the set of customizations to apply to the SAS Viya
monitoring stack to monitor Event Stream Processing related resources.

The "dashboards" folder contains two sample dashboards for CPU, memory,
and logs monitoring, and a copy of the SAS Viya "welcome" with changes
to include references to the SAS ESP resources.

The "loki" folder contains the manifests needed to install Loki.

The "monitors" folder contains the definition of the service monitor
needed to support SAS ESP monitoring.

The "user.env" file contains settings to handle the installation of ESP
resources as well as Loki.

The "values-prom-operator.yaml" file contains a series of modifications
aimed at reducing the amount of memory used by the monitoring stack. 
This is a necessity on RACE environments, but not necessarily on cloud
deployments. In those cases, the file can either be removed or renamed.

The "user-values-prom-operator-*.yaml" files determine how Prometheus
components are accessed, which is via host-based or path-based syntax.
Host-based is the default, and works for on-prem deployments as it is
the case with RACE. Path-based syntax should be used for the cloud. In
that case, the "user-values-prom-operator-path-based.yaml" file needs
to be renamed to "user-values-prom-operator.yaml" and customized as
needed before deploying the monitoring stack.
