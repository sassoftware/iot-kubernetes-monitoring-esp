The following directories are contained in this folder:

- `customizations`:
  Contains changes to apply to the monitoring stack. For SAS ESP, such
  changes relate to the installation of Loki for log monitoring.
- `viya-monitoring-kubernetes-x.x.xx`:
  Contains the binaries for the SAS Viya4 monitoring stack.

**NOTE:**
Before running any of the scripts to install/remove the monitoring stack,
the USER_DIR variable needs to be set to point to the full path for the
folder where containing the customizations as shown in the example below:

```shell
export USER_DIR=/<full-path-to>/Monitoring/customizations
```
