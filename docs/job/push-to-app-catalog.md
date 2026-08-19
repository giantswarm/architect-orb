# push-to-app-catalog

This job templates and packages a given `chart` from the helm directory and
pushes it to `app_catalog` for tagged builds and `app_catalog_test` otherwise.

It supports both classic GitHub-repository-based catalogs and OCI registry
catalogs (by default in Azure Container Registry). Depending on parameters, it
can push to one or the other, or both of them with a single job run.

## Pushing to GitHub App Catalogs (`push_to_appcatalog: true`)
**NOTE**: The job requires `CATALOGBOT_SSH_KEY_PRIVATE_BASE64` environment
variable to be set in the build. This must be base64 encoded private SSH key of
[CatalogBot Github user][catalogbot-user].

**NOTE**: App catalog repositories configured in the job parameters must be
added to the [Catalog Editors][catalog-editors-team] GitHub team. See the
paragraph below for explanation.

This job assumes that the App Catalog is defined in a GitHub repository inside
giantswarm organization. E.g. when `app_catalog` parameter is set to
`"control-plane-test-catalog"` the job will try to use catalog
[giantswarm/control-plane-test-catalog][control-plane-test-catalog]. All
interactions with the App Catalog GitHub repository are done with [CatalogBot
github user][catalogbot-user] credentials.

Detailed instructions on how to set up App Catalog can be found
[here][creating_app_catalog].

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

[catalog-editors-team]: https://github.com/orgs/giantswarm/teams/bot-catalog-editors/repositories
[catalogbot-user]: https://github.com/catalogbot
[control-plane-test-catalog]: https://github.com/giantswarm/control-plane-test-catalog
[creating_app_catalog]: https://intranet.giantswarm.io/docs/dev-and-releng/app-developer-processes/creating_app_catalog/

## Pushing to OCI Registries (`push_to_oci_registry: true`)

The job pushes Helm charts to Giant Swarm's App Catalog OCI registry — `gsoci.azurecr.io/charts/giantswarm` for public images, `gsociprivate.azurecr.io/charts/giantswarm` for private. Visibility is detected from the source GitHub repository (`force-public: true` overrides). Authentication uses the standard CircleCI context env vars (`ACR_GSOCI_USERNAME`/`ACR_GSOCI_PASSWORD` or `ACR_GSOCIPRIVATE_*`).

You can read more about storing helm charts in OCI registries in the [helm
documentation](https://helm.sh/blog/storing-charts-in-oci/).

## Chart version safety

Unlike the GitHub catalog — which is split into `app_catalog` for releases and `app_catalog_test`
for everything else — the OCI registry path is **not** split by build type. Every build pushes to
`<registry>/charts/giantswarm`, and `helm push` replaces whatever the chart's version tag currently
points at. Publishing a plain release version such as `1.2.3` from a branch build therefore
overwrites the released chart in place, and anything tracking that version — Flux most notably —
reconciles the digest change and rolls out the branch's code.

What prevents this is that the chart version is **always** stamped from `gitsemver`. Off-tag that
yields an `X.Y.Z-dev.<branch>.<date>.<time>` pre-release, which cannot collide with a release. This
is why [override_chart_version](#override_chart_version-optional-deprecated) is deprecated and
ignored — leaving the version from `Chart.yaml` in place let a branch build that had not bumped the
version by hand republish, and so overwrite, the released chart.

## Reporting the published version on a pull request

That dev-version scheme is exactly why this is needed: `X.Y.Z-dev.<branch>.<date>.<time>` is
collision-proof but not guessable, so a reviewer who wants to install the chart from a pull request
would otherwise have to open the CircleCI job and read the log.

With [comment_on_pr](#comment_on_pr-optional-boolean-defaulttrue) (the default), the job posts a
single comment on the pull request stating the chart name and version it published, plus the OCI
reference, the digest, and a `helm pull` command. Later pushes **update that same comment in place**
rather than adding new ones, so a long-running branch produces one comment and one notification.

**Prerequisite.** The `CircleCI architect` GitHub App must hold `Pull requests: write` (and
`Issues: write` — pull request conversation comments live on the issues endpoints) on the
repository, accepted by an organisation owner. Without it the job logs a warning naming the missing
permission and carries on.

Known limitations, all of which log a line and leave the build green:

- Nothing is posted for tag builds or default-branch builds — there is no pull request, and a tag
  build's version follows the tag anyway.
- Nothing is posted for forked pull requests: CircleCI withholds context environment variables from
  them, so no GitHub token can be minted.
- If the push predates the pull request, the comment appears on the first build **after** it is
  opened.
- Nothing is posted when both `push_to_appcatalog` and `push_to_oci_registry` are `false`, since
  nothing was published.

## Parameters

- [common parameters](common.md#parameters) shared in all jobs.
- [attach_workspace](#attach_workspace) (optional boolean, default=false)
- [executor](#executor-optional-deprecated) (optional, deprecated, only `app-build-suite` accepted)
- [chart](#chart) name of the directory containing the chart in `helm/`
- [on_tag](#on_tag-optional-boolean-defaulttrue) only push tagged commits to `app_catalog`
- [explicit_allow_chart_name_mismatch](#explicit_allow_chart_name_mismatch-optional-boolean-defaultfalse)
- [persist_chart_archive](#persist_chart_archive-optional-boolean-defaultfalse)
- [push_to_appcatalog](#push_to_appcatalog-optional-boolean-defaulttrue)
- [push_to_oci_registry](#push_to_oci_registry-optional-boolean-defaulttrue)
- [sign](#sign-optional-boolean-defaulttrue)
- [override_chart_version](#override_chart_version-optional-deprecated) (optional, deprecated, always treated as `true`)
- [override_app_version](#override_app_version-optional-boolean-defaulttrue)
- [comment_on_pr](#comment_on_pr-optional-boolean-defaulttrue)

### attach_workspace

When this is `true`, the CircleCI `attach_workspace` command will be executed
immediately after `checkout` into the working directory. Use this if files are
generated/modified in a previous workflow job and need to be used in this job.

### on_tag (optional boolean, default=true)

When this is `false`, commits to `master` will be pushed to `app_catalog`
instead of `app_catalog_test`. Set this to `false` for deployments that follow
a master branch for production releases rather than using tags (the default).

### executor (optional, deprecated)

Kept for backwards compatibility. Only `app-build-suite` is accepted and is the default.
Will be removed in a future version.

### chart

Name of the directory containing the helm chart in the `helm/` directory. This should match
the name of the repository with an optional `-app` suffix.

### explicit_allow_chart_name_mismatch (optional boolean, default=false)

Should be used to allow chart name validation. Set to `true` to explicitly disable checking against the name of the repository with optional `-app` suffix.
This can be the case if the chart directory is generated during CI runs or when multiple charts reside in a single repository.

### persist_chart_archive (optional boolean, default=false)

When set to `true` the packaged chart archive will be persisted to the workspace. Set this to `true` if you're planning to
execute chart tests using the [`run-tests-with-ats`] job.

## Example

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-app-catalog:
          context: architect
          name: push-REPOSITORY-to-CATALOG-app-catalog
          app_catalog: CATALOG-catalog
          app_catalog_test: CATALOG-test-catalog
          chart: REPOSITORY
          requires:
            # Make sure docker image is successfully built.
            - push-REPOSITORY
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```

### push_to_appcatalog (optional boolean, default=true)

When set to `true`, the packaged chart will be pushed to a classic GitHub app
catalog.

### push_to_oci_registry (optional boolean, default=true)

When set to `true`, the packaged chart will be pushed to the giantswarm OCI
registry (`gsoci.azurecr.io/charts/giantswarm` for public charts,
`gsociprivate.azurecr.io/charts/giantswarm` for private). The registry URL
and authentication are not configurable — they're determined from the source
repository's GitHub visibility and standard `ACR_GSOCI_*` /
`ACR_GSOCIPRIVATE_*` context env vars.

### sign (optional boolean, default=true)

When `true`, the pushed Helm chart is signed with cosign keyless OIDC.
The signature lands as an OCI 1.1 referrer artifact on the chart and is
queryable via the registry's referrers API.

Skipped at runtime when the source repository is private (signing would
publish digest + timestamp metadata to the public Rekor transparency log).

See [Cosign signing](../cosign-signing.md) for the verification command
and the end-to-end identity model.

### override_chart_version (optional, deprecated)

**Deprecated.** This parameter has no effect anymore and is always treated as `true`. It is kept
for backwards compatibility and will be removed in a future version.

The chart's `version` field is always stamped with the value computed by `gitsemver` (or read from
the `.build_version` workspace file). Setting the parameter to `false` used to leave the `version`
field in `Chart.yaml` unchanged — see [Chart version safety](#chart-version-safety) for why that is
no longer allowed.

Note that [override_app_version](#override_app_version-optional-boolean-defaulttrue) is *not*
deprecated and still works as documented: `appVersion` does not determine the published tag, so
pinning it cannot overwrite a release.

### override_app_version (optional boolean, default=true)

When `true` (the default), passes `--override-app-version` to App Build Suite, stamping the
chart's `appVersion` field with the value computed by `gitsemver` (or read from the
`.build_version` workspace file). Set to `false` to leave the `appVersion` field in `Chart.yaml`
unchanged.

### comment_on_pr (optional boolean, default=true)

When `true` (the default), the job posts a comment on the pull request stating the chart name and
version it published, together with the OCI reference, the digest, a `helm pull` command and a link
to the git catalog. On subsequent pushes the same comment is updated in place, identified by a
hidden HTML marker keyed on the `chart` parameter — so a repository publishing several charts gets
one comment per chart.

Set to `false` to disable it.

Requires the `CircleCI architect` GitHub App to hold `Pull requests: write` on the repository. Every
failure path — no pull request yet, a forked pull request, a missing App permission, a rate limit —
logs a warning and leaves the build green; the chart has already been published by the time this
runs. See [Reporting the published version on a pull
request](#reporting-the-published-version-on-a-pull-request) for the prerequisites and limitations.
