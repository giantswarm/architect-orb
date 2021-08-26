# run-tests-with-ats

**Experimental!!!** Only use this if you know what you're doing!

Use this job to execute managed apps using [app-test-suite](https://github.com/giantswarm/app-test-suite).

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
       - architect/run-tests-with-abs:
          name: execute chart tests
          chart_dir: "./helm/my-beautiful-app"
```

## Parameters

- [common parameters](common.md#parameters) shared in all jobs.
- [chart_dir](#chart_dir)
- [app-test-suite_version](#app-test-suite_version)
- [app-test-suite_container_tag](#app-test-suite_container_tag)
- [additional_app-test-suite_flags](#additional_app-test-suite_flags)

### chart_dir

Directory in which the chart resides. Usually starts with `./helm`

### app-test-suite_version

Version of app-test-suite `dabs.sh` container wrapper to use (git tag or commit).
Use this parameter if you have some changes lined up in `dabs.sh` which is not released yet.
For git tags, the same container tag of app-test-suite will be used.

**Attention:** For git commits or branches, `latest` will be used as container tag.
This can be circumvented by also setting the parameter [`app-test-suite_container_tag`](#app-test-suite_container_tag).

(Default: "v0.1.2")

### app-test-suite_container_tag

Container tag of app-test-suite to use (check [quay.io/giantswarm/app-test-suite](https://quay.io/giantswarm/app-test-suite)).
This parameter allows to specify the used container tag of app-test-suite.

(Default: "0.1.2")

### additional_app-test-suite_flags

Allows to add additional flags to the execution of app-test-suite.
If possible, specify your configuration using the `.abs/main.yaml` configuration file.
