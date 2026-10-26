# Common

This page contains documentation for common parts of all jobs defined in
architect orb.



## Parameters

### `resource_class` (optional string, default="medium")

Allows specifying [CircleCI `resource_class`] for the job if the default is not
sufficient. Note that there are differences between [docker executors] and [machine executors] and that the resource class has an effect on [credits pricing]. 



### `require_open_pull_request` (optional boolean, default=false)

The gate only works if a pipeline runs when the pull request opens; see the
`trigger-circleci-pipeline` workflow in giantswarm/github-workflows. The
`integration-test` job has no such parameter, so it is not gated.

Carried by `build-image`, `push-to-registries` and `push-to-app-catalog`. When
`true`, the job halts before it does anything unless an open pull request
covers the commit being built, so a push to a scratch branch produces no image
and no chart and costs only the executor spin-up. A branch that is under review
builds on every push, because that is what a reviewer — or a management cluster
reserved against that branch — follows.

The pull request being open is the whole rule. There is no label and no branch
prefix.

Notes:

- **Tag builds are exempt.** A tag has no pull request to find.
- **The gate fails open.** A missing token, a GitHub outage or a rate limit
  builds the commit and says so in the log. A spare build wastes minutes; a
  missed one leaves a reviewer with no chart.
- **Set it on every job you want gated.** `circleci-agent step halt` ends a job
  *successfully*, and a halted job does not skip the jobs that `require` it.
- **Needs `context: architect`** to reach the GitHub API. Without a token the
  gate opens, which is also how forked pull requests keep building: CircleCI
  withholds the context there, and `CIRCLE_PULL_REQUEST` answers instead.

`run-tests-with-ats` takes a parameter of the same name with different
mechanics — see [its page](run-tests-with-ats.md).


[CircleCI `resource_class`]: https://circleci.com/docs/2.0/configuration-reference/#resource_class
[credits pricing]: https://circleci.com/pricing/#compute-options-table
[docker executors]: https://circleci.com/docs/2.0/configuration-reference/#docker-executor
[machine executors]: https://circleci.com/docs/2.0/configuration-reference/#machine-executor-linux

