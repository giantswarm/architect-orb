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

This job assumes that App Catalog is hosted inside a suitable container
registry specified by `registry_url` parameter, e.g.
`giantswarmpublic.azurecr.io`. CircleCI environment variables (specified by
`username_envar` and `password_envar`) will be used by `helm` to sign in to
the registry.

You can read more about storing helm charts in OCI registries in the [helm
documentation](https://helm.sh/blog/storing-charts-in-oci/).

## Validations

### conftest

We use [`conftest`](https://www.conftest.dev/) to validate that the manifests inside the Helm chart don't use features
that will be deprecated on future kubernetes releases.
This is done using these [rego policies](https://github.com/swade1987/deprek8ion).

The policies are evaluated using the **rendered kubernetes manifests in the Helm chart**.
If there are values files in the `ci` folder of the chart, they will be used to render the chart templates.

In case you don't want to check for deprecated manifests, it is possible to skip `conftest` checking by setting parameter
[`skip_conftest_deprek8ion`](#skip_conftest_deprek8ion-optional-boolean-defaultfalse) to `true`.

## Parameters

- [common parameters](common.md#parameters) shared in all jobs.
- [attach_workspace](#attach_workspace) (optional boolean, default=false)
- [executor](#executor-optional-either-architect-or-app-build-suite-defaultarchitect) (optional, either `architect` or `app-build-suite`, default=`architect`)
- [chart](#chart) name of the directory containing the chart in `helm/`
- [on_tag](#on_tag-optional-boolean-defaulttrue) only push tagged commits to `app_catalog`
- [explicit_allow_chart_name_mismatch](#explicit_allow_chart_name_mismatch-optional-boolean-defaultfalse)
- [skip_conftest_deprek8ion](#skip_conftest_deprek8ion-optional-boolean-defaultfalse)
- [persist_chart_archive](#persist_chart_archive-boolean-defaultfalse)
- [push_to_appcatalog](#push_to_appcatalog-optional-boolean-defaulttrue)
- [push_to_oci_registry](#push_to_oci_registry-optional-boolean-defaultfalse)
- [registry_url](#registry_url-optional-string)
- [username_envar](#username_envar-optional-string)
- [password_envar](#password_envar-optional-string)

### attach_workspace

When this is `true`, the CircleCI `attach_workspace` command will be executed
immediately after `checkout` into the working directory. Use this if files are
generated/modified in a previous workflow job and need to be used in this job.

### on_tag (optional boolean, default=true)

When this is `false`, commits to `master` will be pushed to `app_catalog`
instead of `app_catalog_test`. Set this to `false` for deployments that follow
a a master branch for production releases rather than using tags (the default).

### executor (optional, either `architect` or `app-build-suite`, default=`architect`)

Enables users to select the executor and control whether metadata should be generated.
Selecting `app-build-suite` will execute chart linting, validating and packaging using
[app-build-suite](https://github.com/giantswarm/app-build-suite). This also enables
generation and publishing of metadata into the catalog.

### chart

Name of the directory containing the helm chart in the `helm/` directory. This should match
the name of the repository with an optional `-app` suffix.

### explicit_allow_chart_name_mismatch (optional boolean, default=false)

Should be used to allow chart name validation. Set to `true` to explicitly disable checking against the name of the repository with optional `-app` suffix.
This can be the case if the chart directory is generated during CI runs or when multiple charts reside in a single repository.

Does not have any effect if `executor: app-build-suite` is set.

### skip_conftest_deprek8ion (optional boolean, default=false)

Disable checking manifests against deprecated apiVersions using [deprek8ion](https://github.com/swade1987/deprek8ion) rules.

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
          context: "architect"
          name: "push-REPOSITORY-to-CATALOG-app-catalog"
          app_catalog: "CATALOG-catalog"
          app_catalog_test: "CATALOG-test-catalog"
          chart: "REPOSITORY"
          executor: "app-build-suite"
          requires:
            # Make sure docker image is successfully built.
            - push-REPOSITORY-to-quay
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```

### push_to_appcatalog (optional boolean, default=true)

When set to `true`, the packaged chart will be pushed to a classic GitHub app
catalog.

### push_to_oci_registry (optional boolean, default=false)

When set to `true`, the packaged chart will be pushed to the specified OCI
registry.

### registry_url (optional string)

Defaults to `giantswarmpublic.azurecr.io`.

Hostname (and subdomain if applies) of the OCI registry to push to. `oci://`
scheme is implied and should not be added to the URL.

### username_envar (optional string)

Defaults to `AZURE_CLIENTID`.

Specifies environment variable to use as OCI registry username.

### password_envar (optional string)

Defaults to `AZURE_CLIENTSECRET`.

Specifies environment variable to use as OCI registry password.
