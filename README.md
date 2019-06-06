[![CircleCI](https://circleci.com/gh/giantswarm/architect-orb.svg?style=shield)](https://circleci.com/gh/giantswarm/architect-orb) [![CircleCI Orb Version](https://img.shields.io/badge/endpoint.svg?url=https://badges.circleci.io/orb/giantswarm/architect)](https://circleci.com/orbs/registry/orb/giantswarm/architect)

# architect-orb

This repository hosts the source code for giantswarm/architect orb.

Design and goals of the project:

- Replacing [architect][architect] **is not** a goal.
- Being explicit. Desire to do actual job. E.g. building a docker image and pushing it to a registry should be explicitly specified in the build.
- Making builds understandable without looking into [architect][architect] codebase.
- Having one line binary call on each job step - to make the outputs grouped and visible and keeping build configurations sane. Good example is [package-and-push command][https://github.com/giantswarm/architect-orb/blob/master/src/commands/package-and-push.yaml].
- Using [architect executor][architect-executor] most of time with the latest [architect][architect] docker image.
- Using binaries other than architect when appropriate (they should be available inside [architect executor][architect-executor] most of the time). E.g. `docker`, `git`, `helm`, etc. Instead of wrapping existing well known functionality in [architect][architect] binary.
- Using [architect][architect] commands for complex tasks. Good example is `architect helm template` instead of awkward and error prone `sed` calls.

## Jobs

### push-to-app-catalog

This job templates and packages a given `chart` from the helm directory and pushes it to `app_catalog` for tagged builds and `app_catalog_test` otherwise.

**NOTE**: It requires `CATALOGBOT_SSH_KEY_PRIVATE_BASE64` environment variable to be set in the build. This must be base64 encoded private SSH key of [CatalogBot github user](https://github.com/catalogbot).

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-app-catalog:
          name: "build and push magic-operator chart"
          app_catalog: "magic-catalog"
          app_catalog_test: "magic-test-catalog"
          chart: "magic-operator"
          # Make sure docker image is successfully built.
          requires:
            - build
          # Needed to trigger job on git tag.
          filters:
            tags:
              only: /^v.*/
```

[architect]: https://github.com/giantswarm/architect
[architect-executor]: https://github.com/giantswarm/architect-orb/blob/master/src/executors/architect.yaml
