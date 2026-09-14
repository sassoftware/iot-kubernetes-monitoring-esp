This folder contains two config maps and a kubernetes patch file:

- v4m-grafana-config.yaml
  This is the config map that contains the options needed in the
  Grafana configuration file to support the chosen authntication
  type.
- v4-grafana-<authentication type>.yaml
  This is the config map that contains authentication type options.
  Examples of "<authentication type>" string in the name are LDAP,
  OAUTH, etc. Refer to the Grafana documentation for more info.
- v4-grafana-patch.yaml
  This is the Kubernetes patch file that updates the Grafana manifest
  based on the chosen authentication type.
