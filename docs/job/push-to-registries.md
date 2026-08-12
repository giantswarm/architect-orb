# push-to-registries

Builds a multi-architecture container image with `docker buildx` and pushes it to the configured registries.

By default it uses the `Dockerfile` at the workspace root and the root directory as the build context; pass `dockerfile` and `build-context` to override.

The image is tagged with the version produced by `gitsemver get`. The registry hosts come from `registries-data` (or the `REGISTRIES_DATA_BASE64` environment variable) — `image` should only be `repository/image`, no host.

`tag-suffix` adds a suffix to the generated tag.

## Example usage

### Defaults (multi-arch, signed, attested)

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION
workflows:
  build:
    jobs:
      - architect/go-build:
          binary: myapp
      - architect/push-to-registries:
          requires: [architect/go-build]
          image: giantswarm/myapp
```

`go-build` defaults to `linux/amd64,linux/arm64` and writes a `.platforms` file to the workspace; `push-to-registries` reads it to set `--platform` automatically. No need to repeat the platform list.

By default this also emits SLSA provenance, an SPDX SBOM, OCI labels, and — on public images — a cosign keyless signature on the image *and* on its SPDX SBOM attestation. Each is individually controllable: `provenance: min|max|false`, `sbom: true|false`, `oci-labels: true|false`, `sign: true|false`. Set `sbom-cyclonedx: true` to add a (signed, on public) CycloneDX SBOM.

### Restricting to release tags

```yaml
- architect/push-to-registries:
    filters:
      tags:
        only: /^v[0-9]+\.[0-9]+\.[0-9]+$/
      branches:
        ignore: /.*/
```

### Build-only validation on branches (`push: false`)

Validates that the image builds for every target platform without pushing anything: same hadolint lint, same multi-arch buildx build (QEMU emulation, `.platforms` auto-derivation, workspace attach for CI-built binaries), but the result stays in the BuildKit cache. No registry credentials are used; signing, provenance, and SBOM generation are skipped — those only make sense on a published image. Useful on the branch/PR path of workflows that push images only on release tags, so Dockerfile regressions surface on the PR instead of at tag time:

```yaml
# Branches: validate the image build, push nothing.
- architect/push-to-registries:
    name: build-image
    push: false
    requires: [go-build]
    filters:
      branches:
        ignore: main

# Tags: build and push for real.
- architect/push-to-registries:
    name: push-to-registries-release
    requires: [go-build]
    filters:
      tags:
        only: /^v.*/
      branches:
        ignore: /.*/
```

### Custom OCI manifest annotations

```yaml
- architect/push-to-registries:
    requires: [architect/go-build]
    image: giantswarm/myapp
    annotations: |
      manifest:io.giantswarm.klaus.type=toolchain
      manifest:io.giantswarm.klaus.name=myapp
```

## Platform resolution order

When the job runs, `--platform` is resolved in this order:

1. Explicit `platforms:` parameter (if non-empty).
2. `.platforms` file in the workspace (written by `go-build`).
3. Built-in default `linux/amd64,linux/arm64`.

QEMU/binfmt handlers are registered only when at least one resolved platform differs from the build host. A single-platform build matching the host (`platforms: linux/amd64`) skips the privileged `tonistiigi/binfmt` pull entirely — nothing can be emulated, so it bought nothing. See [Multi-arch Dockerfiles](../multi-arch-dockerfiles.md).

## Building on Arm

`resource_class` accepts CircleCI's Arm classes (`arm.medium`, `arm.large`, `arm.xlarge`, `arm.2xlarge`) as well as the x86 ones. The class applies to the `setup_remote_docker` VM as well as the job container — CircleCI matches the remote Docker environment's architecture to the primary container's. The architect image is multi-arch, so no separate executor is needed. There is no `arm.small`; `arm.medium` is the smallest.

```yaml
- architect/push-to-registries:
    platforms: linux/arm64
    resource_class: arm.medium
```

That combination makes the host match the target, so the binfmt registration above is skipped and no `RUN` step is emulated.

## Build cache

Each run of this job gets a fresh `setup_remote_docker` VM and creates a fresh `docker-container` buildx builder, so by default (`cache: off`) **the entire Dockerfile is re-executed from scratch on every build**. The `RUN --mount=type=cache` mounts in your Dockerfile do not help here — they live in the builder's state, which is destroyed with the VM. They only speed up local rebuilds.

`cache: registry` persists BuildKit's layer cache as an OCI artifact in the registry the image is pushed to, so the next build imports it instead of rebuilding:

```yaml
- architect/push-to-registries:
    name: push-to-registries # branch builds
    image: giantswarm/myapp
    dockerfile: packages/backend/Dockerfile
    platforms: linux/amd64
    cache: registry
    filters:
      branches:
        ignore: main
```

**Recommended: enable it on the branch/PR job only, and leave release-tag jobs on `cache: off`.** Branch builds are the frequent ones, so they capture nearly all the time saving, while release artifacts — the ones that get cosign-signed and carry a provenance attestation — are then never assembled from a shared mutable cache. See [Trust model](#trust-model) below.

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

The default ref is `<registry>/<image>:buildcache<tag-suffix>`. `<registry>` is chosen to be identical for every build of a repo, regardless of build type:

1. Entries whose visibility does not match the image are skipped. Visibility _is_ part of the key, so a private image's layers are never cached in a public registry. (A repo that flips visibility gets a cold cache once and orphans the old ref.)
2. The China mirror (`*.cr.aliyuncs.com`) is skipped **unconditionally** — not gated on `split-china-push` the way the image push is, because that parameter varies by build type. A build cache is a throwaway optimisation artifact; it must never cross the Pacific on the build's critical path.
3. `gsoci.azurecr.io` / `gsociprivate.azurecr.io` are preferred by name, so the ref does not depend on the ordering of `REGISTRIES_DATA_BASE64`. Otherwise the first remaining match wins.

The `push_dev` filter is deliberately _not_ applied. It is the filter that varies between dev/branch and release builds, so keying off the fully filtered eligible-registry list would resolve to different registries per build type — forking the cache in two, leaving release builds unable to reuse what the more frequent branch builds paid to write, and accumulating both refs forever.

If no registry survives, the build proceeds without a cache and logs why.

`cache-ref` overrides the derivation entirely — use it to scope per branch, or to point at a dedicated cache repository.

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

On `giantswarm/backstage` (single-arch amd64, Node monorepo with `apt` + `pip` + `yarn workspaces focus` in the Dockerfile): `push-to-registries` went from ~5m32s uncached to **~2m05s** warm (2m03s and 2m08s on two runs), with a 554 MB cache artifact. Repos whose Dockerfile is a single `COPY` of a prebuilt binary have nothing to gain and should stay on `cache: off`.

## Dockerfile requirements

The Dockerfile must select the right binary per platform. Two patterns work; pick whichever fits:

### Prebuilt-binary (recommended for Go services)

`go-build` produces `myapp-linux-amd64` and `myapp-linux-arm64` in the workspace; the Dockerfile selects on `TARGETARCH`:

> For a cross-architecture build the job registers QEMU/binfmt handlers
> beforehand, so a plain Dockerfile (`RUN apk add …`, `RUN go build …`) also
> produces a working multi-arch image — but its `RUN` steps run **emulated
> and 5–20× slower** for non-host architectures. See
> [Multi-arch Dockerfiles: avoiding QEMU emulation](../multi-arch-dockerfiles.md)
> for the three Dockerfile patterns and how to migrate.

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

## Selecting target registries

`registries-data` is space-separated, one registry per line:

```yaml
registries-data: |-
  private gsociprivate.azurecr.io ACR_GSOCIPRIVATE_USERNAME ACR_GSOCIPRIVATE_PASSWORD false
  public gsoci.azurecr.io ACR_GSOCI_USERNAME ACR_GSOCI_PASSWORD false
```

Fields:

1. Visibility — `public`, `private`, or `public/private`
2. Registry URL
3. Username env var name
4. Password env var name
5. Push dev images — `true` pushes branch builds, `false` skips them (release builds only)

Branch builds are "dev"; tag builds are "release". By default dev images go to `gsoci` only, not to Aliyun.

## Private vs public images

The job calls the GitHub API to detect whether the source repository is private. Private source → push only to registries with `private` visibility. Public source → push to `public` or `public/private` registries.

`force-public: true` skips the check and treats the image as public regardless.

## OCI image labels

Emitted by default and configurable via `oci-labels: true|false`:

- `org.opencontainers.image.source` — `https://github.com/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}`
- `org.opencontainers.image.revision` — `${CIRCLE_SHA1}`
- `org.opencontainers.image.version` — the tag from `gitsemver get`
- `org.opencontainers.image.created` — commit timestamp (RFC 3339, deterministic per commit)

In multi-arch mode the same values are also emitted as OCI manifest index annotations.

## Hadolint

`hadolint: warn|fail|skip` (default `warn`) lints the Dockerfile before
the buildx build using the hadolint binary baked into the architect image.

- `warn` — print findings, never fail the job.
- `fail` — fail the job on any finding.
- `skip` — don't run hadolint at all.

`hadolint-config` is an optional path to a `.hadolint.yaml` configuration
file relative to the workspace; defaults to hadolint's built-in rules.

## Cosign signing

`sign: true` (default) signs the pushed image manifest with cosign keyless
OIDC. On public images it **also signs the SBOM attestations** (SPDX, and
CycloneDX when `sbom-cyclonedx: true`) so consumers can cryptographically
verify their origin. Public images only — private images are skipped at
runtime.

See [Cosign signing](../cosign-signing.md) for the verification commands
(including `cosign verify-attestation` for SBOMs), the identity model
(CircleCI's UUID-based SAN URI + the friendly source-repo OID), and
verify-after-sign behavior.

## SBOMs (SPDX + CycloneDX) and signing

`sbom: true` (default) makes buildx attach an **SPDX** SBOM per platform
inline in the image index. On **public** images with `sign: true`, the exact
SPDX predicate buildx produced is additionally signed as a cosign keyless
attestation (`--type spdxjson`) — verifiable independently of the registry.

BuildKit's SBOM attestation only emits SPDX. For a **CycloneDX** SBOM too,
set `sbom-cyclonedx: true`:

```yaml
      - architect/push-to-registries:
          image: giantswarm/myapp
          sbom-cyclonedx: true
```

When enabled, the job generates a CycloneDX SBOM **per architecture** with
[syft](https://github.com/anchore/syft). Where it lands depends on visibility:

- **Public images with `sign: true`** — signed as a cosign keyless
  attestation (`--type cyclonedx`), a verifiable OCI referrer. This is the
  trustable, tamper-evident proof of image contents.
- **Private images, or `sign: false`** — attached **unsigned** as an OCI 1.1
  referrer (artifactType `application/vnd.cyclonedx+json`) using
  [oras](https://oras.land), since signing private artifacts would leak their
  digests/timestamps into the public Rekor transparency log.

Both require `syft` and `oras` in the architect image. `sbom-cyclonedx`
defaults to off, so existing consumers are unaffected.

### Verifying / inspecting SBOMs as a consumer

Signed attestations are verified **per platform** with cosign — see
[Cosign signing → SBOM attestations](../cosign-signing.md#sbom-attestations-spdx--cyclonedx).

Unsigned CycloneDX referrers (private images) are listed/pulled via the
referrers API:

```sh
# Resolve a platform digest, then list its referrers
oras discover --artifact-type application/vnd.cyclonedx+json \
  <registry>/giantswarm/myapp@<platform-digest>

# Pull the SBOM blob
oras pull <registry>/giantswarm/myapp@<sbom-referrer-digest>
```

## Migrating from v8.x

See [Migrating from architect-orb v8.x to v9](../migration-v8-to-v9.md).
