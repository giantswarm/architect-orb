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

## Parameters

- [common parameters](common.md#parameters) shared in all jobs.
- [attach_workspace](#attach_workspace) (optional boolean, default=false)
- [executor](#executor-optional-deprecated) (optional, deprecated, only `app-build-suite` accepted)
- [chart](#chart) name of the directory containing the chart in `helm/`
- [on_tag](#on_tag-optional-boolean-defaulttrue) only push tagged commits to `app_catalog`
- [explicit_allow_chart_name_mismatch](#explicit_allow_chart_name_mismatch-optional-boolean-defaultfalse)
- [persist_chart_archive](#persist_chart_archive-boolean-defaultfalse)
- [push_to_appcatalog](#push_to_appcatalog-optional-boolean-defaulttrue)
- [push_to_oci_registry](#push_to_oci_registry-optional-boolean-defaulttrue)
- [sign](#sign-optional-boolean-defaulttrue)
- [override_chart_version](#override_chart_version-optional-boolean-defaulttrue)
- [override_app_version](#override_app_version-optional-boolean-defaulttrue)

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

### override_chart_version (optional boolean, default=true)

When `true` (the default), passes `--override-chart-version` to App Build Suite, stamping the
chart's `version` field with the value computed by `gitsemver` (or read from the `.build_version`
workspace file). Set to `false` to leave the `version` field in `Chart.yaml` unchanged.

### override_app_version (optional boolean, default=true)

When `true` (the default), passes `--override-app-version` to App Build Suite, stamping the
chart's `appVersion` field with the value computed by `gitsemver` (or read from the
`.build_version` workspace file). Set to `false` to leave the `appVersion` field in `Chart.yaml`
unchanged.
