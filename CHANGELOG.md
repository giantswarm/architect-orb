# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Bump `app-test-suite_version` default to v0.8.0.
- Updated Kubernetes versions in kubeconform command.
- Bump `app-build-suite` to v1.3.0.

## [5.8.0] - 2024-09-03

### Changed

- Bump `app-test-suite_version` default to v0.7.0

## [5.7.0] - 2024-08-29

### Added

- Add `path` parameter to `go-build` and `go-test` jobs to allow for different Go package path.

## [5.6.0] - 2024-08-26

### Changed

- Bump architect to v6.18.0, which uses Go v1.23.0

## [5.5.2] - 2024-08-26

### Removed

- In command `go-test`...
  - remove the step that executes `go vet`, as the same checks are also run by `golangci-lint`
  - move the `go test` step up to get executed before `golangci-lint`, for reduced runtime.
  - Add cache for `golangci-lint`

### Changed

- In command `go-test`, the `golangci-lint` call is no longer limited to a certain number of issues per linter (max-issues-per-linter is now 0).
- In command `go-test`, use the `environment` key for setting environment variables.

## [5.5.1] - 2024-08-22

### Fixed

- Set `GOGC` when running golangci-lint to help avoid using up all available memory in CircleCI

## [5.5.0] - 2024-08-20

### Changed

- Bump `architect` to v6.17.0.

## [5.4.0] - 2024-08-01

### Changed

- Bump `architect` to v6.16.0.

### Added

- Add `git-tag-prefix` parameter to `push-to-registries` job.

## [5.3.1] - 2024-07-26

### Changed

- Bump `architect` to v6.15.1.

## [5.3.0] - 2024-07-18

### Changed

- Bump `architect` to v6.15.0.

## [5.2.1] - 2024-06-06

### Changed

- Update `app-test-suite` to v0.6.1.

## [5.2.0] - 2024-05-15

### Changed

- Update `app-test-suite` to v0.6.0.

## [5.1.2] - 2024-05-08

### Changed

- Update `app-test-suite` to v0.5.1.

## [5.1.1] - 2024-03-06

### Changed

- Make `image-prepare-tag` command fail when `architect project version` command fails (because CircleCI runs the scripts with `-o pipefail`)

## [5.1.0] - 2024-02-23

### Changed

- Update machine executor image to `default`.

## [5.0.1] - 2024-02-05

## [5.0.1] - 2024-02-05

- fix: `push-to-registries` correctly handles the `force-public` flag

### Changed

- Update CircleCI orb-tools to v12

## [5.0.0] - 2024-01-16

### Removed

- Removed `push-to-docker` job. Please migrate to [`push-to-registries`](https://github.com/giantswarm/architect-orb/blob/main/docs/job/push-to-registries.md).

## [4.38.0] - 2024-01-10

### Changed

- Update `app-build-suite` version to [`v1.2.2`](https://github.com/giantswarm/app-build-suite/releases/tag/v1.2.2).
- Switch images to be pulled from `gsoci.azurecr.io` instead of `quay.io`

## [4.37.0] - 2023-12-20

- `push-to-registries` job changes:
  - remove deprecated `push-to-*` config options
  - login to registries before an image is built, so it's possible to use private base images

## [4.36.0] - 2023-12-19

- `push-to-registries` job changes:
  - Add retries to all remote commands
  - Add a check for a visibility of the source code in the job that pushes images to registry. If repo is private, an image should only be pushed to registries that are configured as private ones.
  - Add repos configuration that is parsed from an environment variable. This allows to configure the job to push to different registries based on the configuration only.

## [4.35.6] - 2023-12-05

### Changed

- Update `push-to-app-collection` command to check if the released version is greater than the one stored in the app collection repository. If so, the update is pushed. Skipped otherwise (for lesser or equal).
- Let golangci-lint report more than 3 items of the same type of complaint

## [4.35.5] - 2023-11-28

In the 'push-to-registries' job, pushing to `docker.io` is now the default as well.

## [4.35.4] - 2023-11-28

- Improvements to the `push-to-registries` job.

## [4.35.3] - 2023-11-24

### Fixed

- Made the `image-build-with-docker` command work in a situation where the `docker build` command would output the image SHA more than once.

## [4.35.2] - 2023-11-24

- More improvements to the [`push-to-registries`](./docs/job/push-to-registries.md) job:
  - It is possible now to configure which target registry should receive images for dev builds. This defaults to gsoci (new ACR) and quay.io only. Check the docs for details.
  - The `image` parameter is now optional. The default is to create the name from the GitHub organization and repository name.

## [4.35.1] - 2023-11-22

### Changed

- UX improvements on `push-to-registries` job.

## [4.35.0] - 2023-11-21

Introduce a new [`push-to-registries`](./docs/job/push-to-registries.md) job that pushes charts to multiple registries at once.

## [4.34.1] - 2023-11-10

### Fixed

- Fix Go checksum for `machine-install-go` command

## [4.34.0] - 2023-11-08

### Changed

- Update `architect` version to [`v6.13.0`](https://github.com/giantswarm/architect/releases/tag/v6.13.0) (includes Go v1.21.3)

## [4.33.1] - 2023-10-31

### Fixed

- Prevent false positives in nancy's vulnerability reports by using `go list` with `-deps ./...`

## [4.33.0] - 2023-10-10

### Changed

- Update `app-test-suite` to v0.5.0.

## [4.32.0] - 2023-10-10

### Changed

- Update `app-test-suite` to v0.4.1.
- Update `apptestctl` to v0.18.0, which installs VerticalPodAutoscaler and PolicyException CRDs to test clusters.

## [4.31.0] - 2023-08-02

### Changed

- Update `apptestctl` to v0.17.0, which installs ServiceMonitor and PodMonitor CRDs to test clusters and makes it compatible with Kubernetes 1.25 and above.

## [4.30.1] - 2023-07-20

### Changed

- Bump architect image to v6.12.1 which includes latest golangci-lint

## [4.30.0] - 2023-07-20

### Changed

- Bump architect image to v6.12.0 which includes bump of Go to v1.20

## [4.29.0] - 2023-04-28

### Changed

- Update `apptestctl` to v0.15.0, which installs Cilium Network Policy and Cluster-wide Policy CRDs by default.

## [4.28.1] - 2023-03-09

### Added

- Add `pre_test_target` parameter to `go-build` and `go-test` jobs. This allows a Makefile target to be executed when specified and is helpful for generating code before any linters run.

## [4.28.0] - 2023-02-21

### Added

- Fix `go test` `nancy` external service error ignore logic
- Add `explicit_allow_chart_name_mismatch` to `push-to-app-catalog` with `app-build-suite` executor.
- Add `test_target` parameter to `go-test` command. This allows a Makefile target to be executed when specified.
- Remove deprecated `kubeval` command in favor of `kubeconform`. Add more recent k8s version checks and validation against our giantswarm/json-schema repo

### Changed

- Update `architect` version to [`v6.10.0`](https://github.com/giantswarm/architect/releases/tag/v6.10.0).
- Update Go version used in `machine-install` command to 1.19.6.

## [4.26.0] - 2022-11-21

- Update `architect` version to [`v6.8.0`](https://github.com/giantswarm/architect/releases/tag/v6.8.0).
- Update `app-build-suite` version to [`v1.1.3`](https://github.com/giantswarm/app-build-suite/releases/tag/v1.1.3).

## [4.25.3] - 2022-10-26

### Changed

- Don't fail `go test` if the `nancy` back end is down.

## [4.25.2] - 2022-10-26

### Changed

- Increase timeout for `golangci-lint` to 10 minutes.

## [4.25.1] - 2022-10-20

### Added

- Add step names where missing.

## [4.25.0] - 2022-10-05

### Changed

- Update `architect` version to [`v6.7.0`](https://github.com/giantswarm/architect/releases/tag/v6.7.0).
- Update Go version used in `machine-install` command to 1.19.1.

## [4.24.0] - 2022-07-12

### Changed

- Update `architect` version to [`v6.6.0`](https://github.com/giantswarm/architect/releases/tag/v6.6.0).
  - Update `nancy` to `v1.0.37`.
- Use an additional nancy exclude vulnerabilities file at the root of the repositories: `.nancy-ignore.generated`. If the file does not exist, nancy will ignore it. The standard `.nancy-ignore` file should contain the repository specific excludes and `.nancy-ignore.generated` is a generated one that should contain globally ignored vulnerabilities, if any.

## [4.23.0] - 2022-06-22

### Changed

- Remove old k8s versions from `kubeval` job.

## [4.22.0] - 2022-06-21

### Changed

- Set `push_to_oci_registry` to `true` by default, pushing all charts to OCI as a result.

## [4.21.1] - 2022-06-16

### Changed

- Update `app-test-suite` to v0.2.4

## [4.21.0] - 2022-05-31

### Changed

- Remove `.nancy-ignore.local` file.

## [4.20.0] - 2022-05-27

### Added

- Add a second `.nancy-ignore.local` file.

## [4.19.0] - 2022-05-24

### Changed

- Update `app-test-suite` to v0.2.3

## [4.18.0] - 2022-05-10

### Changed

- Update `architect` version to [`v6.4.0`](https://github.com/giantswarm/architect/releases/tag/v6.4.0).
  - Updates Go version to 1.18.1.
- Update Go version used in `machine-install` command to 1.18.1.

## [4.17.0] - 2022-04-21

### Added

- Add support for pushing to OCI-based App catalogs.

## [4.16.0] - 2022-04-13

### Changed

- Update [deprek8ion](https://github.com/swade1987/deprek8ion) policies to include checking for deprecated manifests of kubernetes releases 1.22
- Change `kubeval` k8s schema to more up-to-date source. (1.21 and 1.22)

## [4.15.0] - 2022-03-29

### Changed

- Update `app-build-suite` to v1.1.2

## [4.14.4] - 2022-03-24

### Changed

- Update `app-build-suite` to v1.1.1

## [4.14.3] - 2022-03-11

### Changed

- Let `docker build` command produce plain progress output

### Fixed

- Update to apptestctl to v0.14.1 to fix problem with AppCatalogEntry CRD.

## [4.14.2] - 2022-03-08

### Fixed

- Check out app catalog at default `HEAD` instead of specifying `master` branch for compatibility with `main` branch.

## [4.14.1] - 2022-03-07

### Added

- Add retry logic to the docker-push step

## [4.14.0] - 2022-03-04

### Changed

- Update `architect` version to [`v6.3.0`](https://github.com/giantswarm/architect/releases/tag/v6.3.0).
  - Updates Go version to 1.17.8.
- Update Go version used in `machine install` command to 1.17.8.

## [4.13.0] - 2022-02-18

### Changed

- Don't push Argo application CRs to app collections now Flux migration is done.

## [4.12.0] - 2022-02-11

### Changed

- Default to use `DOCKER_BUILDKIT=1` environment variable in `push-to-docker` job.
- Update `architect` version to [`v6.2.0`](https://github.com/giantswarm/architect/releases/tag/v6.2.0).
  - Updates Go version to 1.17.7
- Update Go version used in `machine-install` command to 1.17.7.

## [4.11.0] - 2022-02-09

### Changed

- Update architect to 6.1.1.

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

- Create Argo CD Application CR alongside Giant Swarm App CR in `push-to-app-collection` job. They are pushed to separate _/manifests_ directory.

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
  - <https://github.com/giantswarm/giantswarm/issues/10423#issuecomment-637398805>

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

- Fix pushing new unique app in push-to-app-collection job. <https://github.com/giantswarm/architect-orb/pull/69>

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

[Unreleased]: https://github.com/giantswarm/architect-orb/compare/v5.8.0...HEAD
[5.8.0]: https://github.com/giantswarm/architect-orb/compare/v5.7.0...v5.8.0
[5.7.0]: https://github.com/giantswarm/architect-orb/compare/v5.6.0...v5.7.0
[5.6.0]: https://github.com/giantswarm/architect-orb/compare/v5.5.2...v5.6.0
[5.5.2]: https://github.com/giantswarm/architect-orb/compare/v5.5.1...v5.5.2
[5.5.1]: https://github.com/giantswarm/architect-orb/compare/v5.5.0...v5.5.1
[5.5.0]: https://github.com/giantswarm/architect-orb/compare/v5.4.0...v5.5.0
[5.4.0]: https://github.com/giantswarm/architect-orb/compare/v5.3.1...v5.4.0
[5.3.1]: https://github.com/giantswarm/architect-orb/compare/v5.3.0...v5.3.1
[5.3.0]: https://github.com/giantswarm/architect-orb/compare/v5.2.1...v5.3.0
[5.2.1]: https://github.com/giantswarm/architect-orb/compare/v5.2.0...v5.2.1
[5.2.0]: https://github.com/giantswarm/architect-orb/compare/v5.1.2...v5.2.0
[5.1.2]: https://github.com/giantswarm/architect-orb/compare/v5.1.1...v5.1.2
[5.1.1]: https://github.com/giantswarm/architect-orb/compare/v5.1.0...v5.1.1
[5.1.0]: https://github.com/giantswarm/architect-orb/compare/v5.0.1...v5.1.0
[5.0.1]: https://github.com/giantswarm/architect-orb/compare/v5.0.1...v5.0.1
[5.0.0]: https://github.com/giantswarm/architect-orb/compare/v4.38.0...v5.0.0
[4.38.0]: https://github.com/giantswarm/architect-orb/compare/v4.37.0...v4.38.0
[4.37.0]: https://github.com/giantswarm/architect-orb/compare/v4.36.0...v4.37.0
[4.36.0]: https://github.com/giantswarm/architect-orb/compare/v4.35.6...v4.36.0
[4.35.6]: https://github.com/giantswarm/architect-orb/compare/v4.35.5...v4.35.6
[4.35.5]: https://github.com/giantswarm/architect-orb/compare/v4.35.4...v4.35.5
[4.35.4]: https://github.com/giantswarm/architect-orb/compare/v4.35.3...v4.35.4
[4.35.3]: https://github.com/giantswarm/architect-orb/compare/v4.35.2...v4.35.3
[4.35.2]: https://github.com/giantswarm/architect-orb/compare/v4.35.1...v4.35.2
[4.35.1]: https://github.com/giantswarm/architect-orb/compare/v4.35.0...v4.35.1
[4.35.0]: https://github.com/giantswarm/architect-orb/compare/v4.34.1...v4.35.0
[4.34.1]: https://github.com/giantswarm/architect-orb/compare/v4.34.0...v4.34.1
[4.34.0]: https://github.com/giantswarm/architect-orb/compare/v4.33.1...v4.34.0
[4.33.1]: https://github.com/giantswarm/architect-orb/compare/v4.33.0...v4.33.1
[4.33.0]: https://github.com/giantswarm/architect-orb/compare/v4.32.0...v4.33.0
[4.32.0]: https://github.com/giantswarm/architect-orb/compare/v4.31.0...v4.32.0
[4.31.0]: https://github.com/giantswarm/architect-orb/compare/v4.24.0...v4.31.0
[4.30.1]: https://github.com/giantswarm/architect-orb/compare/v4.30.0...v4.30.1
[4.30.0]: https://github.com/giantswarm/architect-orb/compare/v4.29.0...v4.30.0
[4.29.0]: https://github.com/giantswarm/architect-orb/compare/v4.28.1...v4.29.0
[4.28.1]: https://github.com/giantswarm/architect-orb/compare/v4.28.0...v4.28.1
[4.28.0]: https://github.com/giantswarm/architect-orb/compare/v4.26.0...v4.28.0
[4.26.0]: https://github.com/giantswarm/architect-orb/compare/v4.25.3...v4.26.0
[4.25.3]: https://github.com/giantswarm/architect-orb/compare/v4.25.2...v4.25.3
[4.25.2]: https://github.com/giantswarm/architect-orb/compare/v4.25.1...v4.25.2
[4.25.1]: https://github.com/giantswarm/architect-orb/compare/v4.25.0...v4.25.1
[4.25.0]: https://github.com/giantswarm/architect-orb/compare/v4.24.0...v4.25.0
[4.24.0]: https://github.com/giantswarm/architect-orb/compare/v4.23.0...v4.24.0
[4.23.0]: https://github.com/giantswarm/architect-orb/compare/v4.22.0...v4.23.0
[4.22.0]: https://github.com/giantswarm/architect-orb/compare/v4.21.1...v4.22.0
[4.21.1]: https://github.com/giantswarm/architect-orb/compare/v4.21.0...v4.21.1
[4.21.0]: https://github.com/giantswarm/architect-orb/compare/v4.20.0...v4.21.0
[4.20.0]: https://github.com/giantswarm/architect-orb/compare/v4.19.0...v4.20.0
[4.19.0]: https://github.com/giantswarm/architect-orb/compare/v4.18.0...v4.19.0
[4.18.0]: https://github.com/giantswarm/architect-orb/compare/v4.17.0...v4.18.0
[4.17.0]: https://github.com/giantswarm/architect-orb/compare/v4.16.0...v4.17.0
[4.16.0]: https://github.com/giantswarm/architect-orb/compare/v4.15.0...v4.16.0
[4.15.0]: https://github.com/giantswarm/architect-orb/compare/v4.14.4...v4.15.0
[4.14.4]: https://github.com/giantswarm/architect-orb/compare/v4.14.3...v4.14.4
[4.14.3]: https://github.com/giantswarm/architect-orb/compare/v4.14.2...v4.14.3
[4.14.2]: https://github.com/giantswarm/architect-orb/compare/v4.14.1...v4.14.2
[4.14.1]: https://github.com/giantswarm/architect-orb/compare/v4.14.0...v4.14.1
[4.14.0]: https://github.com/giantswarm/architect-orb/compare/v4.13.0...v4.14.0
[4.13.0]: https://github.com/giantswarm/architect-orb/compare/v4.12.0...v4.13.0
[4.12.0]: https://github.com/giantswarm/architect-orb/compare/v4.11.0...v4.12.0
[4.11.0]: https://github.com/giantswarm/architect-orb/compare/v4.10.1...v4.11.0
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
