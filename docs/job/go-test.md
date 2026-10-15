# go-test

This job:

- Checks if Go modules are tidy.
- Checks if Go code is formatted according to rules.
- Checks if imports in .go files are properly sorted using `goimports`.
- Checks if filenames contain non-ASCII characters.
- Writes `.ldflags`, the linker flags [`go-build`](go-build.md) links with, stamping the
  [build metadata](#build-metadata).
- Runs `go test` against the codebase.
- Runs [`gosec`](#security-scanning-with-gosec) via `golangci-lint`. Tests are excluded.
- Runs [`nancy`](#dependency-scanning-with-nancy) against the codebase to check for known vulnerabilities in code
  dependencies.
- Runs [`govulncheck`](#vulnerability-scanning-with-govulncheck) to check whether the code reaches a known
  vulnerability. Fails closed.

## Build metadata

`.ldflags` sets string variables of the module's `pkg/project` package (`$(go list <path>)/pkg/project`):

- `buildTimestamp`: the build time in UTC, `2006-01-02T15:04:05Z`.
- `gitSHA`: the commit, `CIRCLE_SHA1`.
- `version`: on a tag pipeline the tag without its `v` (`v5.10.3` → `5.10.3`), as
  `-X '<module>/pkg/project.version=5.10.3'`. A branch pipeline does not set it, so the package's
  default applies.

Declare them as package-level `var`s; `-X` cannot set a `const`, and a repo without them builds
unchanged. Without the version flag, a binary that falls back to `debug.ReadBuildInfo()` reports a
`v0`/`v1` pseudo-version whenever the module path lacks its major suffix (`/v5`). A `test_target` that
adds its own version flag to `.ldflags`, for example for branch builds, skips when a
`/pkg/project.version=` flag is already there.

`.ldflags` is added to `.git/info/exclude`, as are the binaries and `.platforms` that
[`go-build`](go-build.md) writes into the working tree, so Go's VCS stamp keeps `vcs.modified=false`
and a binary that reports its version from the build info does not print `+dirty`.

## Security scanning with gosec

`gosec` runs via `golangci-lint` and fails the build on any finding. Each finding names the rule that
tripped, for example `G304`; [RULES.md](https://github.com/securego/gosec/blob/master/RULES.md) lists what
every rule checks.

To suppress a finding you have reviewed, add an exclusion to the repo's `golangci-lint` config. Exclude a
rule repo-wide with `linters.settings.gosec.excludes`, or scope it to a path with
`linters.exclusions.rules`:

```yaml
version: "2"
linters:
  settings:
    gosec:
      excludes:
        - G101
  exclusions:
    rules:
      - path: internal/pkg/config/
        linters:
          - gosec
        text: "G304"
```

Inline `//#nosec G304` comments still work and are unaffected by this job. Prefer the config when an
exclusion applies repo-wide or needs a written justification.

The config is read from `.golangci.yml`, `.golangci.yaml`, `.golangci.toml` or `.golangci.json`, searched
from the repo root upwards. The `path` parameter does not affect this, so a config in a subdirectory is
ignored even when the Go package lives there. The file must be v2 format (`version: "2"`); a v1 file fails
to parse and fails the build.

Two limits on what the config can do:

- Linter selection is ignored: only `gosec` runs, and `linters.disable: [gosec]` does not disable the
  check. `run.tests`, `run.issues-exit-code`, `issues.new*` and `issues.max-*` are overridden too, so the
  config cannot make this step advisory-only.
- Exclusions are not bounded, so a config can still suppress everything: a broad `linters.exclusions.path`,
  or `linters.settings.gosec.includes`, which is an allowlist that drops every rule it does not name. Keep
  both scoped and commented.

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

## Dependency scanning with nancy

nancy asks the Sonatype Guide API about every dependency `go list -json -deps ./...` lists. Vulnerable
dependencies that `.nancy-ignore` and `.nancy-ignore.generated` do not exclude fail the job, and so does a
failing `go list`.

nancy caches each dependency's report for 12 hours. The job keeps that cache (`~/.cache/nancy`) in a
CircleCI cache per branch and 12-hour window, so a dependency costs Sonatype Guide credits once per window
instead of once per build, and a build whose dependencies are all cached scans while the API is unavailable.
The cache never crosses branches: a branch's build cannot hand reports to the default branch or a tag.

When nancy cannot get an answer (an outage, a rate limit, an exhausted credit quota or rejected credentials),
the job does not fail, so an unrelated pull request is not blocked. The step prints `NOT SCANNED:` with the
reason, and the job's JUnit results record the failed test `Go dependencies are scanned for known
vulnerabilities`, shown in the job's Tests tab and in CircleCI's test insights. A green job with that failed
test has not checked its dependencies.

## Vulnerability scanning with govulncheck

[govulncheck](https://go.dev/doc/security/vuln/) checks the code against the Go vulnerability database
(`vuln.go.dev`), which needs no account or credits. It reports a vulnerability only when the code calls an
affected function, so a vulnerable module the code imports but does not reach passes.

The step fails closed:

- A reachable vulnerability fails the job. The step lists each one with its module, the version in use and the
  fixed version; `govulncheck ./...` locally shows the call traces.
- A scan that could not run (the database is unreachable, the code does not build) fails the job and prints
  `NOT SCANNED:`. A green step always means the code was scanned and reaches nothing known.

The JUnit test `Go code reaches no known vulnerability` records the result in the job's Tests tab.

### Excluding a reviewed finding

A finding without a fix, or one that cannot be bumped yet, is excluded in `.govulncheck-ignore` at the
repository root, one entry per line:

```
# GO ID or alias (CVE, GHSA), the date the exclusion ends, why and the issue that tracks the fix
GO-2026-5932 until=2026-12-31  # x/crypto/openpgp has no fix; replacing the updater, https://github.com/org/repo/issues/1
```

`until=` is required. An entry past its date, or without one, no longer applies and the step says so, so an
exclusion cannot outlive its review.

