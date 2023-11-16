# push-to-registries

This job builds a docker image and pushes it to a registry.
It uses the Dockerfile at the root of the workspace directory and the root directory as build context by default.
Otherwise, it is possible to specify the Dockerfile and build context to use with `dockerfile` and `build-context` arguments respectively.

**NOTE**: docker registry username and password are read from environment variables which default to `ARCHITECT_DOCKER_REGISTRY_USERNAME` and `ARCHITECT_DOCKER_REGISTRY_PASSWORD` respectively. This can be changed via `username_var` and `password_var` arguments.
**NOTE**: The docker image will be tagged with the version found by `architect project version` command.

Argument `tag-suffix` allows to specify a special suffix to be added after the generated container tag.

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-docker:
          context: "architect"
          name: "push-REPOSITORY-to-quay"
          image: "quay.io/giantswarm/REPOSITORY"
          username_envar: "QUAY_USERNAME"
          password_envar: "QUAY_PASSWORD"
          build-context: "."
          dockerfile: "./Dockerfile"
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
      - architect/push-to-docker:
          ...
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+)?$/
```
