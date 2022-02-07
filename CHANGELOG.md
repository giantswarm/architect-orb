# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.10.1] - 2022-02-07


### Changed

- Update architect to [6.0.0](https://github.com/giantswarm/architect/blob/master/CHANGELOG.md#600---2022-02-07). Includes generators for Flux-friendly app collections.

## [4.10.0] - 2022-02-07

### Changed

- Change `push-to-app-collection` command: generate resources for Flux to manage app collections

## [4.9.0] - 2021-12-15

### Changed

- Change `integration-test` job to always install `apptestctl` binary.
- Add `helm-version` parameter to `integration-test` job.

## [4.8.1] - 2021-11-17

- Update `app-test-suite` to [0.2.2](https://github.com/giantswarm/app-test-suite/blob/master/CHANGELOG.md#022---2021-11-17). Includes 2 important bugfixes for working with ginatswarm catalog.

## [4.8.0] - 2021-11-03

### Changed

- Update `app-test-suite` to [0.2.1](https://github.com/giantswarm/app-test-suite/blob/master/CHANGELOG.md#021---2021-10-28). Main changes are
  - New test type - upgrade test
  - New test executor - go test
  - Update python to 3.9

## [4.7.0] - 2021-11-02

### Added

- Add `tags` parameter to `go-build` job to allow specifying `-tags` flag when running `go build`.

### Changed

- Change download URL of `dats.sh` wrapper to use raw.githubusercontent.com to be able to run pre-release versions of app-test-suite in `run-tests-with-ats` job.

### Removed

- Remove unused `pkg` parameter in `go-build` command.

## [4.6.0] - 2021-10-04

### Changed

- Change `kubeval` k8s schema to more up-to-date source.
- Specify machine `image` to use (`ubuntu-2004:202010-01`) for all jobs that use the `machine` executor.

## [4.5.0] - 2021-09-29

### Added

- Add `kubeval` validation step for duplicate chart resources in `push-to-app-catalog` job.

## [4.4.0] - 2021-09-24

### Changed

- Use version [1.0.4](https://github.com/giantswarm/app-build-suite/blob/master/CHANGELOG.md#104---2021-09-21) of app-build-suite for `app-build-suite` executor.
- Replace `run-tests-with-abs` with `run-tests-with-ats`. Use new [`app-test-suite`](https://github.com/giantswarm/app-test-suite).
- Add `persist_chart_archive` parameter to `push-to-app-catalog` job to be used together with `run-tests-with-abs` job.

## [4.3.0] - 2021-09-13

- Update `architect` version to [`v5.2.0`](https://github.com/giantswarm/architect/releases/tag/v5.2.0).
  - Updates Go version to 1.17.1
  - Updated `golangci-lint` to v1.42.1
- Update Go version used in `machine-install` command to 1.17.1.

## [4.2.0] - 2021-08-25

### Changed

- Update `architect` version to `v5.1.0`.

## [4.1.0] - 2021-08-20

### Changed

- Update [deprek8ion](https://github.com/swade1987/deprek8ion) policies to include checking for deprecated manifests of kubernetes releases 1.16, 1.17, 1.18, 1.19 and 1.20

### Removed

- Remove pushing Argo Application CRs into `helm/` chart path.

## [4.0.0] - 2021-07-12

### Changed

- Update architect to [4.0.0](https://github.com/giantswarm/architect/releases/tag/v4.0.0).

## [3.3.0] - 2021-06-16

### Changed

- Update architect to [3.7.1](https://github.com/giantswarm/architect/releases/tag/v3.7.1).
- Add a friendly name to the lint helm chart step.

## [3.2.0] - 2021-06-15

### Changed

- Update apptestctl version in integration-test job to 0.9.0.

### Removed

- Remove `skip_helm_chart_linting` option introduced in [#256](https://github.com/giantswarm/architect-orb/pull/256).

## [3.1.0] - 2021-05-26

### Changed

- Use version 0.2.3 of app-build-suite for `app-build-suite` executor.

## [3.0.0] - 2021-05-21

### Changed

- :warning: Push Argo Application CRs instead of Giant Swarm App CRs to collections'
  /helm directory. This is a breaking change.

### Removed

- :warning: Remove all `user_configmap*` and `user_secret*` parameters from `push-to-app-collection` job. This is a breaking change.

## [2.11.0] - 2021-05-20

### Added

- Add `selfHeal: true` and `allowEmpty: true` to the generated Application CR sync policy in `push-to-app-collectoin` job (See [architect@v3.6.0]).

### Fixed

- Temporarily don't fail when Chart.yaml doesn't have the config annotation in `push-to-app-collectoin` job (See [architect@v3.6.0]).

[architect@v3.6.0]: https://github.com/giantswarm/architect/blob/master/CHANGELOG.md#360---2021-05-20

## [2.10.0] - 2021-05-19

### Changed

- Update Kubernetes version in integration-test job to 1.21.1.
- Update KinD version in integration-test job to 0.11.0.
- Update Helm version in integration-test job to 3.5.4.

## [2.9.0] - 2021-05-18

### Added

- Create Argo CD Application CR alongside Giant Swarm App CR  in `push-to-app-collection` job. They are pushed to separate _/manifests_ directory.

## [2.8.0] - 2021-05-13

### Fixed

- Remove `.status` field from App CR before pushing into app-collection.

## [2.7.0] - 2021-04-08

### Fixed

- Regenerate ssh public key in `push-to-app-catalog` and `push-to-app-collection` to match given private catalogbot ssh key.

## [2.6.0] - 2021-04-07

### Changed

- Update apptestctl version in integration-test job to 0.8.0.
- Update Kubernetes version in integration-test job to 1.20.2.

## [2.5.0] - 2021-03-30

### Changed

- Allow skipping helm chart linting during `push-to-app-catalog` by setting `skip_helm_chart_linting`.

## [2.4.2] - 2021-03-24

### Fixed

- Fix git clone for push to app collection using master as a main branch

## [2.4.1] - 2021-03-24

### Changed

- Upgrade architect to [3.4.1](https://github.com/giantswarm/architect/releases/tag/v3.4.1) which contains the extended chart schema of app-build-suite.

## [2.4.0] - 2021-03-23

### Changed

- Support both main and master branch in push-to-app-collection.
- Update Kubernetes version in integration-test job to 1.19.4.
- Update Kind version in integration-test job to 0.10.0.
- Bump apptestctl in integration-test job to 0.7.0.
- Update Go version used in `machine-install` command to 1.16.2.
- Bump architect to [3.4.0](https://github.com/giantswarm/architect/releases/tag/v3.4.0).
  - Update `go` version to `v1.16.2`.
  - Update `helm` version to `v3.5.3`.
  - Update `alpine` version to `3.13`.
  - Update `conftest` version to `v0.21.0`.
  - Update `golangci-lint` version to `v1.38.0`.
  - Update `nancy` version to `v1.0.17`.
  - Update `helm-chart-testing` to `v3.3.1`.
- Use version 0.2.2 of app-build-suite for `app-build-suite` executor.

## [2.3.0] - 2021-03-12

### Changed

- Update Go version used in `machine-install` command to 1.16.1.
- Bump architect to 3.3.1.

## [2.2.0] - 2021-03-02

### Added

- Use version 0.2.1 of app-build-suite for `app-build-suite` executor.

### Changed

- Allow chart name mismatch for `push-to-app-catalog` by setting `explicit_allow_chart_name_mismatch` to `true`.

## [2.1.0] - 2021-02-24

### Changed

- Change app catalog base domain to `giantswarm.github.io` because of upstream redirect deprecation.

## [2.0.0] - 2021-02-19

### Changed

- Update Go version used in integration tests to 1.16.
- Bump architect to 3.3.0.

### Removed

- **Breaking**: Remove `legacy` jobs and commands

## [1.1.2] - 2021-02-04

### Added

- Use version 0.1.7 of app-build-suite for `app-build-suite` executor.
- Added experimental `run-tests-with-abs` job for test execution using app-build-suite.

## [1.1.1] - 2021-01-07

### Added

- Use apptestctl v0.6.0 in `integration-test` job.
- Bump helm version in `run-kat-tests` job.
- Use version 0.1.3 of app-build-suite for `app-build-suite` executor.

## [1.1.0] - 2020-12-22

### Changed

- Allow `chart` parameter value of job `push-to-app-catalog` to be
"name of repository with optional -app suffix".

## [1.0.0] - 2020-12-04

### Added

- Set configuration version in the generated App CR in `push-to-app-collection`
  if "config.giantswarm.io/version" annotation is set in Chart.yaml.

### Removed

- Removed `unique` parameter from `push-to-app-collection` job. This is
  a breaking change.

## [0.18.1] - 2020-11-30

### Added

- Use apptestctl v0.5.1 in `integration-test` job to add printer columns for
app and chart CRDs.

### Fixed

- Fix setting kubeconfig when running `apptestctl bootstrap`.

## [0.18.0] - 2020-11-27

### Added

- Use apptestctl v0.5.0 in `integration-test` job.
- Allow app user config configmap and secret configuration.

### Changed

- Bump architect to 3.1.1

## [0.17.1] - 2020-11-24

### Added

- Add `build-context`, `dockerfile` and `tag-suffix` parameters to `push-to-docker`.
- Added names to steps in `push-to-docker` command.
- Added `app-build-suite` executor.
- Add `executor` parameter to `push-to-catalog` job to enable building charts using [app-build-suite](https://github.com/giantswarm/app-build-suite) for metadata generation in `push-to-app-catalog` job.

## [0.17.0] - 2020-11-06

### Added

- Add `install-app-platform` param to integration-test job that runs
`apptestctl bootstrap` to add support for using app CRs in tests.
- Update kubernetes in integration-test job to v1.17.11.
- Update kind in integration-test job to v0.9.0.
- Update helm CLI in integration-test job to v3.4.0.

### Fixed

- Remove copying code to GOPATH in integration-test job since migration to
Go modules is complete.

## [0.16.0] - 2020-10-27

### Added

- Add `resource_class` parameter to `run-kat-tests` job.

## [0.15.1] - 2020-10-26

### Changed

- Set defaults for 'helm-version' (2.16.5), 'kind-version' (0.7.0) and 'kubectl-version' (1.18.0) in 'run-kat-tests' job.

## [0.15.0] - 2020-10-26

### Added

- Add multiple parameters to `run-kat-tests` job.

## [0.14.0] - 2020-10-14

### Added

- Update `architect` binary version to v3.0.2.
- Add guideline to use name on steps.

### Changed

- Make 'package-and-push' more readable.

## [0.13.0] - 2020-10-05

### Changed

- Update Go version used in integration tests to 1.15.2.

## [0.12.0] - 2020-09-28

### Added

- Update `architect` binary version to v3.0.0.

## [0.11.0] - 2020-08-20

### Added

- Scan for Go dependency vulnerabilities with `nancy`.

## [0.10.2] - 2020-08-11

### Added

- Update `architect` binary version to v2.1.3.

## [0.10.1] - 2020-07-24

### Changed

- Install `kind` as a binary file.

## [0.10.0] - 2020-07-03

### Changed

- Delete `helm init` step which was not needed after helm 3.
- Pin `architect` binary version to v2.0.0.

## [0.9.0] - 2020-06-02

### Changed

- Recreate broken [0.8.18] release and discontinue 0.8.x line to avoid confusion. For details see:
  - https://github.com/giantswarm/giantswarm/issues/10423#issuecomment-637398805

## [0.8.18] - 2020-05-25

### Added

- `integration-test-create-cluster`: retry creating kind cluster.

### Fixed

- `push-to-app-catalog`: fix retries.
- `push-to-app-collection`: fix retries.

## [0.8.17] - 2020-05-21

### Fixed

- `integration-test-install-tools`: install Helm 2.16.1 since it's required by our Helm client.

## [0.8.16] - 2020-05-21

### Added

- `integration-test-install-tools`: install Helm 2.16.7.

## [0.8.15] - 2020-05-14

### Fixed

- `push-to-app-catalog`: retry the push up to 4 times to better handle transient errors.

### Added

- `push-to-app-catalog` and `run-kat-tests`: Support providing Chart Testing (`ct`) configuration file

## [0.8.14] - 2020-05-11

### Fixed

- `push-to-app-collection`: retry the push up to 4 times to better handle transient errors.

## [0.8.13] - 2020-04-24

### Changed

- `go-build` job will fail if it fails to compile.

### Fixed

- The `go-test` job takes into consideration go modules when generating flags to inject values into the binary.

## [0.8.12] - 2020-04-22

### Added

- Add new parameter `disable_force_upgrade` to `push-to-app-collection` job which allows
  configuring App CR annotation `chart-operator.giantswarm.io/force-helm-upgrade`.
  This annotation defines whether `chart-operator` forces helm chart upgrade on failure.


## [0.8.11] - 2020-04-21

### Changed

- `conftest` is used to check deprecation policies only up to Kubernetes 1.17.

## [0.8.10] - 2020-04-20

### Changed

- `push-to-app-catalog` will lint the helm charts again.

## [0.8.9] - 2020-04-14

### Added

- Added a new job `run-kat-tests` that executes application tests using
  [kube-app-testing](https://github.com/giantswarm/kube-app-testing)

### Changed

- `push-to-app-catalog` doesn't lint helm charts anymore, as that is now part
  of tests run by `kube-app-testing`


## [0.8.8] - 2020-04-09

### Added

- Add `resource_class` parameter to all jobs (excluding legacy jobs).

### Changed

- Update Go version used in integration tests to 1.14.1.


## [0.8.7] - 2020-04-08

### Added

- Add new parameter `namespace` to `push-to-app-collection` job which allows
  configuring namespace where chart should be installed.



## [0.8.6] - 2020-03-30

### Added

- Use `conftest` to validate helm template using `rego` policies in `push-to-app-catalog` job.



## [0.8.5] - 2020-03-30

### Changed

- Validate templated charts using `architect helm template` in
  `push-to-app-catalog` job.



## [0.8.4] - 2020-03-24

### Added

- New parameter `test-timeout` for the `integration-test-go-test` command and
  `integration-test` job which allows to define the timeout for the test execution.
  It defaults to the value that was already in use.

### Changed

- Don't run cleanup for helm chart template command on non-tagged builds.
- Drop `unparam` from `golangci-lint`.



## [0.8.3] - 2020-03-12

### Added

- New parameter `on_tag` for the `package-and-push` command and
  `push-to-app-catalog` job which allows merges to the `master` branch
  to be deployed to the non-testing app catalog without requiring a tag.

### Changed

- Don't run cleanup for helm chart template command on non-tagged builds.



## [0.8.2] - 2020-03-10

### Changed

- Fix GOPATH problem in `integration-test` job.
- Disable version bump check for Helm lint.
- Helm lint supports single chart rather than entire directory disabling version bump check.



## [0.8.1] - 2020-03-09

### Added

- Enable linting during go-test command.



## [0.8.0] - 2020-03-05

### Added

- Support for optionally attaching the persisted workspace in the `push-to-app-catalog` job.
- Introduce Helm Chart testing and linting in `push-to-app-catalog` job.
- Add `changelog-lint` job.
- Introduce `integration-test` job for running `Go` integration tests in a `KIND`
  cluster.
- Verify chart, operator and tag versions while packing helm chart on tagged
  operator build in `push-to-app-collection` job.

### Changed

- Update CircleCI config to use `orb-tools@8.27.6`.

### Removed

- Remove Docker layer caching from remote docker setup (affects push-to-docker and push-to-docker-legacy)



## [0.7.0] - 2020-02-26

### Added

- Introduce `go-lint` for running configurable linting jobs on `Go` code
- Introduce `gitleaks` for entropy-based checks for secrets in the repository (language-agnostic)
- Support for modern code analysis tools for dep-based projects using the new
`go-test-legacy` job. Based on the existing `go-test` job.
- Support for running arbitrary architect commands inside an architect container
avoiding the requirement of installing the binary locally using the new
`go-architect-legacy` job.
- New `go-cache-save-legacy` and `go-cache-restore-legacy` commands
which enable `dep` dependencies to be cached in jobs as long as `Gopkg.lock` doesn't change.
- Names for steps in `tools-info` command.



## [0.6.0] - 2020-02-19

### Changed

- Stop injecting version into build info in `go-test` command to allow version to be maintained directly in source.

### Fixed

- Fix pushing new unique app in push-to-app-collection job. https://github.com/giantswarm/architect-orb/pull/69



## [0.5.3] - 2020-02-11

### Added

- Fail when .go files not satisfying import rules specified in fmt are present.

### Fixed

- Fix working files cleanup in push-to-app-collection job.



## [0.5.2] - 2020-02-03

### Fixed

- Do not change CR name when "unique" parameter is set in push-to-app-collection job.



## [0.5.1] - 2020-02-03

### Fixed

- Fix push-to-app-collection job broken in v0.5.0 release.



## [0.5.0] - 2020-01-31

### Added

- Add "unique" parameter to push-to-app-collection job.



## [0.4.5] - 2019-12-11

### Added

- Add "push-to-docker-legacy" command to be able push old style docker image tags.



## [0.4.4] - 2019-10-31

### Added

- Add "tag-latest-branch" parameter to the push-to-docker job.



## [0.4.3] - 2019-10-10

### Added

- Add go-test job for building libraries.



## [0.4.2] - 2019-10-04

### Added

- Add "os" parameter to the go-build job.



## [0.4.1] - 2019-10-02

### Added

- Add message to known errors link if pushing to catalog or collection fails.

### Changed

- Fail when go modules are not tidy in go-build.



## [0.4.0] - 2019-09-17

### Added

- Add go-build job.



## [0.3.0] - 2019-09-06

### Added

- Add push-to-app-collection job.



## [0.2.0] - 2019-07-26

### Added

- Add push-to-docker job.



## [0.1.2] - 2019-07-22

### Fixed

- Index new package only in package-and-push command.



## [0.1.1] - 2019-06-14

### Fixed

- Fix app catalog name reference in indexing step of package-and-push command.



## [0.1.0] - 2019-06-04

### Added

- Add push-to-app-catalog job.



[Unreleased]: https://github.com/giantswarm/architect-orb/compare/v4.10.1...HEAD
[4.10.1]: https://github.com/giantswarm/architect-orb/compare/v4.10.0...v4.10.1
[4.10.0]: https://github.com/giantswarm/architect-orb/compare/v4.9.0...v4.10.0
[4.9.0]: https://github.com/giantswarm/architect-orb/compare/v4.8.1...v4.9.0
[4.8.1]: https://github.com/giantswarm/architect-orb/compare/v4.8.0...v4.8.1
[4.8.0]: https://github.com/giantswarm/architect-orb/compare/v4.7.0...v4.8.0
[4.7.0]: https://github.com/giantswarm/architect-orb/compare/v4.6.0...v4.7.0
[4.6.0]: https://github.com/giantswarm/architect-orb/compare/v4.5.0...v4.6.0
[4.5.0]: https://github.com/giantswarm/architect-orb/compare/v4.4.0...v4.5.0
[4.4.0]: https://github.com/giantswarm/architect-orb/compare/v4.3.0...v4.4.0
[4.3.0]: https://github.com/giantswarm/architect-orb/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/giantswarm/architect-orb/compare/v4.1.0...v4.2.0
[4.1.0]: https://github.com/giantswarm/architect-orb/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/giantswarm/architect-orb/compare/v3.3.0...v4.0.0
[3.3.0]: https://github.com/giantswarm/architect-orb/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/giantswarm/architect-orb/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/giantswarm/architect-orb/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/giantswarm/architect-orb/compare/v2.11.0...v3.0.0
[2.11.0]: https://github.com/giantswarm/architect-orb/compare/v2.10.0...v2.11.0
[2.10.0]: https://github.com/giantswarm/architect-orb/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/giantswarm/architect-orb/compare/v2.8.0...v2.9.0
[2.8.0]: https://github.com/giantswarm/architect-orb/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/giantswarm/architect-orb/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/giantswarm/architect-orb/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/giantswarm/architect-orb/compare/v2.4.2...v2.5.0
[2.4.2]: https://github.com/giantswarm/architect-orb/compare/v2.4.1...v2.4.2
[2.4.1]: https://github.com/giantswarm/architect-orb/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/giantswarm/architect-orb/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/giantswarm/architect-orb/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/giantswarm/architect-orb/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/giantswarm/architect-orb/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/giantswarm/architect-orb/compare/v1.1.2...v2.0.0
[1.1.2]: https://github.com/giantswarm/architect-orb/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/giantswarm/architect-orb/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/giantswarm/architect-orb/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/giantswarm/architect-orb/compare/v0.18.1...v1.0.0
[0.18.1]: https://github.com/giantswarm/architect-orb/compare/v0.18.0...v0.18.1
[v0.18.0]: https://github.com/giantswarm/architect-orb/compare/v0.17.1...v0.18.0
[0.17.1]: https://github.com/giantswarm/architect-orb/compare/v0.17.0...v0.17.1
[0.17.0]: https://github.com/giantswarm/architect-orb/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/giantswarm/architect-orb/compare/v0.15.1...v0.16.0
[0.15.1]: https://github.com/giantswarm/architect-orb/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/giantswarm/architect-orb/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/giantswarm/architect-orb/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/giantswarm/architect-orb/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/giantswarm/architect-orb/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/giantswarm/architect-orb/compare/v0.10.2...v0.11.0
[0.10.2]: https://github.com/giantswarm/architect-orb/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/giantswarm/architect-orb/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/giantswarm/architect-orb/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/giantswarm/architect-orb/compare/v0.8.18...v0.9.0
[0.8.18]: https://github.com/giantswarm/architect-orb/compare/v0.8.17...v0.8.18
[0.8.17]: https://github.com/giantswarm/architect-orb/compare/v0.8.16...v0.8.17
[0.8.16]: https://github.com/giantswarm/architect-orb/compare/v0.8.15...v0.8.16
[0.8.15]: https://github.com/giantswarm/architect-orb/compare/v0.8.14...v0.8.15
[0.8.14]: https://github.com/giantswarm/architect-orb/compare/v0.8.13...v0.8.14
[0.8.13]: https://github.com/giantswarm/architect-orb/compare/v0.8.12...v0.8.13
[0.8.12]: https://github.com/giantswarm/architect-orb/compare/v0.8.11...v0.8.12
[0.8.11]: https://github.com/giantswarm/architect-orb/compare/v0.8.10...v0.8.11
[0.8.10]: https://github.com/giantswarm/architect-orb/compare/v0.8.9...v0.8.10
[0.8.9]: https://github.com/giantswarm/architect-orb/compare/v0.8.8...v0.8.9
[0.8.8]: https://github.com/giantswarm/architect-orb/compare/v0.8.7...v0.8.8
[0.8.7]: https://github.com/giantswarm/architect-orb/compare/v0.8.6...v0.8.7
[0.8.6]: https://github.com/giantswarm/architect-orb/compare/v0.8.5...v0.8.6
[0.8.5]: https://github.com/giantswarm/architect-orb/compare/v0.8.4...v0.8.5
[0.8.4]: https://github.com/giantswarm/architect-orb/compare/v0.8.3...v0.8.4
[0.8.3]: https://github.com/giantswarm/architect-orb/compare/v0.8.2...v0.8.3
[0.8.2]: https://github.com/giantswarm/architect-orb/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/giantswarm/architect-orb/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/giantswarm/architect-orb/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/giantswarm/architect-orb/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/giantswarm/architect-orb/compare/v0.5.3...v0.6.0
[0.5.3]: https://github.com/giantswarm/architect-orb/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/giantswarm/architect-orb/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/giantswarm/architect-orb/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/giantswarm/architect-orb/compare/v0.4.5...v0.5.0
[0.4.5]: https://github.com/giantswarm/architect-orb/compare/v0.4.4...v0.4.5
[0.4.4]: https://github.com/giantswarm/architect-orb/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/giantswarm/architect-orb/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/giantswarm/architect-orb/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/giantswarm/architect-orb/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/giantswarm/architect-orb/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/giantswarm/architect-orb/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/giantswarm/architect-orb/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/giantswarm/architect-orb/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/giantswarm/architect-orb/compare/v0.1.0...v0.1.1

[0.1.0]: https://github.com/giantswarm/architect-orb/releases/tag/v0.1.0
