# push-to-registries

This job builds a container image and pushes it to a set of registries configured within the job itself.
This job is intended for classic single-architecture Dockerfiles, where a single binary is copied into the image (e.g., `COPY myapp /usr/local/bin/myapp`).

It uses the `Dockerfile` found at the root of the workspace directory and the root directory as
build context by default.
Otherwise, it is possible to specify the Dockerfile and build context to use with `dockerfile` and `build-context` arguments respectively.

**NOTE**: The container image will be tagged with the version found by the `architect project version` command.

**NOTE:** The registry domain is configured by the job itself. In the `image` argument, please only specify `repository/image`.

Argument `tag-suffix` allows to specify a special suffix to be added after the generated container tag.

## Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-registries:
          image: myapp
```

You might want to restrict the build of tags even further, by only building tags that are valid semver strings.
You can do it like this:

```yaml
...
workflows:
  my-workflow:
    jobs:
      - architect/push-to-registries:
          ...
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+)?$/
```

## Selecting target registries

If you're not happy with default values, you will have to pass the argument `registries-data`, that should look like that
```yaml
registries-data: |-
  private slow-registry.example.com SLOW_REGISTRY_USERNAME SLOW_REGISTRY_PASSWORD false
  public normal-registry.example.com NORMAL_REGISTRY_USERNAME NORMAL_REGISTRY_PASSWORD false
```

Every line will be split to 5 variables by the whitespace, where

1. Visibility of the image "private" "public" "private/public"
2. A Registry URL
3. An environment variable to get the username from
4. An environment variable to get the password from
5. Push dev image or not, if `true` dev images are going to be pushed to registry

The job distinguishes between release and dev builds. Builds for commits in a branch (other than the default branch) are considered **dev** builds, all others are **release** builds.

By default, images from dev builds are only pushed to normal registries, but not to slow ones.

## Slow registries (async push)

Some registries are significantly slower to push to than others. A slow registry can take up to
30 minutes to accept an image push, which would block every downstream job (e.g. `push-to-app-catalog`)
for the same duration even though those jobs do not depend on the slow registry at all.

To solve this, the job supports **async push** for slow registries. Registries listed in `slow-registries`
are skipped during the main job. Once all normal registries have been pushed to, the job triggers a
separate pipeline in [`giantswarm/slow-registry-pusher`](https://github.com/giantswarm/slow-registry-pusher)
and exits immediately. The slow-registry-pusher pipeline then pulls the image from a normal registry
and pushes it to the slow registries independently.

This means downstream jobs such as `push-to-app-catalog` are unblocked as soon as normal registries are
ready, while slow registries are still guaranteed to receive the image — just with a delay.

### Workflow shape

```
go-build ──► push-to-registries ──► push-to-app-catalog
                    │
                    └──► (triggers) slow-registry-pusher pipeline
                                         └──► push to slow registries (async, independent)
```

### Failure behaviour

- If a **normal registry** push fails, `push-to-registries` fails immediately — downstream jobs are blocked as usual.
- If triggering the slow-registry-pusher pipeline fails (e.g. network error, bad token), `push-to-registries` also fails.
- If a **slow registry** push fails, the `slow-registry-pusher` pipeline is marked as failed in its own CircleCI project. Your repository's workflow is not affected, but the failure is visible in the CircleCI dashboard for `giantswarm/slow-registry-pusher` and will notify via any alerting configured there.

### Requirements

The `architect` CircleCI context must contain a `CIRCLECI_TOKEN` environment variable holding a
CircleCI API token with permission to trigger pipelines in the `giantswarm/slow-registry-pusher` project.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `async-slow-registries` | boolean | `true` | Enable async push for slow registries. Set to `false` to restore original synchronous behaviour. |
| `slow-registries` | string | `""` | Space-separated list of registry hostnames to push asynchronously. Only used when `async-slow-registries` is `true`. If empty, the `SLOW_REGISTRIES` environment variable is used. |

### Opting out

To push all registries synchronously (original behaviour), set `async-slow-registries` to `false`.
No other workflow changes are needed.

```yaml
- architect/push-to-registries:
    context: architect
    async-slow-registries: false
```

This is useful when:
- You are debugging a registry push issue and want to see failures inline.
- The `slow-registry-pusher` infrastructure is unavailable.
- You intentionally need the downstream job to wait until all registries, including slow ones, have the image.

### Customising the slow registries list

The list of slow registries is configured via the `SLOW_REGISTRIES` environment variable (typically
set in the CircleCI `architect` context). Its value is a space-separated list of registry hostnames.

You can override it per-job by setting the `slow-registries` parameter. Any registry listed here must
also be present in `registries-data` (or the default `REGISTRIES_DATA_BASE64` context variable) so
that credentials are available in the slow-registry-pusher pipeline.

```yaml
- architect/push-to-registries:
    context: architect
    slow-registries: "slow-registry.example.com another-slow-registry.example.com"
```

## Private vs Public images, how does the job handle it?

By default, the job is trying to detect whether the repo with the source code is public or private (it only works with github), and if private, it's checking if the target registry is configured for storing private images.
The list of private registries is set as a parameter in the `image-push-to-registry` job. If a registry is not "private-friendly" and the source is not public, the job will exit after the check.

If it's required to push an image that uses a private code to public registries, one can set the parameter `force-public` to true, then the whole check will be skipped and the image will be pushed to any registry.
