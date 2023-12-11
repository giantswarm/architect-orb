# push-to-registries

This job builds a container image and pushes it to a set of registries configured within the job itself.
This way this job centralizes the management over image uploads and build process.
It uses the `Dockerfile` found at the root of the workspace directory and the root directory as
build context by default.
Otherwise, it is possible to specify the Dockerfile and build context to use with `dockerfile` and `build-context` arguments respectively.

**NOTE**: The container image will be tagged with the version found by the `architect project version` command.

**NOTE:** The registry domain is configured by the job itself. In the `image` argument, please only specify `repository/image`.

Argument `tag-suffix` allows to specify a special suffix to be added after the generated container tag.

Example usage:

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-registries:
          context: architect
          name: push-to-registries
          requires:
            # Make sure binary is built.
            - go-build
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
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

The default configuration enables pushing to all registries we care about. Sticking with the defaults is recommended here. However, if you want to override pushing to any of the target registries, you have the following config parameters available:

- `push-to-gsoci` (boolean): Whether or not to push to `gsoci.azurecr.io`
- `push-to-quay` (boolean): Whether or not to push to `quay.io`
- `push-to-aliyun` (boolean): Whether or not to push to Aliyun (for AWS China)
- `push-to-docker` (boolean): Whether or not to push to `docker.io`

## Pushing dev vs. release images

The job distinguishes between release and dev builds. Builds for commits in a branch (other than the default branch) are considered **dev** builds, all others are **release** builds.

By default, images from dev builds are only pushed to `gsoci` and `quay.io`, but not to Aliyun and `docker.io`.

- `push-dev-to-gsoci` (boolean): Whether or not to push to `gsoci.azurecr.io`. Also requires `push-to-gsoci` to be true.
- `push-dev-to-quay` (boolean): Whether or not to push to `quay.io`. Also requires `push-to-quay` to be true.
- `push-dev-to-aliyun` (boolean): Whether or not to push to Aliyun (for AWS China). Also requires `push-to-aliyun` to be true.
- `push-dev-to-docker` (boolean): Whether or not to push to `docker.io`. Also requires `push-to-docker` to be true.

## Private vs Public images, how does the job handle it?

By default, the job is trying to detect whether the repo with the source code is public or private (it only works with github), and if private, it's checking if the target registry is configured for storing private images.
The list of private registries is set as a parameter in the `image-push-to-registry` job. If a registry is not "private-friendly" and the source is not public, the job will exit after the check.

If it's required to push an image that uses a private code to public registries, one can set the parameter `force-public` to true, then the whole check will be skipped and the image will be pushed to any registry.
