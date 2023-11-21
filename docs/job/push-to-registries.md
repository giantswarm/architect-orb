# push-to-registries

This job builds a docker image and pushes it to a set of registries configured within the job itself.
This way this job centralizes the management over image uploads and build process.
It uses the `dockerfile` at the root of the workspace directory and the root directory as 
build context by default.
Otherwise, it is possible to specify the Dockerfile and build context to use with `dockerfile` and `build-context` arguments respectively.

**NOTE**: The docker image will be tagged with the version found by `architect project version` command.

**NOTE:** The registry domain is configured by the job itself. In the `image` argument, please only specify `repository/image`

Argument `tag-suffix` allows to specify a special suffix to be added after the generated container tag.



Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-registries:
          context: "architect"
          name: "push-image-to-registries"
          image: "giantswarm/REPOSITORY"
          tag-suffix: ""
          requires:
            # Make sure binary is built.
            - go-build-REPOSITORY
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
