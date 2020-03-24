# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).



## [Unreleased]

### Added

- New parameter `test-timeout` for the `integration-test-go-test` command and 
  `integration-test` job which allows to define the timeout for the test execution.
  It defaults to the value that was already in use.

### Changed

- Don't run cleanup for helm chart template command on non-tagged builds.
- Drop `unparam` from `golangci-lint`.



## [0.8.3] - 2020-03-12

### Added

- New parameter `on_tag` for the `package-and-push` command and
  `push-to-app-catalog` job which allows merges to the `master` branch
  to be deployed to the non-testing app catalog without requiring a tag.

### Changed

- Don't run cleanup for helm chart template command on non-tagged builds.



## [0.8.2] - 2020-03-10

### Changed

- Fix GOPATH problem in `integration-test` job.
- Disable version bump check for Helm lint.
- Helm lint supports single chart rather than entire directory disabling version bump check.



## [0.8.1] - 2020-03-09

### Added

- Enable linting during go-test command.



## [0.8.0] - 2020-03-05

### Added

- Support for optionally attaching the persisted workspace in the `push-to-app-catalog` job.
- Introduce Helm Chart testing and linting in `push-to-app-catalog` job.
- Add `changelog-lint` job.
- Introduce `integration-test` job for running `Go` integration tests in a `KIND`
  cluster.
- Verify chart, operator and tag versions while packing helm chart on tagged
  operator build in `push-to-app-collection` job.

### Changed

- Update CircleCI config to use `orb-tools@8.27.6`.

### Removed

- Remove Docker layer caching from remote docker setup (affects push-to-docker and push-to-docker-legacy)



## [0.7.0] - 2020-02-26

### Added

- Introduce `go-lint` for running configurable linting jobs on `Go` code
- Introduce `gitleaks` for entropy-based checks for secrets in the repository (language-agnostic)
- Support for modern code analysis tools for dep-based projects using the new
`go-test-legacy` job. Based on the existing `go-test` job.
- Support for running arbitrary architect commands inside an architect container
avoiding the requirement of installing the binary locally using the new
`go-architect-legacy` job.
- New `go-cache-save-legacy` and `go-cache-restore-legacy` commands
which enable `dep` dependencies to be cached in jobs as long as `Gopkg.lock` doesn't change.
- Names for steps in `tools-info` command.



## [0.6.0] - 2020-02-19

### Changed

- Stop injecting version into build info in `go-test` command to allow version to be maintained directly in source.

### Fixed

- Fix pushing new unique app in push-to-app-collection job. https://github.com/giantswarm/architect-orb/pull/69



## [0.5.3] - 2020-02-11

### Added

- Fail when .go files not satisfying import rules specified in fmt are present.

### Fixed

- Fix working files cleanup in push-to-app-collection job.



## [0.5.2] - 2020-02-03

### Fixed

- Do not change CR name when "unique" parameter is set in push-to-app-collection job.



## [0.5.1] - 2020-02-03

### Fixed

- Fix push-to-app-collection job broken in v0.5.0 release.



## [0.5.0] - 2020-01-31

### Added

- Add "unique" parameter to push-to-app-collection job.



## [0.4.5] - 2019-12-11

### Added

- Add "push-to-docker-legacy" command to be able push old style docker image tags.



## [0.4.4] - 2019-10-31

### Added

- Add "tag-latest-branch" parameter to the push-to-docker job.



## [0.4.3] - 2019-10-10

### Added

- Add go-test job for building libraries.



## [0.4.2] - 2019-10-04

### Added

- Add "os" parameter to the go-build job.



## [0.4.1] - 2019-10-02

### Added

- Add message to known errors link if pushing to catalog or collection fails.

### Changed

- Fail when go modules are not tidy in go-build.



## [0.4.0] - 2019-09-17

### Added

- Add go-build job.



## [0.3.0] - 2019-09-06

### Added

- Add push-to-app-collection job.



## [0.2.0] - 2019-07-26

### Added

- Add push-to-docker job.



## [0.1.2] - 2019-07-22

### Fixed

- Index new package only in package-and-push command.



## [0.1.1] - 2019-06-14

### Fixed

- Fix app catalog name reference in indexing step of package-and-push command.



## [0.1.0] - 2019-06-04

### Added

- Add push-to-app-catalog job.



[Unreleased]: https://github.com/giantswarm/architect-orb/compare/v0.8.3...HEAD
[0.8.3]: https://github.com/giantswarm/architect-orb/compare/v0.8.2...v0.8.3
[0.8.2]: https://github.com/giantswarm/architect-orb/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/giantswarm/architect-orb/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/giantswarm/architect-orb/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/giantswarm/architect-orb/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/giantswarm/architect-orb/compare/v0.5.3...v0.6.0
[0.5.3]: https://github.com/giantswarm/architect-orb/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/giantswarm/architect-orb/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/giantswarm/architect-orb/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/giantswarm/architect-orb/compare/v0.4.5...v0.5.0
[0.4.5]: https://github.com/giantswarm/architect-orb/compare/v0.4.4...v0.4.5
[0.4.4]: https://github.com/giantswarm/architect-orb/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/giantswarm/architect-orb/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/giantswarm/architect-orb/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/giantswarm/architect-orb/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/giantswarm/architect-orb/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/giantswarm/architect-orb/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/giantswarm/architect-orb/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/giantswarm/architect-orb/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/giantswarm/architect-orb/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/giantswarm/architect-orb/releases/tag/v0.1.0
