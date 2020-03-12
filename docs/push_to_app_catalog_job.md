# push-to-app-catalog job

## Parameters

### attach_workspace (optional boolean, default=false)

When this is `true`, the CircleCI `attach_workspace` command will be executed
immediately after `checkout` into the working directory. Use this if files are
generated/modified in a previous workflow job and need to be used in this job.

### on_tag (optional boolean, default=true)

When this is `false`, commits to `master` will be pushed to `app_catalog`
instead of `app_catalog_test`. Set this to `false` for deployments that follow
a a master branch for production releases rather than using tags (the default).
