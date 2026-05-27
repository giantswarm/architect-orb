# go-build

Builds Go binaries for one or more target architectures in a single job and persists them to the workspace.

**How it works:**
- Runs `go-test` (with optional `pre_test_target` and `test_target`).
- Loops over each entry in `architectures` and runs `go build` cross-compiled for that GOOS/GOARCH.
- Each binary is named `<binary>-<GOOS>-<GOARCH>`. For `linux/amd64` (when included), a copy is also written to `<binary>` for backward compatibility.
- The resolved architecture list is written to `.platforms` in the workspace so `push-to-registries` can auto-derive `--platform`.

## Parameters

- `binary`: Name of the output binary (required).
- `architectures`: Comma-separated list of target architectures (e.g., `"linux/amd64,linux/arm64"`). Default: `"linux/amd64,linux/arm64"`.
- `path`: Path to the Go package to build (default: `"."`).
- `pre_test_target`: Makefile target to run before tests/lints (optional).
- `tags`: Additional Go build tags (optional).
- `test_target`: Makefile target to run for tests (optional).
- `resource_class`: CircleCI resource class for the job.
- `clone_depth`: Commits to keep in local git history after checkout (default: `1`, i.e. CircleCI's default shallow clone). Use `0` for full history. Greater than `1` deepens to that many commits. Set to `0` when build steps rely on `git log` / `git rev-list` (e.g. `go generate` embedding the commit SHA of the last change to a template).
- `sign`: Sign each produced binary with cosign keyless OIDC (default: `true`). Public repos only — private repos are skipped at runtime. See [Signing](#signing).

## Example usage

### Multi-arch (default)

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@x.y.z
workflows:
  build:
    jobs:
      - architect/go-build:
          binary: myapp
      - architect/push-to-registries:
          requires: [architect/go-build]
```

`architectures` defaults to `linux/amd64,linux/arm64`, so the default invocation builds both binaries in a single job. Tests run once (not per arch), CircleCI startup overhead is paid once, and `push-to-registries` auto-derives `--platform` from the `.platforms` file written to the workspace.

### Restricting to a single architecture

Set `architectures` explicitly when you only need one target:

```yaml
- architect/go-build:
    binary: myapp
    architectures: "linux/amd64"
```

Dockerfile (any arch list):
```dockerfile
FROM gcr.io/distroless/static:nonroot
ARG TARGETARCH
COPY myapp-linux-${TARGETARCH} /myapp
ENTRYPOINT ["/myapp"]
```

## Dockerfile contract

`go-build` writes binaries named `<binary>-<GOOS>-<GOARCH>` (e.g. `myapp-linux-amd64`, `myapp-linux-arm64`) to the workspace. The Dockerfile that ships those binaries must select on `TARGETARCH`:

```dockerfile
FROM gcr.io/distroless/static:nonroot
ARG TARGETARCH
COPY myapp-linux-${TARGETARCH} /myapp
ENTRYPOINT ["/myapp"]
```

A Dockerfile that does `COPY myapp myapp` (no per-arch selector) will silently ship the same binary for both architectures and the arm64 variant will crash with `exec format error` on arm64 hosts.

See [`push-to-registries`](./push-to-registries.md) for the full Dockerfile contract, including the compile-in-Dockerfile pattern (`--platform=$BUILDPLATFORM` builder).

## Signing

`sign: true` (default) signs each `<binary>-<GOOS>-<GOARCH>` with cosign
keyless OIDC and writes a sibling `<binary>-<GOOS>-<GOARCH>.bundle`
Sigstore bundle. The bundle is verified immediately with
`cosign verify-blob` before the job exits. Bundles are persisted alongside
the binaries via the existing workspace glob.

Skipped at runtime when the source repo is private — signing would
publish digest + timestamp metadata to the public Rekor transparency log.

To upload signed binaries (and their `.bundle` siblings) to a GitHub
Release, follow `go-build` with the `upload-release-assets` job.

See [Cosign signing](../cosign-signing.md) for the verification command
and the end-to-end identity model.
