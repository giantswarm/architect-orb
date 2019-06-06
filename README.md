[![CircleCI](https://circleci.com/gh/giantswarm/architect-orb.svg?style=shield)](https://circleci.com/gh/giantswarm/architect-orb) [![CircleCI Orb Version](https://img.shields.io/badge/endpoint.svg?url=https://badges.circleci.io/orb/giantswarm/architect)](https://circleci.com/orbs/registry/orb/giantswarm/architect)

# architect-orb

This repository hosts the source code for giantswarm/architect orb.

Design and goals of the project:

- Replacing [architect][architect] entirely **is not** a goal. But replacing most of its functionality is.
- Being explicit. Desire to do actual job. E.g. building a docker image and pushing it to a registry should be explicitly specified in the build.
- Making builds understandable without looking into [architect][architect] codebase.
- Having one line binary call on each job step - to make the outputs grouped and visible and keeping build configurations sane. Good example is [package-and-push command](https://github.com/giantswarm/architect-orb/blob/master/src/commands/package-and-push.yaml).
- Using [architect executor][architect-executor] with the latest [architect][architect] docker image most of time.
- Using binaries other than `architect` when appropriate (they should be available inside [architect executor][architect-executor] most of the time). E.g. `docker`, `git`, `helm`, etc. Instead of wrapping existing well known functionality in [architect][architect] binary.
- Using [architect][architect] commands for complex tasks. Good example is `architect helm template` instead of awkward and error prone `sed` calls.

## Development

- For a completely new job that is not reusing any of the existing commands the fastest way to prototype is probably creating an inline orb. Here is an example of working inline orb prototype: https://github.com/giantswarm/release-operator/pull/121/files.
- Create a PR and test your changes using `dev:alpha` version. This version is updated every time job `orb-tools/publish-dev` configured in [circleci config](.circleci/config.yml) runs. Which is basically on every pushed commit. Beware that if someone else is developing on another branch at the same time `dev:aplha` version is likely to be overridden by their builds. You need to coordinate that. That should be enough for time being as we don't usually develop more than one CI feature at a time. To use `dev:alpha` version you need to just change the version of the orb declaration to `architect: giantswarm/architect@dev:alpha`.
- Update [Unreleased section of CHANGELOG.md](CHANGELOG.md#Unreleased) file with the changes introduced in your PR.
- If you want to also make a new release follow the steps in [Releases](#Releases) section (which is most likely the case) or merge your PR.

## Releases

1. Open a new PR with changes to `orb-tools/dev-promote-prod` job in [circleci config](.circleci/config.yml):
    - Change `release: patch` line to `minor` or `major` if the release isn't a patch release.
    - Uncomment `only: master` line and comment `ignore: /.*/`.
2. Change [Unreleased header of CHANGELOG.md](CHANGELOG.md#Unreleased) to the version you are going to release. Please also update the URLs at the bottom.
3. Create new _Unreleased_ section in _CHANGELOG.md_.
4. Merge your PR.
5. Push the version tag for the commit against which `orb-tools/dev-promote-prod` job ran. E.g. `git tag v0.1.0 dc15f409d09884784fab86ebb6725b14a3f3cd2e`.
6. **IMPORTANT:** Create a new PR reverting changes introduced in 1. **immediately** so we don't create useless versions in branches created from master.

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
