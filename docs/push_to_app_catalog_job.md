# push-to-app-catalog job

This job pushes the app to the specified catalog.
Before doing that, it runs some validations.

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
