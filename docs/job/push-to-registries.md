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

## Dockerfile requirements

The Dockerfile must select the right binary per platform. Two patterns work; pick whichever fits:

### Prebuilt-binary (recommended for Go services)

`go-build` produces `myapp-linux-amd64` and `myapp-linux-arm64` in the workspace; the Dockerfile selects on `TARGETARCH`:

> Since v8.2, the job registers QEMU/binfmt handlers before building, so
> a plain Dockerfile (`RUN apk add …`, `RUN go build …`) also produces a
> working multi-arch image — but its `RUN` steps run **emulated and 5–20×
> slower** for non-host architectures. See
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
