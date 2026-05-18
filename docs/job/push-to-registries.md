# push-to-registries

Builds a multi-architecture container image with `docker buildx` and pushes it to the configured registries.

By default it uses the `Dockerfile` at the workspace root and the root directory as the build context; pass `dockerfile` and `build-context` to override.

The image is tagged with the version produced by `architect project version`. The registry hosts come from `registries-data` (or the `REGISTRIES_DATA_BASE64` environment variable) — `image` should only be `repository/image`, no host.

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

By default this also emits SLSA provenance, an SPDX SBOM, OCI labels, and a cosign keyless signature on public images. Each is individually controllable: `provenance: min|max|false`, `sbom: true|false`, `oci-labels: true|false`, `sign: true|false`.

### Restricting to release tags

```yaml
- architect/push-to-registries:
    filters:
      tags:
        only: /^v[0-9]+\.[0-9]+\.[0-9]+$/
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

```dockerfile
FROM gcr.io/distroless/static:nonroot
ARG TARGETARCH
WORKDIR /
ADD myapp-linux-${TARGETARCH} myapp
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

A Dockerfile that does `ADD myapp myapp` (a single binary file with no per-arch selection) will produce broken arm64 images — both manifests will contain the same (likely amd64) binary. Always use `${TARGETARCH}` (or a `--platform=$BUILDPLATFORM` builder stage that emits per-arch output).

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
- `org.opencontainers.image.version` — the tag from `architect project version`
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
OIDC. Public images only — private images are skipped at runtime.

See [Cosign signing](../cosign-signing.md) for the verification command,
identity model (CircleCI's UUID-based SAN URI + the friendly source-repo
OID), and verify-after-sign behavior.

## Migrating from v8.x

See [Migrating from architect-orb v8.x to v9](../migration-v8-to-v9.md).
