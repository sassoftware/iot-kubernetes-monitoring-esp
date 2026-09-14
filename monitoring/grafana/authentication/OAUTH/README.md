This folder contains a config map and a kubernetes patch file:

- v4m-grafana-config.yaml
  This is the config map that contains the options needed in the
  Grafana configuration file to support OAUTH.
- v4m-grafana-patch.yaml
  This is the Kubernetes patch file that updates the Grafana manifest
  based on OAUTH.