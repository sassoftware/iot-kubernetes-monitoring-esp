drwxr-xr-x. 3 root root   24 Apr 18 22:57 customizations
drwxr-xr-x. 2 root root   52 Apr 18 11:04 github
-rw-------. 1 root root  312 Apr 18 10:00 README.md
drwxr-xr-x. 9 root root 4096 Apr 18 11:04 viya4-monitoring-kubernetes-x.x.xx

The following directories are contained in this folder:

- customizations:
  Contains changes to apply to the monitoring stack. For SAS ESP, such
  changes relate to the installation of Loki for log monitoring.

- github
  Stores the original, zipped version of the viya-monitoring-kubernetes
  folder.

- viya-monitoring-kubernetes-x.x.xx
  Contains the binaries for the SAS Viya4 monitoring stack.

NOTE:
Before running any of the scripts to install/remove the monitoring stack,
the USER_DIR variable needs to be set to point to the full path for the
folder where containing the customizations as shown in the example below:

export USER_DIR=/root/Viya_Manager/Optional-Components/Monitoring/customizations
