# go-build

This job builds Go binaries for one or more target architectures and operating systems. It supports both classic single-architecture builds and modern multi-architecture workflows for container images.

**How it works:**
- Runs `go-test` (with optional `pre_test_target` and `test_target`)
- Builds the binary for one or more architectures using the `go-build` command
- Each binary is named `<binary>-<GOOS>-<GOARCH>`. For `linux/amd64` a copy is also written to `<binary>` for backward compatibility.
- When `architectures` (plural) is set, the resolved list is also written to `.platforms` in the workspace so downstream `push-to-registries` jobs can auto-derive `--platform`.
- All produced binaries (and `.platforms`) are persisted to the workspace.

## Parameters

- `binary`: Name of the output binary (required).
- `architectures`: Comma-separated list of target architectures (e.g., `"linux/amd64,linux/arm64"`). When set, builds all listed targets in this single job and writes the list to `.platforms`. Takes precedence over `architecture`.
- `architecture`: Single target architecture (e.g., `"linux/amd64"`). Default: `linux/amd64`. Kept for callers using a CircleCI matrix.
- `os`: **Deprecated.** Ignored. Use `architectures` instead.
- `path`: Path to the Go package to build (default: `"."`).
- `pre_test_target`: Makefile target to run before tests/lints (optional).
- `tags`: Additional Go build tags (optional).
- `test_target`: Makefile target to run for tests (optional).
- `resource_class`: CircleCI resource class for the job.
- `clone_depth`: Number of commits to keep in the local git history after checkout (default: `1`). Use `0` for full history. Values greater than `1` deepen the history to that many commits. The default of `1` preserves the behaviour of CircleCI's built-in `checkout` step. Set to `0` when build steps rely on `git log` or `git rev-list` to traverse the repo (for example, a `go generate` step that embeds the commit SHA of the last change to a template file).

## Example usage

### Single-architecture (default)

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@x.y.z
workflows:
  build:
    jobs:
      - architect/go-build:
          binary: myapp
```

Dockerfile example:
```dockerfile
FROM gcr.io/distroless/static
COPY myapp /usr/local/bin/myapp
ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Multi-architecture (recommended — single job, `architectures` plural)

Builds all listed architectures in one job and writes `.platforms` to the workspace. Downstream `push-to-registries` (with `multiarch: true`) auto-derives `--platform` from `.platforms`, so no platform list needs to be repeated.

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@x.y.z
workflows:
  build-multiarch:
    jobs:
      - architect/go-build:
          binary: myapp
          architectures: "linux/amd64,linux/arm64"
      - architect/push-to-registries:
          requires: [architect/go-build]
          multiarch: true
```

This is the simplest setup for the common case. Tests run once (not per arch), CircleCI startup overhead is paid once, and the platform list lives in one place.

### Multi-architecture (CircleCI matrix — singular `architecture`)

Useful when you want each architecture to run on a different `resource_class` (for example, `arm.medium` to avoid QEMU when compiling inside the Dockerfile). Pass `platforms` explicitly to `push-to-registries`.

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@x.y.z
workflows:
  build-multiarch:
    jobs:
      - architect/go-build:
          matrix:
            parameters:
              architecture: ["linux/amd64", "linux/arm64"]
          binary: myapp
      - architect/push-to-registries:
          requires: [architect/go-build]
          multiarch: true
          platforms: "linux/amd64,linux/arm64"
```

## Preparing for multi-arch container images

If you plan to use the output binaries in a multi-arch Docker image (see [`push-to-registries`](./push-to-registries.md)), ensure your Dockerfile uses the `TARGETARCH` (or `TARGETPLATFORM`) build argument to select the correct binary at build time:

```dockerfile
FROM gcr.io/distroless/static
ARG TARGETARCH
COPY myapp-linux-${TARGETARCH} /usr/local/bin/myapp
ENTRYPOINT ["/usr/local/bin/myapp"]
```

All referenced binaries (e.g., `myapp-linux-amd64`, `myapp-linux-arm64`) must be present in the workspace before the image build step — `go-build` persists them automatically.

## Notes
- Backward compatible: existing single-arch and matrix-based workflows do not need to change.
- For classic single-arch Dockerfiles, use the default or specify a single `architecture`.
- For true multi-arch images, prefer `architectures` (plural) so the platform list is auto-discovered downstream.
