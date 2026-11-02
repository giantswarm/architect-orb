# pin-version

Resolves the workflow's version once, at its start, and persists it to the
workspace as `.pipeline_version`. Every job that requires `pin-version` and
attaches the workspace builds with that version instead of resolving its own.

Without it every job resolves the version itself with `gitsemver get`, from the
git state of its own checkout. A dev version is built on the most recent stable
tag reachable from the commit, and each checkout fetches the tags anew, so a
stable tag that lands while the workflow runs -- a promote tagging a commit the
branch contains -- moves that base between jobs. The image is then tagged
`1.2.4-…` and the chart that references it stamped `1.3.1-…`, and
app-build-suite's image reference check fails the chart push.

```
pin-version ──▶ .pipeline_version (workspace)
     │
     ├──▶ build-image / push-to-registries   image tagged with it
     └──▶ push-to-app-catalog                chart stamped with it
          (attach_workspace: true)
```

`image-prepare-tag` reads the file when it is in the working directory, which
`build-image` and `push-to-registries` (they always attach the workspace) and
`push-to-app-catalog` with `attach_workspace: true` provide. A job without the
file resolves the version as before. The rule for a branch pipeline at a tagged
commit (the job ends, green, before building) applies to the pinned version.

The job is small and needs nothing but the checkout: run it in parallel with
the build job at the start of the workflow and add it to the `requires` of
every job that builds with the version. A rerun from failed keeps the pinned
version; a full rerun resolves it anew.

## Example usage

```yaml
workflows:
  build:
    jobs:
      - architect/pin-version:
          name: pin-version
          filters:
            tags:
              only: /^v.*/

      - architect/push-to-registries:
          context: architect
          name: push-to-registries
          requires:
            - pin-version
          filters:
            tags:
              only: /^v.*/

      - architect/push-to-app-catalog:
          context: architect
          name: push-to-app-catalog
          app_catalog: control-plane-catalog
          app_catalog_test: control-plane-test-catalog
          chart: my-app
          attach_workspace: true
          requires:
            - push-to-registries
          filters:
            tags:
              only: /^v.*/
```

## Parameters

- `git-tag-prefix` (optional string, default `""`): the tag prefix of a mono
  repo. The file is then `.pipeline_version-<prefix>`, read by the jobs that pass
  the same prefix.
- `resource_class` (optional, default `small`).
