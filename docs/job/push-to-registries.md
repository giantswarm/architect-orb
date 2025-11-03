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

If you're not happy with default values, you will have to pass the argumet `registries-data`, that should look like that
```yaml
registries-data: |-
  private gsociprivate.azurecr.io ACR_GSOCIPRIVATE_USERNAME ACR_GSOCIPRIVATE_PASSWORD false
  public gsoci.azurecr.io ACR_GSOCI_USERNAME ACR_GSOCI_PASSWORD false
```

Every line will be split to 5 variables by the whitespace, where

1. Visibility of the image "private" "public" "private/public"
2. A Registry URL
3. An environment variable to get the username from
4. An environment variable to get the password from
5. Push dev image or not, if `true` dev images are going to be pushed to registry

The job distinguishes between release and dev builds. Builds for commits in a branch (other than the default branch) are considered **dev** builds, all others are **release** builds.

By default, images from dev builds are only pushed to `gsoci`, but not to Aliyun.

## Private vs Public images, how does the job handle it?

By default, the job is trying to detect whether the repo with the source code is public or private (it only works with github), and if private, it's checking if the target registry is configured for storing private images.
The list of private registries is set as a parameter in the `image-push-to-registry` job. If a registry is not "private-friendly" and the source is not public, the job will exit after the check.

If it's required to push an image that uses a private code to public registries, one can set the parameter `force-public` to true, then the whole check will be skipped and the image will be pushed to any registry.
