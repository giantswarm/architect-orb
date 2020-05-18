# push-to-docker

This job builds a docker image and pushes it to a registry.
It requires the build context and Dockefile to be present at the root of worksapce directory.

**NOTE**: docker registry username and password are read from environement variables which default to `ARCHITECT_DOCKER_REGISTRY_USERNAME` and `ARCHITECT_DOCKER_REGISTRY_PASSWORD` respectively. This can be changed via `username_var` and `password_var` arguments.
**NOTE**: The docker image will be tagged with the version found by `architect project version` command.

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-docker:
          name: "push-REPOSITORY-to-quay"
          image: "quay.io/giantswarm/REPOSITORY"
          username_envar: "QUAY_USERNAME"
          password_envar: "QUAY_PASSWORD"
          requires:
            # Make sure binary is built.
            - go-build-REPOSITORY
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```
