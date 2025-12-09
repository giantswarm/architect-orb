# push-to-registries-multiarch

This job builds and pushes a multi-architecture container image to a set of registries using a single, efficient step. It leverages the `push-to-registries-multiarch` command, which combines building and pushing for all specified platforms and registries.

**Use this job if:**
- You want to publish a single image that supports multiple architectures (e.g., linux/amd64 and linux/arm64).
- Your Dockerfile uses the `TARGETPLATFORM` build argument to select the correct binary for each platform (see below).
- You have already built and persisted binaries for all target architectures in your workspace before the image build step.

If you are using a classic single-arch Dockerfile (with a plain `COPY` of a single binary), use [`push-to-registries`](./push-to-registries.md) instead.

## Example usage

### Recommended: Matrix pattern for multi-arch builds

Use a CircleCI matrix to build all required architectures in parallel, then run the push-to-registries-multiarch job after all builds complete. This is scalable, efficient, and easy to maintain.

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/go-build:
          matrix:
            parameters:
              architecture: ["linux/amd64", "linux/arm64"]
          binary: myapp
      - architect/push-to-registries-multiarch:
          name: push-to-registries-multiarch
          requires:
            - architect/go-build
          image: giantswarm/myapp
          # This is the default, so you can leave it out:
          # platforms: "linux/amd64,linux/arm64"
```

- The matrix runs go-build for each architecture in parallel.
- The push-to-registries-multiarch job waits for all go-build jobs to finish, then builds and pushes the multi-arch image.

### Classic (single-arch) usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/go-build:
          name: go-build
          binary: myapp
      - architect/push-to-registries-multiarch:
          name: push-to-registries-multiarch
          requires:
            - go-build
          image: giantswarm/myapp
```

## Dockerfile requirements for multi-arch

Your Dockerfile must use the `TARGETPLATFORM` build argument to select the correct binary for each architecture. Example:

```dockerfile
FROM alpine AS binary-selector
ARG TARGETPLATFORM
COPY myapp-* /binaries/
RUN case "$TARGETPLATFORM" in \
      "linux/amd64") cp /binaries/myapp-linux-amd64 /bin/myapp ;; \
      "linux/arm64") cp /binaries/myapp-linux-arm64 /bin/myapp ;; \
      *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac

FROM gcr.io/distroless/static
WORKDIR /workspace
COPY --from=binary-selector /bin/myapp /workspace/myapp
EXPOSE 8080
ENTRYPOINT ["/workspace/myapp"]
```

- Adjust binary names, workdir, and EXPOSE as needed for your project.
- All referenced binaries must be present in the workspace before the image build step.

## Parameters
- `image`: Name of the container image (without registry host).
- `build-context`: Build context directory (default: ".").
- `dockerfile`: Path to the Dockerfile (default: "./Dockerfile").
- `force-public`: Skip the repo visibility check and push the image to public registries.
- `tag-latest-branch`: Name of the branch on which the image will be additionally tagged as "latest".
- `tag-suffix`: Suffix to append to image tags (optional).
- `registries-data`: Registry configuration string (see orb docs for format).
- `platforms`: Comma-separated string of platforms to build for (e.g., "linux/amd64,linux/arm64"). Defaults to "linux/amd64".

## Notes
- This job requires Docker Buildx and a compatible executor (the default architect executor supports this).
- The build and push are performed in a single step for all tags and registries, improving efficiency and reducing duplication.
- If your Dockerfile does not use the multi-arch pattern, the build will fail for non-matching architectures.
- For single-arch images, set `platforms: linux/amd64` (the default).
