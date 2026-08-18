# build-image

Builds the container image for **one** architecture, on a machine of that
architecture.

Run one `build-image` job per architecture. Each builds its platform natively —
nothing is emulated — and pushes it to the registries **by digest**, with no tag.

```
build-image (linux/amd64, small)
build-image (linux/arm64, arm.medium)
```

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

## Branch validation

With `push: false` the job builds and discards, so a Dockerfile regression
surfaces on the PR instead of at tag time. No credentials are used, no digest is
recorded, and provenance and SBOM generation are skipped — those only make sense
on a published image.

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
in the workspace.

The manifest is a build intermediate: tagging it would publish a second artifact
under the same version that works on one architecture only, and that a consumer
could pin by mistake. The trade-off is that a
pipeline that fails after the build leaves untagged manifests behind, so
**untagged-manifest retention wants to be enabled on the target registries** —
the same prerequisite the build cache already has.

**Attestations are produced per architecture.** BuildKit can only attest what it
built, so `--attest` runs here. Each push is itself an index: the image manifest
plus its attestation manifest.

## Parameters

Two parameters are specific to this job:

- `platform` (required) — the single platform to build.
- `persist-build-version` (default `false`) — write `.build_version` to the
  workspace for `package-helm-with-abs`. These jobs run concurrently and
  CircleCI refuses to attach a workspace that two concurrent jobs persisted the
  same path into, so set it on **exactly one** job per path, and only if a chart
  job downstream needs it.

## Build cache

Each run of this job gets a fresh `setup_remote_docker` VM and creates a fresh `docker-container` buildx builder, so by default (`cache: off`) **the entire Dockerfile is re-executed from scratch on every build**. The `RUN --mount=type=cache` mounts in your Dockerfile do not help here — they live in the builder's state, which is destroyed with the VM. They only speed up local rebuilds.

`cache: registry` persists BuildKit's layer cache as an OCI artifact in the registry the image is pushed to, so the next build imports it instead of rebuilding:

```yaml
- architect/build-image:
    name: verify-image-amd64
    platform: linux/amd64
    resource_class: small
    cache: registry
    filters:
      branches:
        ignore: main
```

**Recommended: enable it on the branch/PR jobs only, and leave release-tag jobs on `cache: off`.** Branch builds are the frequent ones, so they capture nearly all the time saving, while release artifacts — the ones that get cosign-signed and carry a provenance attestation — are then never assembled from a shared mutable cache. See [Trust model](#trust-model) below.

This pays off most for Dockerfiles that do expensive work in `RUN` steps whose inputs rarely change — `apt-get install`, `pip install`, `npm`/`yarn install`. Order the Dockerfile so those layers sit above anything that changes every commit, or the cache will miss.

### Pin your base image, or the cache goes cold on its own

**A floating base tag defeats this entirely whenever upstream republishes it.** `FROM node:24-trixie-slim` resolves to whatever digest that tag points at today; when the publisher pushes a new one (Debian security updates land in `-slim` tags often — sometimes weekly), the `FROM` layer changes and **every layer beneath it is invalidated**. The build is fully cold, and the next export rewrites the whole cache.

This was observed while validating the feature: two builds of an unchanged `yarn.lock` three days apart, where the second was fully cold purely because `node:24-trixie-slim` had been republished that morning.

If you want consistent hits, pin a full version *and* the digest, and let Renovate move both:

```dockerfile
FROM node:24.19.0-trixie-slim@sha256:0711b541c1c33a8a53...
```

Without a pin, treat the speedup as "fast between base-image republishes" rather than "fast every build", and discount the benefit accordingly when weighing it against the storage and egress cost.

### Prerequisite: untagged-manifest retention

**Enable untagged-manifest retention on the target registry before opting a repo in.** An export whose content differs PUTs a new cache manifest and moves the `:buildcache` tag; the previous manifest becomes untagged rather than deleted, and ACR does not garbage-collect untagged manifests by default. Referenced blobs dedupe, so the growth is the changed-layer delta — and the layers that change are usually the big ones.

**This accrues per content change, not per build.** A fully warm build re-exports byte-identical content, so the manifest digest does not move and no orphan is created — two consecutive warm builds on `giantswarm/backstage` both left the same digest in place. What creates an orphan is a build whose layers actually differ: a base-image bump, a lockfile change, a Dockerfile edit. On a repo with a digest-pinned base and stable dependencies that is a handful per month rather than one per build.

```bash
az acr config retention update --registry gsoci --type UntaggedManifests --days 7 --status enabled
```

(Retention is a Premium feature and is configured per registry; a scheduled purge task works too.) The `:buildcache` tag itself is also permanent — it is not cleaned up if a repo later stops using `cache: registry` or renames its image, so remove it by hand in that case.

### Cache ref derivation

The default ref is `<registry>/<image>:buildcache<tag-suffix>-<platform>`. The platform is appended either way, derived or explicit: these jobs run concurrently, and two exporting to one ref would race, leaving whichever finished last as the only surviving cache manifest. `<registry>` is chosen to be identical for every build of a repo, regardless of build type:

1. Entries whose visibility does not match the image are skipped. Visibility _is_ part of the key, so a private image's layers are never cached in a public registry. (A repo that flips visibility gets a cold cache once and orphans the old ref.)
2. The China mirror (`*.cr.aliyuncs.com`) is skipped **unconditionally** — not gated on `split-china-push` the way the image push is, because that parameter varies by build type. A build cache is a throwaway optimisation artifact; it must never cross the Pacific on the build's critical path.
3. `gsoci.azurecr.io` / `gsociprivate.azurecr.io` are preferred by name, so the ref does not depend on the ordering of `REGISTRIES_DATA_BASE64`. Otherwise the first remaining match wins.

The `push_dev` filter is deliberately _not_ applied. It is the filter that varies between dev/branch and release builds, so keying off the fully filtered eligible-registry list would resolve to different registries per build type — forking the cache in two, leaving release builds unable to reuse what the more frequent branch builds paid to write, and accumulating both refs forever.

If no registry survives, the build proceeds without a cache and logs why.

`cache-ref` overrides the derivation entirely — use it to scope per branch, or to point at a dedicated cache repository. The platform suffix is still appended.

### Trust model

**The layer cache sits inside the trust boundary of every repo that shares the push credentials.** `image-login-to-registries` logs in with shared context credentials, so any CI job in the org that can push images can also write any other image's `:buildcache`. `--cache-from` then imports that content into builds that get cosign-signed and carry `--attest type=provenance`.

The capability is not new — those credentials could already push image tags. What is new is the _stealth_: cache content can change without any tag anyone inspects moving, and the resulting provenance attestation becomes a false statement about how the image was built.

This is why the recommendation above is to keep `cache: off` on release-tag jobs. If you do enable it on a signed release path, treat a poisoned cache as a realistic threat rather than a nuisance, and consider a dedicated `cache-ref` in a repository with narrower write access.

### Other notes and limits

- **Requires `push: true`.** The cache export reuses the registry credentials the push path sets up; with `push: false` the parameter is ignored and the build logs why.
- **Cache mounts are not exported.** Only layers are. A layer cache _hit_ skips the `RUN` entirely, so its `--mount=type=cache` is irrelevant. A _miss_ re-runs the step against a cold mount — so a lockfile bump costs full price, as before.
- **The exporter always runs `mode=max`**, so intermediate layers are exported too. That is not configurable: BuildKit's default `min` exports only layers present in the final image, i.e. precisely not the expensive intermediate `RUN` steps this exists for.
- **Export failures never fail the build**, but they are reported. `--cache-to` carries `ignore-error=true`, because the image is already pushed by the time the cache is written and the job's retry loop must not rebuild four times over a cache-write problem. Since that would otherwise make a permanently broken cache invisible — and the exporter retries with escalating backoff, so it costs time as well — the job greps the build output for a failed export and emits a loud non-fatal `WARNING`.
- **Concurrent builds race on the tag.** Last write wins. That is usually just a later cache miss, but it is not always benign: a build whose Dockerfile dropped a stage replaces the richer cache wholesale and orphans the loser's blobs.
- **Egress is not free.** Warm builds pull cache blobs from the registry that previously were produced locally. The wall-clock win on `giantswarm/backstage` was large (see below), but if you are opting in many repos, account for standing storage plus per-build egress, not just CI minutes.
- ACR (`gsoci`/`gsociprivate`) rejects the exporter's default manifest-list format, so the cache is pushed with `image-manifest=true,oci-mediatypes=true`.

### Measured effect

On `giantswarm/backstage` (single-arch amd64, Node monorepo with `apt` + `pip` + `yarn workspaces focus` in the Dockerfile): the image build went from ~5m32s uncached to **~2m05s** warm (2m03s and 2m08s on two runs), with a 554 MB cache artifact. Repos whose Dockerfile is a single `COPY` of a prebuilt binary have nothing to gain and should stay on `cache: off`.

## Dockerfile requirements

The Dockerfile must select the right binary per platform. Two patterns work; pick whichever fits:

### Prebuilt-binary (recommended for Go services)

`go-build` produces `myapp-linux-amd64` and `myapp-linux-arm64` in the workspace; the Dockerfile selects on `TARGETARCH`:

```dockerfile
FROM gcr.io/distroless/static:nonroot
ARG TARGETARCH
WORKDIR /
COPY myapp-linux-${TARGETARCH} myapp
USER 65532:65532
ENTRYPOINT ["/myapp"]
```

No `RUN` on the target architecture, no QEMU emulation, fast.

### Compile-in-Dockerfile

For projects whose build doesn't lend itself to upstream cross-compilation (or that prefer a self-contained Dockerfile):

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.22 AS builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /out/myapp .

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /out/myapp /myapp
ENTRYPOINT ["/myapp"]
```

The `--platform=$BUILDPLATFORM` on the builder pins it to the host arch so `RUN go build` cross-compiles natively rather than running under QEMU.

### What does NOT work

A Dockerfile that does `COPY myapp myapp` (a single binary file with no per-arch selection) will produce broken arm64 images — both manifests will contain the same (likely amd64) binary. Always use `${TARGETARCH}` (or a `--platform=$BUILDPLATFORM` builder stage that emits per-arch output).

## OCI image labels

Emitted by default and configurable via `oci-labels: true|false`:

- `org.opencontainers.image.source` — `https://github.com/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}`
- `org.opencontainers.image.revision` — `${CIRCLE_SHA1}`
- `org.opencontainers.image.version` — the tag from `gitsemver get`
- `org.opencontainers.image.created` — commit timestamp (RFC 3339, deterministic per commit)

Labels are image-config level, so they survive the merge untouched. The matching index annotations are re-applied by [`push-to-registries`](push-to-registries.md#oci-index-annotations).

## Hadolint

`hadolint: warn|fail|skip` (default `warn`) lints the Dockerfile before
the buildx build using the hadolint binary baked into the architect image.

- `warn` — print findings, never fail the job.
- `fail` — fail the job on any finding.
- `skip` — don't run hadolint at all.

`hadolint-config` is an optional path to a `.hadolint.yaml` configuration
file relative to the workspace; defaults to hadolint's built-in rules.

The lint is a property of the source, not the architecture, so it runs in every
architecture's job. It costs about a second and fails before minutes of building
past a broken Dockerfile.

## Things that bite

**`split-china-push` must match** the value on `push-to-registries`, or the two
disagree about which registries hold the per-architecture digests.

**`persist-build-version` belongs on exactly one job per path.** These jobs run
concurrently, and CircleCI refuses to attach a workspace that two concurrent jobs
persisted the same path into, so it defaults to `false`. On the release path
`push-to-registries` already writes `.build_version`. On a branch path with no
`push-to-registries` job, set it on one `build-image` job if a chart job
downstream needs the version — otherwise `package-helm-with-abs` falls back to
bare `gitsemver get`, which does not apply `tag-suffix`.

**The platform list lives in the workflow, not in `.platforms`.** `go-build` still
writes that file, but nothing derives the image platforms from it any more: the
set is the list of `build-image` jobs, and the `platforms` parameter of
`push-to-registries` must agree with it. A mismatch fails the merge loudly rather
than publishing a partial index.
