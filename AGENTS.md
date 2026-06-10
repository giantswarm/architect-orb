This file provides guidance to AI agents working with code in this repository.

## What this repo is

`architect-orb` is a [CircleCI orb](https://circleci.com/developer/orbs/orb/giantswarm/architect) that
provides reusable CI/CD jobs and commands for Giant Swarm projects. It builds, tests, and publishes Go
binaries, Docker images, and Helm charts to Giant Swarm's image and chart registries.

## Development workflow

There are no local build or test commands — the orb is developed by pushing branches and testing against
CircleCI.

**Testing changes**: Each branch push publishes the dev orb under three tags: `dev:<branch-name>`,
`dev:<full-commit-sha>`, and `dev:alpha` (latest dev publish of any branch). Reference the branch-name
tag in a consuming repo's `.circleci/config.yml` — it always points at the latest push of the branch:

```yaml
orbs:
  architect: giantswarm/architect@dev:my-branch-name
```

Use the commit-SHA tag instead when a run must be pinned to an exact revision. Dev versions are mutable
and auto-deleted after 90 days.

**CI pipeline** (`.circleci/config.yml`):

1. `orb-tools/lint` — validates YAML structure
2. `orb-tools/pack` — assembles `src/` into a single packed orb
3. `orb-tools/publish` — publishes as dev version (branches) or production (tags matching `v\d+\.\d+\.\d+`)

## Source structure

```
src/
  @orb.yml          # Orb description only (no jobs/commands declared here)
  commands/         # Reusable steps (one YAML file per command)
  jobs/             # Job definitions (compose commands; no `run:` steps directly)
  executors/        # Executor definitions
docs/               # Job documentation (one .md per job)
```

The main executor (`src/executors/architect.yaml`) uses `gsoci.azurecr.io/giantswarm/architect:<version>`,
which bundles all required tools: `architect`, `gitsemver`, `helm`, `go`, `cosign`, `hadolint`, etc.

## Coding guidelines

- **Jobs call only commands** — no `run:` steps directly in `src/jobs/`. All logic lives in commands.
- **Step names are prefixed** with `architect/COMMAND_NAME:` and use imperative phrasing (e.g.,
  `architect/push-helm-package: Push chart archive to app catalog repo`).
- **Steps are small** — ideally a single binary call per step.
- **Conditional steps** use `when:` / `unless:` blocks. Multiline skipping (`[ condition ] && exit 0`) is
  acceptable when `when:`/`unless:` is awkward.
- **Inter-step state** is passed via files prefixed `.build_*`, scoped to a single command, and cleaned up in
  a final cleanup step.
- **Version stamping** uses `gitsemver version` (not `architect project version`). This is the canonical way
  to get the current build version.
- Always update the `CHANGELOG.md` with a summary of changes and notable features/fixes.

## Versioning and signing (v9+)

- `gitsemver version` computes semver from git state for all artifacts.
- Cosign keyless OIDC signing is on by default for images, charts, and binaries on **public** repos. Private
  repos are skipped to avoid Rekor transparency log leakage.
- `push-to-registries` uses `docker buildx` exclusively (no single-arch path). Platform list comes from the
  `.platforms` workspace file written by `go-build`, or defaults to `linux/amd64,linux/arm64`.

## Registries

- Public images/charts: `gsoci.azurecr.io` (auth via `ACR_GSOCI_USERNAME`/`ACR_GSOCI_PASSWORD`)
- Private images/charts: `gsociprivate.azurecr.io` (auth via `ACR_GSOCIPRIVATE_*`)
- Visibility is auto-detected from the GitHub API unless `force-public: true` is set.

## Releases

Done by github automation. Do not create releases manually.
