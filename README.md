[![CircleCI](https://circleci.com/gh/giantswarm/architect-orb.svg?style=shield)](https://circleci.com/gh/giantswarm/architect-orb) [![CircleCI Orb Version](https://img.shields.io/badge/endpoint.svg?url=https://badges.circleci.io/orb/giantswarm/architect)](https://circleci.com/orbs/registry/orb/giantswarm/architect)

# architect-orb

This repository hosts the source code for giantswarm/architect orb.

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
          # Make sure docker image is sucessfuly built.
          requires:
            - build
          # Needed to trigger job on git tag.
          filters:
            tags:
              only: /^v.*/
```
