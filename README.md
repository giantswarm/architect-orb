[![CircleCI](https://circleci.com/gh/giantswarm/architect-orb.svg?style=shield)](https://circleci.com/gh/giantswarm/architect-orb) [![CircleCI Orb Version](https://img.shields.io/badge/endpoint.svg?url=https://badges.circleci.io/orb/giantswarm/architect)](https://circleci.com/orbs/registry/orb/giantswarm/architect)

# architect-orb

This repository hosts the source code for giantswarm/architect orb.



## Design and Goals

- Replacing [architect][architect] entirely **is not** a goal. But replacing
  most of its functionality is.
- Being explicit. Desire to do actual job. E.g. building a docker image and
  pushing it to a registry should be explicitly specified in the build.
- Making builds understandable without looking into [architect][architect]
  codebase.
- Having one line binary call on each job step - to make the outputs grouped
  and visible and keeping build configurations sane. Good example is
  [helm-chart-template][helm-chart-template].
- Using [architect executor][architect-executor] with the latest
  [architect][architect] docker image most of time.
- Using binaries other than `architect` when appropriate (they should be
  available inside [architect executor][architect-executor] most of the time).
  E.g. `docker`, `git`, `helm`, etc. Instead of wrapping existing well known
  functionality in [architect][architect] binary.
- Using [architect][architect] commands for complex tasks. Good example is
  `architect helm template` instead of awkward and error prone `sed` calls.

[helm-chart-template]: https://github.com/giantswarm/architect-orb/blob/master/src/commands/helm-chart-template.yaml

## Coding Guidelines

- Jobs should be documented in [docs](/docs).
- Jobs should call only commands and not have steps defined directly. I.e. no
  `run:` key in _/jobs_ directory.
- Steps defined in commands should be named. Names should be [prefixed with
  `architect/COMMAND_NAME` like here][step-prefix]. They should have imperative
  format.
- Steps defined in commands should be small. Ideally single binary call. One
  exception is step skipping described later.
- Step skipping should be done using [`when:` and `unless:` steps][when-unless].
- If using [`when:` and `unless:` steps][when-unless] is difficult then
  multiline skipping is acceptable. [See this code for
  example][multiline-skipping].
- Temporary information between steps should be carried in files prefixed with
  `.build_`.
- Temporary `.build_*` files should be only used in scope of a single command.
- A command using temporary files should clean them with [cleanup step in
  format linked here][cleanup-step]. This should be the last step of the command.

[cleanup-step]: https://github.com/giantswarm/architect-orb/blob/cbbb1b8d036ba7f10c58fa06e88028d759cd12e8/src/commands/helm-chart-template.yaml#L41-L44
[multiline-skipping]: https://github.com/giantswarm/architect-orb/blob/cbbb1b8d036ba7f10c58fa06e88028d759cd12e8/src/commands/helm-chart-template.yaml#L13-L15
[step-prefix]: https://github.com/giantswarm/architect-orb/blob/cbbb1b8d036ba7f10c58fa06e88028d759cd12e8/src/commands/helm-chart-template.yaml#L7
[when-unless]: https://circleci.com/docs/2.0/configuration-reference/#the-when-step-requires-version-21

## Development

- For a completely new job that is not reusing any of the existing commands the
  fastest way to prototype is probably creating an inline orb. Here is an
  example of working inline orb prototype:
  https://github.com/giantswarm/release-operator/pull/121/files.
- Create a PR and test your changes using the dev version, by changing
  the orb declaration to `architect: giantswarm/architect@dev:your-branch`.
  Dev versions are mutable and deleted after 90 days. Details here
  https://circleci.com/docs/2.0/using-orbs/#development-and-production-orbs-versioning-semantics.
- Update [Unreleased section of CHANGELOG.md](CHANGELOG.md#Unreleased) file
  with the changes introduced in your PR.
- If you want to also make a new release follow the steps in
  [Releases](#Releases) section (which is most likely the case) or merge your
  PR.

## Releases

1. Open a new PR with following changes:
    - Change [Unreleased header of CHANGELOG.md](CHANGELOG.md#Unreleased) to
    the version you are going to release.
    - Create new _Unreleased_ section in _CHANGELOG.md_.
    - Update the URLs at the bottom.
2. Merge your PR.
3. Tag the version (e.g. `git tag v0.1.0 dc15f409d09884784fab86ebb6725b14a3f3cd2e && git push origin v0.1.0`) so links in
   [CHANGELOG.md](CHANGELOG.md) work nicely.

## Jobs

### go-test

This job:

- Checks if Go modules are tidy.
- Checks if imports in .go files satisfy import rules defined in fmt.
- Runs `go vet` against the codebase.
- Runs `go test` against the codebase.

Example usage:

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/go-test:
          name: go-test-REPOSITORY
          # Needed to trigger job also on git tag.
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```

### go-build

This job:

- Does everything [go-test](#go-test) job does.
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
          name: go-build-REPOSITORY
          binary: REPOSITORY
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```

### integration-test

- Runs an integration test by creating a KIND cluster and executing it as a Go test.
- See [docs](docs/integration_test.md).

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
          name: "push-REPOSITORY-to-CATALOG-app-catalog"
          app_catalog: "CATALOG-catalog"
          app_catalog_test: "CATALOG-test-catalog"
          chart: "REPOSITORY"
          requires:
            # Make sure docker image is successfully built.
            - push-REPOSITORY-to-quay
          filters:
            # Trigger job also on git tag.
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

### push-to-docker-legacy

Same as `push-to-docker` with only change that the docker image tag only includes the commit SHA instead of version + SHA.

### push-to-app-collection

This job generate an App CR and add it to the an app collection chart repository.

* The App name, App namespace and catalog are passed by parameters (respectively `app_name`, `app_namespace` and `app_catalog`).
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
          name: "push-REPOSITORY-to-COLLECTION-app-collection"
          app_name: "REPOSITORY"
          app_namespace: "NAMESPACE"
          app_collection_repo: "COLLECTION-app-collection"
          requires:
            # Make sure the chart bechind the app is in the app catalog.
            - push-REPOSITORY-to-CATALOG-app-catalog
          filters:
            # Do not trigger the job on commit.
            branches:
              ignore: /.*/
            # Trigger job also on git tag.
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
