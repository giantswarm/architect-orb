# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New `cosign-prepare` command. Mints a CircleCI OIDC token with `aud=sigstore` via `circleci run oidc get --root-issuer`, exporting it as `SIGSTORE_ID_TOKEN` through `BASH_ENV`. The cosign signing blocks in `image-build-and-push` and `push-helm` now call this single command instead of duplicating the token-mint logic.
- Cosign keyless signing for Go binaries produced by the `go-build` command/job. Each `<binary>-<GOOS>-<GOARCH>` gets a sibling `<binary>-<GOOS>-<GOARCH>.bundle` Sigstore bundle, verified immediately with `cosign verify-blob`. Public repos only — private repos are skipped at runtime to avoid leaking artifacts into the public Rekor transparency log. Controlled by `sign: true|false` (default `true`) on both `go-build` job and command. Bundles ride along the existing workspace persistence glob.
- New `upload-release-assets` job. Attaches workspace-persisted `<binary>-<GOOS>-<GOARCH>` files (and their cosign `.bundle` siblings) to the GitHub Release for the current tag with `gh release upload --clobber`. Retries up to `attempts` times (default 12 × 5s) to absorb the race with the release-creation GitHub Action. Helm charts and container images intentionally stay in the OCI registry.
- `hadolint` step in `push-to-registries`. Lints `<<parameters.dockerfile>>` before the buildx build using the hadolint binary baked into the architect image. Controlled by `hadolint: warn|fail|skip` (default `warn` — findings printed, build continues) and `hadolint-config` (optional path to `.hadolint.yaml`).
- Cosign keyless signing for Helm charts pushed to the giantswarm OCI registry. Public charts only — private charts are skipped at runtime to avoid leaking digests/timestamps into the public Rekor transparency log. Same OIDC mechanism as container-image signing (`circleci run oidc get --claims '{"aud":"sigstore"}' --root-issuer`). Controlled by `sign: true|false` (default `true`) on `push-to-app-catalog` and the underlying `push-helm` command. Signature lands as an OCI 1.1 referrer artifact, queryable via the registry's referrers API.

### Removed

- **Breaking.** `push-to-registries-multiarch` job (deprecated since v7.0). Migrate to `push-to-registries`.
- **Breaking.** `multiarch:` parameter on `push-to-registries`. The job always uses `docker buildx` now; consumers of the previous default (`multiarch: false`) get multi-arch builds automatically.
- **Breaking.** `os` parameter on the `go-build` command and job (deprecated and ignored since v8.1). Use `architectures` instead.
- **Breaking.** Singular `architecture` parameter on the `go-build` command and job. Replaced entirely by `architectures` (plural). Matrix-based callers must switch to a single job with a comma-separated list.
- **Breaking.** `image-build-with-docker` and `image-push-to-registries` commands (the single-arch `docker build` / `docker push` path). The single-arch path is collapsed into the buildx path; nothing else in the orb referenced these commands.
- `password_envar`, `username_envar`, `registry_url` parameters on `push-helm` and the two `[deprecated]` legacy OCI auth/push run steps that used them. The current OCI push flow uses `generate-github-token` + the giantswarm OCI authenticator instead.

### Changed

- **Breaking.** `image-build-and-push-multiarch` command renamed to `image-build-and-push` — multi-arch is no longer a distinguishing trait. Direct callers of the command need to update the name; consumers of the `push-to-registries` job are unaffected.

### Added

- SLSA provenance attestation enabled by default (`provenance: min`) on the multi-arch path. Configurable via `provenance: min|max|false`. **Note**: `max` mode embeds all `--build-arg` values verbatim into the attestation; do not use it on projects that pass secrets via `--build-arg`. Attestations are stored *inline* in the image index (the `unknown/unknown` manifest entries seen in `docker manifest inspect`) — BuildKit does not currently support OCI 1.1 referrer storage for attestations; `docker buildx imagetools inspect` shows them with proper labels.
- SBOM (SPDX) attestation enabled by default (`sbom: true`) on the multi-arch path. Configurable via `sbom: true|false`. Same inline-storage caveat as provenance.
- Cosign keyless image signing enabled by default (`sign: true`) on the multi-arch path. Signatures are stored as proper OCI 1.1 referrer artifacts (cosign's own implementation, independent of BuildKit). **Public images only** — private images are skipped at runtime to avoid leaking digests/timestamps into the public Rekor transparency log. A fresh CircleCI OIDC token with `aud=sigstore` is minted via `circleci run oidc get --claims '{"aud":"sigstore"}' --root-issuer`; the auto-injected `CIRCLE_OIDC_TOKEN_V2` is not used because its audience doesn't match what Fulcio's CircleCI federation expects. The signing cert SAN URI is UUID-based (CircleCI's choice), but the Sigstore X.509 extensions populate the friendly source repo URI (`github.com/<org>/<repo>`) in OID `1.3.6.1.4.1.57264.1.12`, so verification policies can pin to the readable identity.
- `--metadata-file` capture from buildx is now used to resolve the manifest index digest for cosign signing.
- Register QEMU/binfmt handlers (`tonistiigi/binfmt --install all`) before `docker buildx build` so Dockerfiles with `RUN` steps on a non-host architecture work without consumers needing `--platform=$BUILDPLATFORM` themselves. The image tag is bumped automatically by Renovate.
- Replace the buildx builder bootstrap (`buildx create --use 2>/dev/null || buildx use`) with explicit `buildx inspect` / `create --driver docker-container` / `inspect --bootstrap`, so failures in builder setup surface instead of being masked.
- `architectures` parameter on the `go-build` command and job: comma-separated list (e.g. `linux/amd64,linux/arm64`) that builds all targets in a single job, removing the need for a CircleCI matrix at the consumer. Writes the resolved list to `.platforms` in the workspace.
- Auto-derive `platforms` in `push-to-registries` (and the legacy `push-to-registries-multiarch`) from the `.platforms` file written by `go-build`. The `platforms` parameter default is now `""` and falls back to `linux/amd64,linux/arm64` when neither an explicit value nor a workspace file is available — existing consumers see no behavior change.
- Standard OCI image labels emitted by default in both single-arch (`docker build`) and multi-arch (`docker buildx build`) paths: `org.opencontainers.image.{source,revision,version,created}`. In multi-arch mode the same values are also emitted as OCI manifest index annotations. The `created` label is taken from the commit timestamp (`git show -s --format=%cI`) so rebuilds of the same SHA produce identical labels; the `version` label is omitted when no tag is available rather than emitting `unknown`.
- `oci-labels` boolean parameter (default `true`) on `push-to-registries`, `push-to-registries-multiarch`, `image-build-with-docker`, and `image-build-and-push-multiarch` to opt out of the standard labels.

### Changed

- `image-login-to-registries`: docker and regctl logins now pipe the password via stdin (`--password-stdin` / `--pass-stdin`) instead of building a shell command string. Drops the `eval`-based env-var resolution in the regctl branch in favour of bash indirect expansion.
- `image-login-to-registries`: read the registries data file directly (`while read … done < .registries_data`) instead of piping through `cat`, so a failed login terminates the script instead of being trapped in a subshell.
- `go-build`: validate the `architectures` parameter against `^[a-zA-Z0-9/_,-]+$` before splitting, matching the existing check on `platforms`.

### Fixed

- Drop the duplicated `<version>-<suffix>-<suffix>` tag emitted by the multi-arch push when `tag-suffix` was set (the suffix is already baked into `DOCKER_IMAGE_TAG`).
- Read the single `.ldflags` file (written by `go-test`) in the multi-arch `go-build` path. The previous lookup of `.ldflags-<GOOS>-<GOARCH>` always missed and silently dropped `gitSHA` / `buildTimestamp` from cross-compiled binaries.
- Remove the unreachable legacy branch in `go-build` (the `architecture` default of `linux/amd64` made the `os`-based branch dead code). The `os` parameter is kept for backward compatibility but is now ignored; use `architectures` instead.
- Fail loudly when the GitHub repository visibility check returns a non-200 status or an unparseable body. Previously a rate-limited or errored API response caused the image to be silently treated as private, skipping pushes to public registries.
- Pin `setup_remote_docker` to `docker24` in `push-to-registries` and `push-to-registries-multiarch` to keep image builds reproducible across CircleCI default-version drift.
- `image-login-to-registries`: turn off shell xtrace before resolving registry credentials so passwords are no longer printed into CI logs by the `set -x` trace.

### Deprecated

- The `os` parameter on `go-build` is now ignored (kept for backward compatibility). Use `architectures` for multi-arch or `architecture` for single-arch matrix-based callers.

## [8.0.2] - 2026-05-07

### Fixed

- Revert the v8.0.1 `setup_remote_docker version: docker24` pin in `push-to-registries` and `push-to-registries-multiarch` back to `default`. The pin only covered the daemon side; the architect executor's Docker client (installed via Alpine's `apk add docker`) tracks Alpine stable and is now Docker 28.x (API 1.52), which the pinned daemon (API 1.43 max) refused with `client version 1.52 is too new. Maximum supported API version is 1.43`. Letting the daemon track CircleCI's default lets the two sides stay compatible.

## [8.0.1] - 2026-05-07

### Fixed

- `go-build`: narrow the workspace persist glob from `./<binary>*` to `./<binary>-*-*` (multi-arch named binaries) plus `./<binary>` only on the linux/amd64 build. The previous wildcard also captured unrelated repo files matching the binary prefix (e.g. `<binary>-manifest.yaml`), causing matrix multi-arch builds to fail at `attach_workspace` with "Concurrent upstream jobs persisted the same file(s)".
- Drop the duplicated `<version>-<suffix>-<suffix>` tag emitted by the multi-arch push when `tag-suffix` was set (the suffix is already baked into `DOCKER_IMAGE_TAG`).
- Read the single `.ldflags` file (written by `go-test`) in the multi-arch `go-build` path. The previous lookup of `.ldflags-<GOOS>-<GOARCH>` always missed and silently dropped `gitSHA` / `buildTimestamp` from cross-compiled binaries.
- Remove the unreachable legacy branch in `go-build` (the `architecture` default of `linux/amd64` made the `os`-based branch dead code). The `os` parameter is kept for backward compatibility but is now ignored; use `architecture` instead.
- Fail loudly when the GitHub repository visibility check returns a non-200 status or an unparseable body. Previously a rate-limited or errored API response caused the image to be silently treated as private, skipping pushes to public registries.
- Pin `setup_remote_docker` to `docker24` in `push-to-registries` and `push-to-registries-multiarch` to keep image builds reproducible across CircleCI default-version drift.

## [8.0.0] - 2026-05-06

### Removed

- Remove `push-to-app-collection` command and job.

## [7.1.0] - 2026-04-28

### Added

- Split pushes to China into two jobs.

## [7.0.0] - 2026-04-24

### Added

- Add `multiarch`, `platforms`, and `annotations` parameters to `push-to-registries` job, enabling multi-architecture image builds via `docker buildx` as an opt-in path (`multiarch: true`). Single-arch behaviour is unchanged. `platforms` defaults to `"linux/amd64,linux/arm64"`.
- Add `clone_depth` parameter to the `go-build` job. Defaults to `1` (preserves current behaviour). Set to `0` for full history when build steps need `git log` / `git rev-list` to traverse the whole repo (e.g. `go generate` that records the last commit touching a file). Any value greater than `1` deepens the history to that many commits.

### Deprecated

- `push-to-registries-multiarch` job is deprecated. Use `push-to-registries` with `multiarch: true` instead. It will be removed in the next major version.

### Removed

- Remove deprecated `run-kat-tests` job and related `kat-tests-install-tools` and `kat-tests-run` commands. The `kube-app-testing` tool is no longer maintained.

### Changed

- Improved wording and documentation for `goimports` step in `go-test` job

## [6.15.0] - 2026-03-12

### Changed

- Update gitleaks executor to v8.30.0
- Update app-build-suite executor to 1.7.0-circleci

### Fixed

- Improve error handling in `push-helm` command's OCI registry step. The GitHub API call to detect repository visibility now checks the HTTP status code, validates JSON responses, and prints the actual response body on failure instead of producing a cryptic `jq` parse error.

## [6.14.1] - 2026-02-24

### Fixed

- Fix `push_dev` detection in multi-arch image push: the tag regex was anchored (`^[a-f0-9]{40}$`) and never matched the actual `version-commitsha` tag format produced by `architect project version`, causing dev images to be pushed to registries with `push_dev: false` (e.g. Aliyun).

## [6.14.0] - 2026-02-20

### Added

- Add optional `annotations` parameter to `push-to-registries-multiarch` for OCI manifest annotations via `docker buildx build --annotation`.

## [6.13.0] - 2026-02-18

### Changed

- Update architect executor to v7.4.0, which brings app-build-suite to v1.7.0

## [6.12.0] - 2026-01-20

### Fixed

- Update app-build-suite image version to 1.5.2, which fixes handling of GitHub URLs for non-tag builds.
- Update app-build-suite image version to 1.5.1, which fixes support for OCI-compliant chart annotations.

## [6.11.0] - 2025-12-11

### Added

- Add `force-public` flag to `push-to-app-catalog` job.

## [6.10.0] - 2025-12-09

### Changed

- Default multiarch image builds to `linux/amd64` and `linux/arm64` (previously this was only linux/amd64)

### Fixed

- Update app-build-suite image version to 1.4.3, which fixes support for OCI-compliant chart annotations.

## [6.9.0] - 2025-12-04

### Changed

- Use app-build-suite v1.4.2, which brings support for OCI-compliant chart annotations.

## [6.8.0] - 2025-11-04

### Added

- Add `generate-github-token` command that can generate a temporary token from a GitHub App (private key, app id, installation id) and store in `GITHUB_TOKEN` environment variable in `BASH_ENV`.
- Push charts to `gsoci` (public images) and `gsociprivate` (private images) registries under `charts/giantswarm`.

### Changed

- Mark steps pushing charts to `giantswarmpublic` as deprecated.
- Change visibility detection of repositories to use a temporary GitHub token and check for: image push, multi architecture image push.

### Removed

- Removed all info regarding pushing images to `quay.io/giantswarm` and `docker.io/giantswarm` from docs and comments


## [6.7.0] - 2025-10-01

### Changed

- Use architect v7.2.1 which supports running on ARM.

## [6.6.1] - 2025-09-08

### Fixed

- Change download URL for `kubectl` to `https://dl.k8s.io/release/VERSION/bin/linux/amd64/kubectl`

### Changed

- Add retries to downloads in `integration-test-install-tools` steps

## [6.6.0] - 2025-09-05

### Changed

- Update app-build-suite to v1.2.9
- Update gitleaks to v8.28.0
- Update kind to v0.30.0
- Update default apptestctl version to v0.24.0
- Update default helm version to v3.18.6
- Update default Kubernetes version to v1.31.12

## [6.5.0] - 2025-09-03

### Removed

- Remove `ManagementClusterConfiguration` support from `push-to-app-collection` command.

## [6.4.1] - 2025-09-03

### Changed

- Update `run-tests-with-ats` job with latest app-test-suite version.

## [6.4.0] - 2025-08-15

### Changed

- Use architect v7.1.0 that applies Go 1.25

## [6.3.2] - 2025-08-06

### Changed

- The `skip_conftest_deprek8ion` parameter is now ignored and will be removed in the future.

### Removed

- The `helm-conftest` step in the `push-to-app-catalog` job is removed.

## [6.3.1] - 2025-08-06

### Changed

- Update architect to v7.0.3

## [6.3.0] - 2025-08-06

### Added

- Update `push-to-app-collection` with knowledge on how to update `Konfiguration` CRs in collections.

### Changed

- Update `push-to-app-collection` to skip updating `ManagementClusterConfiguration` CRs in a collection if `kustomize/konfiguration.yaml` does not exist.
- Update `push-to-app-collection` to respect other job parameters as well on version updates in `App` CRs.

## [6.2.1] - 2025-07-08

### Changed

- Update `run-tests-with-ats` job with latest app-test-suite version.

## [6.2.0] - 2025-07-07

### Changed

- Update `run-tests-with-ats` job with latest app-test-suite version.

## [6.1.0] - 2025-07-03

### Added

- Unified multi-arch and single-arch image build/push logic into `image-build-and-push-multiarch.yaml` command and `push-to-registries-multiarch` job.
- Simplified `go-build` job and command: now supports multi-arch and always produces a `binary` for `linux/amd64`.

## [6.0.0] - 2025-06-11

### Removed

- Remove support for konfigure generators in `push-to-app-collection` command.

## [5.15.0] - 2025-05-14

### Changed

- Do not update or create konfigure generator input when the `./flux-manifests` folder does not exist in the collection.
- Print values file name when testing with `conftest`.

## [5.14.0] - 2025-05-08

### Removed

- Remove golangci-lint from go-test and go-build

## [5.13.1] - 2025-04-28

### Changed

- Bump architect to v6.20.1, which incluces a downgrade of golangci-lint from v1.64.8 to v1.64.7

## [5.13.0] - 2025-04-24

### Changed

- Remove the version command check from go-build job

### Added

- Added support for App CRs in `push-to-app-collection` command.

## [5.12.1] - 2025-04-03

### Changed

- Run `helm dependency update` before trying to template the target chart in `run-kyverno-tests` job.

## [5.12.0] - 2025-03-28

### Added

- Add `run-kyverno-tests` job for easy Kyverno policies validation.

## [5.11.6] - 2025-03-14

### Changed

- architect version changed to [v6.19.1](https://github.com/giantswarm/architect/releases/tag/v6.19.1)

## [5.11.5] - 2025-02-13

### Changed

- architect version changed to [v6.18.2](https://github.com/giantswarm/architect/releases/tag/v6.18.2), which updates the golangci-lint version used to v1.64.4, which is compatible with Go 1.24.

## [5.11.4] - 2025-01-07

### Fixed

- Run `app-build-suite` before `conftest` in `push-to-app-catalog` job to fix missing subchart issue.

## [5.11.3] - 2025-01-07

### Changed

- Reorder commands in `push-to-app-catalog` job to prevent duplicated code and duplicated executions of architect and app-build-suite.

## [5.11.2] - 2024-12-04

### Added

- Add `go-test` checks for non-ASCII filenames and non-ASCII characters in Go code.
- update `app-build-suite` executor to 1.2.8

## [5.11.1] - 2024-10-31

### Changed

- Update dependency app-test-suite to v0.10.2 (#573)

## [5.11.0] - 2024-10-29

### Changed

- Update Kind, Helm and Kubernetes versions in integration-test jobs (#570).
- Update dependency app-test-suite to v0.10.1 (#570)
- Support new app creation in collections. (#555)
- Update dependency architect to v5.10.1. (#568)

## [5.10.1] - 2024-10-09

### Changed

- Update dependency architect to v5.10.0 (#565)
- Jobs: Bump App Test Suite to v0.8.1. (#566)

## [5.10.0] - 2024-10-08

- Bump `app-build-suite` to v1.2.5.

## [5.9.0] - 2024-10-08

### Changed

- Bump `app-test-suite_version` default to v0.8.0.
- Updated Kubernetes versions in kubeconform command.
- Bump `app-build-suite` to v1.2.3.

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

- Change download URL of `dats.sh` wrapper to use raw.githubusercontent.com to be able to run pre-release versions of app-test-suite in `run-tests-with-abs` job.

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

[Unreleased]: https://github.com/giantswarm/architect-orb/compare/v8.0.2...HEAD
[8.0.2]: https://github.com/giantswarm/architect-orb/compare/v8.0.1...v8.0.2
[8.0.1]: https://github.com/giantswarm/architect-orb/compare/v8.0.0...v8.0.1
[8.0.0]: https://github.com/giantswarm/architect-orb/compare/v7.1.0...v8.0.0
[7.1.0]: https://github.com/giantswarm/architect-orb/compare/v7.0.0...v7.1.0
[7.0.0]: https://github.com/giantswarm/architect-orb/compare/v6.15.0...v7.0.0
[6.15.0]: https://github.com/giantswarm/architect-orb/compare/v6.14.1...v6.15.0
[6.14.1]: https://github.com/giantswarm/architect-orb/compare/v6.14.0...v6.14.1
[6.14.0]: https://github.com/giantswarm/architect-orb/compare/v6.13.0...v6.14.0
[6.13.0]: https://github.com/giantswarm/architect-orb/compare/v6.12.0...v6.13.0
[6.12.0]: https://github.com/giantswarm/architect-orb/compare/v6.11.0...v6.12.0
[6.11.0]: https://github.com/giantswarm/architect-orb/compare/v6.10.0...v6.11.0
[6.10.0]: https://github.com/giantswarm/architect-orb/compare/v6.9.0...v6.10.0
[6.9.0]: https://github.com/giantswarm/architect-orb/compare/v6.8.0...v6.9.0
[6.8.0]: https://github.com/giantswarm/architect-orb/compare/v6.7.0...v6.8.0
[6.7.0]: https://github.com/giantswarm/architect-orb/compare/v6.6.1...v6.7.0
[6.6.1]: https://github.com/giantswarm/architect-orb/compare/v6.6.0...v6.6.1
[6.6.0]: https://github.com/giantswarm/architect-orb/compare/v6.5.0...v6.6.0
[6.5.0]: https://github.com/giantswarm/architect-orb/compare/v6.4.1...v6.5.0
[6.4.1]: https://github.com/giantswarm/architect-orb/compare/v6.4.0...v6.4.1
[6.4.0]: https://github.com/giantswarm/architect-orb/compare/v6.3.2...v6.4.0
[6.3.2]: https://github.com/giantswarm/architect-orb/compare/v6.3.1...v6.3.2
[6.3.1]: https://github.com/giantswarm/architect-orb/compare/v6.3.0...v6.3.1
[6.3.0]: https://github.com/giantswarm/architect-orb/compare/v6.2.1...v6.3.0
[6.2.1]: https://github.com/giantswarm/architect-orb/compare/v6.2.0...v6.2.1
[6.2.0]: https://github.com/giantswarm/architect-orb/compare/v6.1.0...v6.2.0
[6.1.0]: https://github.com/giantswarm/architect-orb/compare/v6.0.0...v6.1.0
[6.0.0]: https://github.com/giantswarm/architect-orb/compare/v5.15.0...v6.0.0
[5.15.0]: https://github.com/giantswarm/architect-orb/compare/v5.14.0...v5.15.0
[5.14.0]: https://github.com/giantswarm/architect-orb/compare/v5.13.1...v5.14.0
[5.13.1]: https://github.com/giantswarm/architect-orb/compare/v5.13.0...v5.13.1
[5.13.0]: https://github.com/giantswarm/architect-orb/compare/v5.12.1...v5.13.0
[5.12.1]: https://github.com/giantswarm/architect-orb/compare/v5.12.0...v5.12.1
[5.12.0]: https://github.com/giantswarm/architect-orb/compare/v5.11.6...v5.12.0
[5.11.6]: https://github.com/giantswarm/architect-orb/compare/v5.11.5...v5.11.6
[5.11.5]: https://github.com/giantswarm/architect-orb/compare/v5.11.4...v5.11.5
[5.11.4]: https://github.com/giantswarm/architect-orb/compare/v5.11.3...v5.11.4
[5.11.3]: https://github.com/giantswarm/architect-orb/compare/v5.11.2...v5.11.3
[5.11.2]: https://github.com/giantswarm/architect-orb/compare/v5.11.1...v5.11.2
[5.11.1]: https://github.com/giantswarm/architect-orb/compare/v5.11.0...v5.11.1
[5.11.0]: https://github.com/giantswarm/architect-orb/compare/v5.10.1...v5.11.0
[5.10.1]: https://github.com/giantswarm/architect-orb/compare/v5.10.0...v5.10.1
[5.10.0]: https://github.com/giantswarm/architect-orb/compare/v5.9.0...v5.10.0
[5.9.0]: https://github.com/giantswarm/architect-orb/compare/v5.8.0...v5.9.0
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
[5.0.1]: https://github.com/giantswarm/architect-orb/compare/v5.0.0...v5.0.1
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
[0.18.0]: https://github.com/giantswarm/architect-orb/compare/v0.17.1...v0.18.0
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
