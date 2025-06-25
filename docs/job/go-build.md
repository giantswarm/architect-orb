# go-build

This job builds Go binaries for one or more target architectures and operating systems. It supports both classic single-architecture builds and modern multi-architecture workflows for container images.

**How it works:**
- Runs `go-test` (with optional `pre_test_target` and `test_target`)
- Builds the binary for the specified architecture using the `go-build` command
- If `architecture` is set (e.g., linux/amd64), the binary will be named `<binary>-<GOOS>-<GOARCH>`. If the architecture is linux/amd64, a copy will also be made as `<binary>` for compatibility with legacy workflows.
- All produced binaries are persisted to the workspace (using a wildcard pattern)

## Parameters

- `binary`: Name of the output binary (required).
- `architecture`: Target architecture for Go build (e.g., "linux/amd64", "linux/arm64", or "darwin/amd64"). Defaults to "linux/amd64". If set, will split into GOOS/GOARCH and name the binary accordingly. If linux/amd64, also copies to `<binary>`.
- `os`: **Deprecated.** Use `architecture` instead for multi-arch support.
- `path`: Path to the Go package to build (default: ".").
- `pre_test_target`: Makefile target to run before tests/lints (optional).
- `tags`: Additional Go build tags (optional).
- `test_target`: Makefile target to run for tests (optional).
- `resource_class`: CircleCI resource class for the job.

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
          architecture: "linux/amd64"
```

Dockerfile example:
```dockerfile
FROM gcr.io/distroless/static
COPY myapp /usr/local/bin/myapp
ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Multi-architecture (multiple jobs, different resource_class)

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@x.y.z
workflows:
  build-multiarch:
    jobs:
      - architect/go-build:
          binary: myapp
          architecture: "linux/amd64"
          resource_class: medium
      - architect/go-build:
          binary: myapp
          architecture: "linux/arm64"
          resource_class: arm.medium
      - architect/go-build:
          binary: myapp
          architecture: "darwin/amd64"
          resource_class: macos.xlarge
```

This will run the `go-build` job in parallel for each architecture, and you can specify a different executor or resource_class for each if needed (e.g., to use ARM or macOS runners).

### Multi-architecture (using CircleCI matrix, recommended for push-to-registries-multiarch)

For best results and maintainability, we recommend using a CircleCI matrix to build all required architectures in parallel. This is especially useful when using `push-to-registries-multiarch`, as it ensures all binaries are built and available for the multi-arch image build step.

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
```

This approach is scalable and makes it easy to add or remove architectures. Each job runs in parallel, and you can use the `requires` field in your workflow to ensure all builds complete before running `push-to-registries-multiarch`.

## Migrating from `os` to `architecture`

The `os` parameter is now deprecated. For multi-arch builds, use the `architecture` parameter and run the job multiple times (once per architecture). For single-arch, you can omit `architecture` (defaults to `linux/amd64`).

## Preparing for multi-arch container images

If you plan to use the output binaries in a multi-arch Docker image (see [`push-to-registries-multiarch`](./push-to-registries-multiarch.md)), ensure your Dockerfile uses the `TARGETPLATFORM` build argument to select the correct binary at build time. See the multi-arch Dockerfile example in the `push-to-registries-multiarch` documentation.

- All referenced binaries (e.g., `myapp-linux-amd64`, `myapp-linux-arm64`) must be present in the workspace before the image build step.

## Notes
- Backward compatible: existing single-arch workflows do not need to change.
- For classic single-arch Dockerfiles, use the default or specify a single architecture.
- For true multi-arch images, use this job with multiple architectures and update your Dockerfile accordingly.
