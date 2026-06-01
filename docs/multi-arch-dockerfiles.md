# Multi-arch Dockerfiles: avoiding QEMU emulation

Starting with architect-orb **v9.0**, `push-to-registries` is always a
multi-arch buildx build. Before each build the job registers QEMU/binfmt
handlers (`tonistiigi/binfmt --install all`), so any Dockerfile will
produce a working multi-arch image — but Dockerfiles that don't follow
one of the patterns below execute their `RUN` steps under emulation,
which is **5–20× slower** than native.

This document covers how to identify which pattern your Dockerfile uses
today and how to migrate to a non-emulated build.

## When does emulation kick in?

QEMU runs when both of these are true:

1. The build emits a manifest for an architecture **different from the
   build host** (the architect executor is `linux/amd64`, so this means
   `linux/arm64` today).
2. A `RUN` (or other build-time exec) instruction runs in a stage whose
   effective platform is the target arch.

A `RUN` step is emulated iff the stage's platform is not the host's. Two
ways to keep `RUN` on the host:

- Don't use `RUN` at all (just `COPY` the prebuilt binary).
- Pin the stage doing the `RUN` to the build platform with
  `FROM --platform=$BUILDPLATFORM …` and cross-compile from there.

`COPY` itself never emulates regardless of platform.

## Pattern A — pre-built binary + `TARGETARCH` selection (recommended)

The canonical architect-orb pattern. `go-build` produces one binary per
target arch (`myapp-linux-amd64`, `myapp-linux-arm64`); the Dockerfile
picks the right one based on `TARGETARCH`. No `RUN` runs under emulation.

```dockerfile
FROM gcr.io/distroless/static:nonroot
ARG TARGETARCH
COPY myapp-linux-${TARGETARCH} /myapp
USER 65532:65532
ENTRYPOINT ["/myapp"]
```


CircleCI side:

```yaml
- architect/go-build:
    binary: myapp
- architect/push-to-registries:
    requires: [architect/go-build]
    image: giantswarm/myapp
```

`go-build`'s `architectures` defaults to `linux/amd64,linux/arm64`; the
job writes `.platforms` to the workspace and `push-to-registries`
auto-derives `--platform` from it.

## Pattern B — cross-compile inside the Dockerfile with `$BUILDPLATFORM`

Use this when the binary is *not* pre-built outside Docker (e.g. you build
inside the image from sources). The build stage is pinned to the host
platform; the Go toolchain cross-compiles via `GOOS`/`GOARCH`. No
emulation.

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -o /out/myapp ./cmd/myapp

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/myapp /myapp
ENTRYPOINT ["/myapp"]
```

This works for any cross-compilable toolchain (Go, Rust with the right
target, Zig). For languages without good cross-compile support
(CGO-heavy code, Python with native wheels), fall back to Pattern A.

## Pattern C — naive Dockerfile (emulated, slow)

```dockerfile
FROM alpine
RUN apk add --no-cache ca-certificates curl
COPY myapp /myapp
ENTRYPOINT ["/myapp"]
```

The `RUN apk add` runs under QEMU for `linux/arm64`. It works (this is
what the binfmt registration enables), but a single `apk add` can take
30–60 seconds emulated vs. 2–3 seconds native. Migrate to Pattern A or B
if the build appears on the CI critical path.

Also: this pattern silently breaks if `COPY myapp /myapp` is a single
binary file — both arm64 and amd64 manifests will contain the same
binary. Always use `${TARGETARCH}` selection (Pattern A) or a
`$BUILDPLATFORM` builder (Pattern B).

## Migrating C → A

1. Move every `RUN` out of the final image. If you need `ca-certificates`,
   pull it from a distroless or static base image that already includes
   it (`gcr.io/distroless/static-debian12`, `cgr.dev/chainguard/static`).
2. Build the binary outside Docker via `architect/go-build` (the default
   `architectures` is already `linux/amd64,linux/arm64`).
3. Replace the final stage with `FROM gcr.io/distroless/static` + a single
   `COPY` of the binary selected by `TARGETARCH` (Pattern A above).

For non-Go projects, the same shape applies: produce arch-specific
artifacts in a prior CI job, then `COPY --from=…` based on `TARGETARCH`.

## Verifying your Dockerfile is not emulated

Locally:

```bash
docker buildx create --use --name check-multiarch --driver docker-container
docker run --privileged --rm tonistiigi/binfmt --install all
time docker buildx build --platform linux/amd64,linux/arm64 -t test:multi .
```

Watch the output: any `RUN` line tagged with `[linux/arm64]` that takes
significantly longer than its `[linux/amd64]` counterpart is being
emulated.

A faster signal: temporarily add `RUN uname -m` to the suspect stage. If
it prints `aarch64` while you're on an x86_64 host, that stage is
emulated.

## See also

- [`push-to-registries`](./job/push-to-registries.md) — Dockerfile contract.
- [Cosign signing](./cosign-signing.md) — supply-chain defaults in v9.
- [Migrating from architect-orb v8.x to v9](./migration-v8-to-v9.md).
