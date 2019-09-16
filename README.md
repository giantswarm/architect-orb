[![CircleCI](https://circleci.com/gh/giantswarm/architect-orb.svg?style=shield)](https://circleci.com/gh/giantswarm/architect-orb) [![CircleCI Orb Version](https://img.shields.io/badge/endpoint.svg?url=https://badges.circleci.io/orb/giantswarm/architect)](https://circleci.com/orbs/registry/orb/giantswarm/architect)

# architect-orb

This repository hosts the source code for giantswarm/architect orb.

Design and goals of the project:

- Replacing [architect][architect] entirely **is not** a goal. But replacing
  most of its functionality is.
- Being explicit. Desire to do actual job. E.g. building a docker image and
  pushing it to a registry should be explicitly specified in the build.
- Making builds understandable without looking into [architect][architect]
  codebase.
- Having one line binary call on each job step - to make the outputs grouped
  and visible and keeping build configurations sane. Good example is
  [package-and-push command][package-and-push-command].
- Using [architect executor][architect-executor] with the latest
  [architect][architect] docker image most of time.
- Using binaries other than `architect` when appropriate (they should be
  available inside [architect executor][architect-executor] most of the time).
  E.g. `docker`, `git`, `helm`, etc. Instead of wrapping existing well known
  functionality in [architect][architect] binary.
- Using [architect][architect] commands for complex tasks. Good example is
  `architect helm template` instead of awkward and error prone `sed` calls.

[package-and-push-command]: https://github.com/giantswarm/architect-orb/blob/master/src/commands/package-and-push.yaml

## Development

- For a completely new job that is not reusing any of the existing commands the
  fastest way to prototype is probably creating an inline orb. Here is an
  example of working inline orb prototype:
  https://github.com/giantswarm/release-operator/pull/121/files.
- Create a PR and test your changes using `dev:BRANCH_NAME` version. This
  version is updated every time job `orb-tools/publish-dev` configured in
  [circleci config](.circleci/config.yml) runs. Which is basically on every
  pushed commit in the feature branch. Dev versions are mutable and deleted
  after 90 days. Details here
  https://circleci.com/docs/2.0/creating-orbs/#using-development-versions. To
  use `dev:BRANCH_NAME` version you need to  change the version of the orb
  declaration to `architect: giantswarm/architect@dev:BRANCH_NAME`.
- Update [Unreleased section of CHANGELOG.md](CHANGELOG.md#Unreleased) file
  with the changes introduced in your PR.
- If you want to also make a new release follow the steps in
  [Releases](#Releases) section (which is most likely the case) or merge your
  PR.

## Releases

1. Open a new PR with changes to `orb-tools/dev-promote-prod` job in [circleci
   config](.circleci/config.yml):
    - Change `release: patch` line to `minor` or `major` if the release isn't
      a patch release.
    - Uncomment `only: master` line and comment `ignore: /.*/`.
2. Change [Unreleased header of CHANGELOG.md](CHANGELOG.md#Unreleased) to the
   version you are going to release. Please also update the URLs at the bottom.
   To check the current version of the orb check "orb version" badge on the
   top.
3. Create new _Unreleased_ section in _CHANGELOG.md_.
4. Merge your PR.
5. **IMPORTANT:** Create a new PR reverting changes introduced in step 1.
   **immediately** so we don't create useless versions in branches created from
   master.
6. Push the version tag for the commit against which
   `orb-tools/dev-promote-prod` job ran. E.g. `git tag v0.1.0
   dc15f409d09884784fab86ebb6725b14a3f3cd2e` so links in
   [CHANGELOG.md](CHANGELOG.md) work nicely.

## Jobs

### go-build

This job:

- Runs `go test` against the codebase.
- Builds a go binary.
- Runs `BINARY version` and checks if it returned 0 exit code.
- Persists the binary to the workspace.

Example usage:

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/go-build:
          name: go-build-MY-BINARY
          binary: MY-BINARY
          # Needed to trigger job also on git tag.
          filters:
            tags:
              only: /^v.*/
```

### push-to-app-catalog

This job templates and packages a given `chart` from the helm directory and
pushes it to `app_catalog` for tagged builds and `app_catalog_test` otherwise.

**NOTE**: The job requires `CATALOGBOT_SSH_KEY_PRIVATE_BASE64` environment
variable to be set in the build. This must be base64 encoded private SSH key of
[CatalogBot Github user][catalogbot-user].

**NOTE**: App catalog repositories configured in the job parameters must be
added to the [Catalog Editors][catalog-editors-team] GitHub team. See the
paragraph below for explanation.

This job assumes that the App Catalog is defined in a GitHub repository inside
giantswarm organization. E.g. when `app_catalog` parameter is set to
`"control-plane-test-catalog"` the job will try to use catalog
https://github.com/giantswarm/control-plane-test-catalog. All interactions with
the App Catalog GitHub repository are done with [CatalogBot github
user] credentials.

Detailed instructions on how to set up App Catalog can be found here:
https://github.com/giantswarm/giantswarm/blob/master/processes/appcatalog.md#setting-up-a-new-app-catalog.

[catalog-editors-team]: https://github.com/orgs/giantswarm/teams/catalog-editors/repositories
[CatalogBot github user]: https://github.com/catalogbot

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


**NOTE**: There is a known issue produced by a race condition which produces a failed build with the following output.
```
To github.com:giantswarm/control-plane-test-catalog.git
 ! [rejected]        master -> master (fetch first)
error: failed to push some refs to 'git@github.com:giantswarm/control-plane-test-catalog.git'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally. This is usually caused by another repository pushing
hint: to the same ref. You may want to first integrate the remote changes
hint: (e.g., 'git pull ...') before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
Exited with code 1
```
It is an rare case so triggering again the build should solve the issue.

### push-to-docker

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
          image: "giantswarm/magic-operator"
          registry: "quay.io"
          username_envvar: "QUAY_USERNAME"
          password_envvar: "QUAY_PASSWORD"
          requires:
            - build
          filters:
            tags:
              only: /^v.*/
```

### push-to-app-collection

This job generate an App CR and add it to the an app collection chart repository.

* The App name and catalog are passed by parameters (respectively `app_name` and `app_catalog`).
* The App version is automatically detected by `architect project version`.
* The app collection repository where the App CR is added to is passed by parameter (`app_collection_repo`).

**NOTE**: The job requires `CATALOGBOT_SSH_KEY_PRIVATE_BASE64` environment
variable to be set in the build. This must be base64 encoded private SSH key of
[CatalogBot Github user][catalogbot-user].

**NOTE**: app collection repositories configured in the job parameters must be
added to the [Catalog Editors][catalog-editors-team] GitHub team with write permission. See the
paragraph below for explanation.

This job assumes that the app collection is defined in a GitHub repository inside
giantswarm organization. E.g. when `app_collection_repo` parameter is set to
`"aws-app-collection"` the job will try to use https://github.com/giantswarm/aws-app-collection.
All interactions with the app collection GitHub repository are done with [CatalogBot github
user] credentials.

[catalog-editors-team]: https://github.com/orgs/giantswarm/teams/catalog-editors/repositories
[CatalogBot github user]: https://github.com/catalogbot

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-app-collection:
          name: "push-to-aws-app-collection"
          app_name: "aws-operator"
          app_collection_repo: "aws-app-collection"
          requires:
            - push-aws-operator-to-app-catalog
          filters:
            branches:
              ignore: /.*/
            tags:
              only: /^v.*/
```


**NOTE**: There is a known issue produced by a race condition which produces a failed build with the following output.

```
To github.com:giantswarm/aws-app-collection.git
 ! [rejected]        master -> master (fetch first)
error: failed to push some refs to 'git@github.com:giantswarm/aws-app-collection.git'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally. This is usually caused by another repository pushing
hint: to the same ref. You may want to first integrate the remote changes
hint: (e.g., 'git pull ...') before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
Exited with code 1
```
It is an rare case so triggering again the build should solve the issue.


[architect]: https://github.com/giantswarm/architect
[architect-executor]: https://github.com/giantswarm/architect-orb/blob/master/src/executors/architect.yaml
