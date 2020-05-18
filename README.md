[![CircleCI](https://circleci.com/gh/giantswarm/architect-orb.svg?style=shield)](https://circleci.com/gh/giantswarm/architect-orb)
[![CircleCI Orb Version](https://img.shields.io/badge/endpoint.svg?url=https://badges.circleci.io/orb/giantswarm/architect)](https://circleci.com/orbs/registry/orb/giantswarm/architect)

# architect-orb

This repository hosts the source code for giantswarm/architect orb.

## Jobs

Jobs available in this orb are documented [here](docs/README.md#jobs)

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

[architect]: https://github.com/giantswarm/architect
[architect-executor]: https://github.com/giantswarm/architect-orb/blob/master/src/executors/architect.yaml
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
3. Create GitHub release for the commit merged to master branch [here]
   (https://github.com/giantswarm/architect-orb/releases/new). Fill in only
   the `Tag version` fields. The rest should remain empty.
