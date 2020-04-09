
# run-kat-tests

This job installs all the required software to run
[kube-app-testing](https://github.com/giantswarm/kube-app-testing).

This includes:

- helm chart validation
- deploying app on a test cluster
- optionally executing functional tests

Parameters:

- `chart` - the name of the chart to test in `/helm` directory
- `cluster_type` - type of the cluster to create for test execution. `kind` is default
  and the only one supported right now.

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
          filters:
            tags:
              only: /^v.*/
```
