# run-tests-with-abs

**Experimental!!!** Only use this if you know what you're doing!

Use this job to execute managed apps using [app-build-suite](https://github.com/giantswarm/app-build-suite).

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
- [app-build-suite_version](#app-build-suite_version)
- [app-build-suite_container_tag](#app-build-suite_container_tag)
- [additional_app-build-suite_flags](#additional_app-build-suite_flags)

### chart_dir

Directory in which the chart resides. Usually starts with `./helm`

### app-build-suite_version

Version of app-build-suite `dabs.sh` container wrapper to use (git tag or commit).
Use this parameter if you have some changes lined up in `dabs.sh` which is not released yet.
For git tags, the same container tag of app-build-suite will be used.

**Attention:** For git commits or branches, `latest` will be used as container tag.
This can be circumvented by also setting the parameter [`app-build-suite_container_tag`](#app-build-suite_container_tag).

(Default: "v0.2.1")

### app-build-suite_container_tag

Container tag of app-build-suite to use (check [quay.io/giantswarm/app-build-suite](https://quay.io/giantswarm/app-build-suite)).
This parameter allows to specify the used container tag of app-build-suite.

(Default: "v0.2.1")

### additional_app-build-suite_flags

Allows to add additional flags to the execution of app-build-suite.
If possible, specify your configuration using the `.abs/main.yaml` configuration file.
