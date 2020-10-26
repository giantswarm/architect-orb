# run-kat-tests

This job installs all the required software to run
[kube-app-testing](https://github.com/giantswarm/kube-app-testing).

Almost all actions are done by the `kube-app-testing` script, which can be used
for running test locally during development as well. This script is responsible
for creating the test clusters, setting them up, running tests and tearing
clusters down.

The orb here is responsible mainly for installing dependencies required for the
script to run.

This includes:

- helm chart validation
- deploying app on a test cluster
- optionally executing functional tests

Parameters:

- `chart` - the name of the chart to test in `/helm` directory
- `cluster_type` - type of the cluster to create for test execution. `kind` is default.
- `ct_config` - Path to configuration file for Chart Testing (`ct`). This is
  required, if the app relies on external dependencies. You would use this
  config file [to add additional Helm repositories](https://github.com/helm/chart-testing/tree/v2.4.1#using-private-chart-repositories).
  Otherwise this parameter is optional.
- `kind-version` - Version of `kind` used.
- `helm-version` - Version of `helm` used.
- `kube-app-testing-version` - Version of [`kube-app-testing](https://github.com/giantswarm/kube-app-testing) to use.
- `additional_kube-app-testing_flags` - Additional flags supplied to the `kube-app-testing.sh` script.

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/run-kat-tests:
          name: "test the chart with kat"
          chart: "[CHART_NAME]"
          ct_config: ".circleci/ct-config.yaml"
          filters:
            tags:
              only: /^v.*/
```
