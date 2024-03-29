# run-tests-with-ats

**Experimental!!!** Only use this if you know what you're doing!

Use this job to execute app tests using [app-test-suite](https://github.com/giantswarm/app-test-suite).

**Attention** This job requires a present CircleCI workspace with a helm chart archive.
This is usually generated by executing job [`push-to-app-catalog`](./push-to-app-catalog.md) with [`persist_chart_archive`](./push-to-app-catalog.md#persist_chart_archive-boolean-defaultfalse) set to `true`.

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-app-catalog:
          name: push-to-catalog
          app_catalog: "default-catalog"
          app_catalog_test: "default-test-catalog"
          chart: "my-beautiful-app"
          persist_chart_archive: true # required for run-tests-with-ats

      - architect/run-tests-with-ats:
          name: execute chart tests
          chart_archive_prefix: "my-beautiful-app" # optional
          requires:
            - push-to-catalog
```

## Parameters

- [common parameters](common.md#parameters) shared in all jobs.
- [chart_archive_prefix](#chart_archive_prefix-optional-string-default)
- [app-test-suite_version](#app-test-suite_version)
- [app-test-suite_container_tag](#app-test-suite_container_tag)
- [additional_app-test-suite_flags](#additional_app-test-suite_flags)

### chart_archive_prefix (optional string, default="")

Used for discovery of the chart archive to test. Default is an empty string which will resolve the first `*.tgz` file.

Actual implementation is:

```
find -name "<< parameters.chart_archive_prefix >>*.tgz" -print -quit
```

### app-test-suite_version

Version of app-test-suite `dats.sh` container wrapper to use (git tag or commit).
Use this parameter if you have some changes lined up in `dats.sh` which is not released yet.
For git tags, the same container tag of app-test-suite will be used.

**Attention:** For git commits or branches, `latest` will be used as container tag.
This can be circumvented by also setting the parameter [`app-test-suite_container_tag`](#app-test-suite_container_tag).

(Default: "v0.2.2")

### app-test-suite_container_tag

Container tag of app-test-suite to use (check gsoci.azurecr.io/giantswarm/app-test-suite).
This parameter allows to specify the used container tag of app-test-suite.

(Default: "0.2.2")

### additional_app-test-suite_flags

Allows to add additional flags to the execution of app-test-suite.
If possible, specify your configuration using the `.ats/main.yaml` configuration file.

A basic `.ats/main.yaml` could look like this:

```yaml
smoke-tests-cluster-type: kind # Create a kind cluster to run tests in

skip-steps: functional, upgrade # Only execute smoke tests
````
