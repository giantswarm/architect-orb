# upload-release-assets

Uploads binary artifacts from the workspace to the GitHub Release for the current tag.

Use after `go-build` on tagged builds. The release itself is created by the `giantswarm/automerge` / `create-release` GitHub Action shortly after the tag lands; this job retries for up to a minute to absorb that race.

Helm charts and container images are not uploaded here — they live in the OCI registry.

## Parameters

- `binary`: Binary name as passed to `go-build` (required). The job uploads all matching files from the workspace: `<binary>-<GOOS>-<GOARCH>` and any `<binary>-<GOOS>-<GOARCH>.bundle` cosign signature bundles.
- `attempts`: Maximum number of upload attempts (default: `12`). Each attempt waits 5s before retrying.
- `resource_class`: CircleCI resource class (default: `small`).
- `github-token-env-var`: Name of the environment variable holding a GitHub token with `contents:write` on the target repository (default: `TAYLORBOT_GITHUB_ACTION`). Falls back to the GitHub App token when the variable is absent or empty.

## Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  build:
    jobs:
      - architect/go-build:
          binary: myapp
          filters:
            tags:
              only: /^v.*/
      - architect/push-to-registries:
          requires: [architect/go-build]
          image: giantswarm/myapp
          filters:
            tags:
              only: /^v.*/
      - architect/upload-release-assets:
          requires: [architect/go-build]
          binary: myapp
          filters:
            tags:
              only: /^v.*/
            branches:
              ignore: /.*/
```

`go-build` persists `myapp-linux-amd64`, `myapp-linux-arm64`, and their `.bundle` siblings to the workspace; `upload-release-assets` attaches them all to the release with `gh release upload --clobber`.

## Notes

- The job requires a `CIRCLE_TAG` to be set — always pair it with a tag filter.
- By default uses `TAYLORBOT_GITHUB_ACTION` from the `architect` context (org-wide). Falls back to the GitHub App token if that variable is absent or empty.
- If signing is disabled (`sign: false` on `go-build`), no `.bundle` files are present and only the bare binaries are uploaded.

See [Cosign signing](../cosign-signing.md) for how to verify the `.bundle` files after download.
