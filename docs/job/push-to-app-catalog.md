# push-to-app-catalog

This job templates and packages a given `chart` from the helm directory and
pushes it to `app_catalog` for tagged builds and `app_catalog_test` otherwise.

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

## Validations

### conftest

We use [`conftest`](https://www.conftest.dev/) to validate that the manifests inside the Helm chart don't use features
that will be deprecated on future kubernetes releases.
This is done using these [rego policies](https://github.com/swade1987/deprek8ion).

The policies are evaluated using the **rendered kubernetes manifests in the Helm chart**.
If there are values files in the `ci` folder of the chart, they will be used to render the chart templates.

## Parameters

- [common parameters](common.md#parameters) shared in all jobs.
- [attach_workspace](#attach_workspace) (optional boolean, default=false)
- [executor](#executor-optional-either-architect-or-app-build-suite-defaultarchitect) (optional, either `architect` or `app-build-suite`, default=`architect`)
- [chart](#chart) name of the directory containing the chart in `helm/`
- [on_tag](#on_tag-optional-boolean-defaulttrue) only push tagged commits to `app_catalog`
- [explicit_allow_chart_name_mismatch](#explicit_allow_chart_name_mismatch-optional-boolean-defaultfalse)

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
