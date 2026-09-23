# go-test

This job:

- Checks if Go modules are tidy.
- Checks if Go code is formatted according to rules.
- Checks if imports in .go files are properly sorted using `goimports`.
- Checks if filenames contain non-ASCII characters.
- Runs `go test` against the codebase.
- Runs [`gosec`](#security-scanning-with-gosec) via `golangci-lint`. Tests are excluded.
- Runs `nancy` against the codebase to check for known vulnerabilities in code dependencies.

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
