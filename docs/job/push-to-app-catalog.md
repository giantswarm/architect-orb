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

### attach_workspace

When this is `true`, the CircleCI `attach_workspace` command will be executed
immediately after `checkout` into the working directory. Use this if files are
generated/modified in a previous workflow job and need to be used in this job.

### on_tag (optional boolean, default=true)

When this is `false`, commits to `master` will be pushed to `app_catalog`
instead of `app_catalog_test`. Set this to `false` for deployments that follow
a a master branch for production releases rather than using tags (the default).

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
          requires:
            # Make sure docker image is successfully built.
            - push-REPOSITORY-to-quay
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```
