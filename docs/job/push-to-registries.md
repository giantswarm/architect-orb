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
          architectures: "linux/amd64,linux/arm64"
      - architect/push-to-registries:
          requires: [architect/go-build]
          image: giantswarm/myapp
```

`go-build` writes a `.platforms` file to the workspace; `push-to-registries` reads it to set `--platform` automatically. No need to repeat the platform list.

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

## Cosign signing

`sign: true` (default) signs the pushed image manifest with cosign keyless OIDC.

- **Public images only.** Private images are skipped at runtime to avoid leaking digests/timestamps into the public Rekor transparency log.
- A fresh CircleCI OIDC token with `aud=sigstore` is minted via `circleci run oidc get` (the auto-injected `CIRCLE_OIDC_TOKEN_V2` has the wrong audience for Fulcio).
- The cert SAN URI is UUID-based but the Sigstore extensions populate the friendly source repo URI in OID `1.3.6.1.4.1.57264.1.12`, so verification policies can pin to `github.com/<org>/<repo>`.

## Migrating from v8.x

In v8.x there were two ways to reach this functionality (`push-to-registries` with `multiarch: true` plus the deprecated `push-to-registries-multiarch` job). Both are gone in v9 — `push-to-registries` always uses buildx now. Consumers of the deprecated job rename to `push-to-registries`; consumers using `multiarch: false` get multi-arch for free. The `multiarch:` parameter is no longer accepted.
