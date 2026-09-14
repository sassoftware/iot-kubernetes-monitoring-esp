This folder contains two config maps and a kubernetes patch file:

- v4m-grafana-config.yaml
  This is the config map that contains the options needed in the
  Grafana configuration file to support LDAP.
- v4m-grafana-LDAP.yaml
  This is the config map that contains authentication type options. Refer to the Grafana documentation for more info.
- v4m-grafana-patch.yaml
  This is the Kubernetes patch file that updates the Grafana manifest
  based on LDAP.