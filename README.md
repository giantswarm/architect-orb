[![CircleCI](https://dl.circleci.com/status-badge/img/gh/giantswarm/architect-orb/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/giantswarm/architect-orb/tree/main)
[![Orb Version Badge](https://badges.circleci.com/orbs/giantswarm/architect.svg)](https://circleci.com/developer/orbs/orb/giantswarm/architect)

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
  and visible and keeping build configurations sane.
- Using [architect executor][architect-executor] with the latest
  [architect][architect] docker image most of time.
- Using binaries other than `architect` when appropriate (they should be
  available inside [architect executor][architect-executor] most of the time).
  E.g. `docker`, `git`, `helm`, etc. Instead of wrapping existing well known
  functionality in [architect][architect] binary.
- Using purpose-built binaries for complex tasks. For example, `gitsemver
  version` computes chart/image versions from git state, replacing earlier
  `architect`-driven version manipulation.

[architect]: https://github.com/giantswarm/architect
[architect-executor]: https://github.com/giantswarm/architect-orb/blob/main/src/executors/architect.yaml

## Coding Guidelines

- Jobs should be documented in [docs](/docs).
- Jobs should call only commands and not have steps defined directly. I.e. no
  `run:` key in _/jobs_ directory.
- Steps defined in commands should be named. Names should be [prefixed with
  `architect/COMMAND_NAME` like here][step-prefix] and use imperative format.
- Steps defined in commands should be small. Ideally single binary call. One
  exception is step skipping described later.
- Steps should be described using the `name:` attribute, to make it as easy as
  possible to understand what's happening.
- Step skipping should be done using [`when:` and `unless:` steps][when-unless].
- If using [`when:` and `unless:` steps][when-unless] is difficult then
  multiline skipping is acceptable. [See this code for
  example][multiline-skipping].
- Temporary information between steps should be carried in files prefixed with
  `.build_`.
- Temporary `.build_*` files should be only used in scope of a single command.
- A command using temporary files should clean them up as the last step.

[multiline-skipping]: https://github.com/giantswarm/architect-orb/blob/3e36470/src/commands/prepare-catalogbot-git-ssh.yaml
[step-prefix]: https://github.com/giantswarm/architect-orb/blob/main/src/commands/push-helm.yaml
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

## Releases

Releases are done by GitHub automation: merging a PR to `main` tags the release from its
[conventional commit](https://www.conventionalcommits.org/) subject and CircleCI publishes the orb. Do not
create releases manually.
