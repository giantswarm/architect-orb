# package-and-push command

## Parameters

### production_branch (optional, default="")

When this is a non-empty string, commits on the given branch will be treated as production releases
and the helm chart will be pushed to `app_catalog` instead of `app_catalog_test`. Use this for deployments
that follow a trunk branch (usually `master`) for production releases rather than using tags.
