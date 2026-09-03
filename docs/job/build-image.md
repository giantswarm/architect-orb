# build-image

Builds the container image for **one** architecture, on a machine of that
architecture.

Run one `build-image` job per architecture. Each builds its platform natively —
nothing is emulated — and pushes it to the registries **by digest**, with no tag.
A [`push-to-registries`](push-to-registries.md) job with `merge-digests: true`
then joins the digests into one tagged index per registry and signs it.

```
build-image (linux/amd64, small)     ─┐
                                      ├─▶ push-to-registries (merge-digests: true)
build-image (linux/arm64, arm.medium) ─┘
```

This is the opt-in alternative to the single-job build that `push-to-registries`
does by default. It pays off for Dockerfiles with real work in their `RUN` steps
(`apt-get install`, `pip install`, `yarn install`, native-module compiles), where
the emulated architecture of a single multi-platform build is the whole critical
path. A Dockerfile that only `COPY`s a cross-compiled binary gains nothing from
it; see [When not to opt in](push-to-registries.md#when-not-to-opt-in).

By default it uses the `Dockerfile` at the workspace root and the root directory
as the build context; pass `dockerfile` and `build-context` to override.

## Why one job per architecture

A CircleCI job runs on one machine, and a machine is native for one architecture.
One job per architecture is what keeps every `RUN` step native. The jobs run
concurrently, so wall clock is the slower single build rather than the sum.

`resource_class` must match `platform` — that is the whole point. CircleCI gives
the `setup_remote_docker` VM the architecture of the job's resource class, so
`arm.medium` for a `linux/arm64` build and `small`/`medium` for `linux/amd64`.
There is no `arm.small`; `arm.medium` is the smallest Arm class.

**A mismatch fails the job.** It does not fall back to QEMU.

## Publishing the index

```yaml
- architect/build-image:
    name: build-image-amd64
    platform: linux/amd64
    resource_class: small
    requires: [go-build]

- architect/build-image:
    name: build-image-arm64
    platform: linux/arm64
    resource_class: arm.medium
    requires: [go-build]

- architect/push-to-registries:
    name: push-to-registries
    merge-digests: true
    platforms: linux/amd64,linux/arm64
    requires: [build-image-amd64, build-image-arm64]
```

See [push-to-registries → Native per-architecture builds](push-to-registries.md#native-per-architecture-builds-opt-in)
for the full before/after and what the merge job does.

## Branch validation

With `push: false` the job builds and discards, so a Dockerfile regression
surfaces on the PR instead of at tag time. No credentials are used, no digest is
recorded, and provenance and SBOM generation are skipped — those only make sense
on a published image. There is no `push-to-registries` job on such a path: with
nothing pushed there is nothing to merge.

```yaml
- architect/build-image:
    name: verify-image-amd64
    platform: linux/amd64
    resource_class: small
    push: false

- architect/build-image:
    name: verify-image-arm64
    platform: linux/arm64
    resource_class: arm.medium
    push: false
```

## How the push works

The job runs
`--output type=image,"name=<reg1>/<img>,<reg2>/<img>",push-by-digest=true,...`,
which pushes the manifest to every eligible registry without creating a tag, and
records the resulting digest in `.image-digests/<image><tag-suffix>/<platform>`
in the workspace. The directory is namespaced by image and `tag-suffix`, so two
builds in one pipeline (a mono-repo with two Dockerfiles) stay separate, and it
holds one file per platform, so every architecture's job can persist into it
without colliding.

The manifest is a build intermediate: tagging it would publish a second artifact
under the same version that works on one architecture only, and that a consumer
could pin by mistake. The trade-off is that a pipeline that fails after the build
leaves untagged manifests behind, so **untagged-manifest retention wants to be
enabled on the target registries** — the same prerequisite the build cache
already has.

**Attestations are produced per architecture.** BuildKit can only attest what it
built, so `--attest` runs here. Each push is itself an index: the image manifest
plus its attestation manifest. The merge copies those child indexes whole, which
is what keeps the attestations attached to their platform in the published index.

## Parameters

Two parameters are specific to this job:

- `platform` (required) — the single platform to build.
- `persist-build-version` (default `false`) — write `.build_version` to the
  workspace for `package-helm-with-abs`. These jobs run concurrently and
  CircleCI refuses to attach a workspace that two concurrent jobs persisted the
  same path into, so set it on **exactly one** job per path, and only if a chart
  job downstream needs it. On a path that ends in a `push-to-registries` merge,
  leave it `false` everywhere: that job persists `.build_version`.

The rest are the build half of the `push-to-registries` parameters, and behave
identically. See that page for the details:

- [Build cache](push-to-registries.md#build-cache) — `cache`, `cache-ref`. The
  platform is appended to the cache ref, derived or explicit, because these jobs
  run concurrently and would otherwise race on one ref.
- [Dockerfile requirements](push-to-registries.md#dockerfile-requirements) —
  still worth following. They keep a local multi-platform build fast, though in
  CI the host is always the target.
- [Hadolint](push-to-registries.md#hadolint) — `hadolint`, `hadolint-config`.
  The lint is a property of the source, not the architecture, so it runs in
  every architecture's job. It costs about a second and fails before minutes of
  building past a broken Dockerfile.
- [OCI image labels](push-to-registries.md#oci-image-labels) — `oci-labels`.
  Labels are image-config level and survive a merge untouched. Index
  annotations do not, so `index:`-scoped `annotations` are **rejected** here;
  only `manifest:`-scoped ones are accepted. The merge job re-applies the
  index-level `org.opencontainers.image.*` annotations.

## Things that bite

**`split-china-push` and `force-public` must match** the values on the
`push-to-registries` job, or the two disagree about which registries hold the
per-architecture digests.

**`persist-build-version` belongs on exactly one job per path.** These jobs run
concurrently, and CircleCI refuses to attach a workspace that two concurrent jobs
persisted the same path into, so it defaults to `false`. On a path with a
`push-to-registries` merge that job writes `.build_version`. On a validate-only
branch path with no `push-to-registries` job, set it on one `build-image` job if
a chart job downstream needs the version — otherwise `package-helm-with-abs`
falls back to bare `gitsemver get`, which does not apply `tag-suffix`.

**The platform set lives in the workflow.** The set of architectures is the list
of `build-image` jobs, and the `platforms` parameter of the `push-to-registries`
merge must agree with it. A mismatch fails the merge loudly rather than
publishing a partial index.

**There is no native class for every platform.** `linux/arm/v7`, `linux/s390x`
and `linux/ppc64le` have no CircleCI resource class of their architecture, so
they cannot be built this way. Keep those images on the single-job build, which
emulates them.
