# User-Provided Dashboards

You can use the `monitoring/dashboards` directory to supply a set of additional Grafana dashboards to deploy with the monitoring components. Template files are additionally provided in the `templates` directory; these templates are processed when the IoT monitoring solution is deployed to produce dashboards that will work with the metrics endpoint Prometheus targets (`/eventStreamProcessing/v2/metrics` by default).

## Community Dashboards

The monitoring deployment includes a set of dashboards, but you can also add your own. Many dashboards are available at [Grafana's site of community dashboards](https://grafana.com/grafana/dashboards). Download the `.json` file for a dashboard and save it using a filename that is
a [valid kubernetes resource name](https://kubernetes.io/docs/concepts/overview/working-with-objects/names).

## Troubleshooting

### Data Sources

Many publicly available dashboards use a generic data source definition, such as `${DS_PROMETHEUS}`. If you use Grafana's import function to import the dashboard, Grafana prompts you for a valid data source.

Because this process provisions the dashboards during deployment rather than manually
importing them, Grafana cannot resolve the data source, so errors will be displayed 
when you view the dashboard. To resolve this issue, perform
a global replace of the generic data source with `Prometheus`. For example:

* Find: `"datasource": "${DS_PROMETHEUS}"`
* Replace: `"datasource": "Prometheus"`

### Size

Dashboards provided here are provisioned as configmaps. Because some extremely detailed
dashboards might be too large, these large dashboards must be manually imported using the Grafana.
