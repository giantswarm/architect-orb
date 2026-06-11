# build-image

Validates that the container image builds for every target platform — **without pushing anything**. This is the branch/PR counterpart of [`push-to-registries`](push-to-registries.md): same hadolint lint, same multi-arch `docker buildx` build (QEMU for foreign architectures), but the result stays in the BuildKit cache. No registry credentials are used, nothing is signed, no SBOMs are produced.

Use it on the branch path of a workflow whose `push-to-registries` is restricted to release tags, so Dockerfile regressions surface on the PR instead of at tag time.

By default it uses the `Dockerfile` at the workspace root and the root directory as the build context; pass `dockerfile` and `build-context` to override.

## Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION
workflows:
  build:
    jobs:
      - architect/go-build:
          name: go-build
          binary: myapp

      # Branches: validate the image build, push nothing.
      - architect/build-image:
          requires: [go-build]
          filters:
            branches:
              ignore: main

      # Tags: build and push for real.
      - architect/push-to-registries:
          requires: [go-build]
          filters:
            tags:
              only: /^v.*/
            branches:
              ignore: /.*/
```

`go-build` writes a `.platforms` file to the workspace; `build-image` reads it to set `--platform` automatically, exactly like `push-to-registries`. The workspace is attached, so Dockerfiles that `COPY` the CI-built binaries keep working.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `image` | `giantswarm/${CIRCLE_PROJECT_REPONAME}` | Name used for the (discarded) local image tag. |
| `build-context` | `.` | Build context directory. |
| `dockerfile` | `./Dockerfile` | Dockerfile path. |
| `platforms` | `""` | Comma-separated platform list; auto-derived from `.platforms` when empty. |
| `hadolint` | `warn` | Dockerfile linting: `warn`, `fail`, or `skip`. |
| `hadolint-config` | `""` | Optional `.hadolint.yaml` path. |
| `resource_class` | `small` | CircleCI resource class. |

## What it does NOT do

- No push — multi-platform images cannot even be `--load`ed into the docker image store; the build result intentionally stays in the BuildKit cache.
- No image tag versioning (`gitsemver` is not consulted; the local tag is the commit SHA and is discarded).
- No cosign signing, no provenance, no SBOM — those only make sense on a published image and belong to `push-to-registries`.
