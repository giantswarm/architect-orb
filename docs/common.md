# Common

This page contains documentation for common parts of all jobs defined in
architect orb.

## Parameters

### resource_class

Allows specifying [CircleCI `resource_class`] for the job if the default is not
sufficient. Note that it differs between docker and machine executors. Details
can be found there:

- https://circleci.com/docs/2.0/configuration-reference/#docker-executor
- https://circleci.com/docs/2.0/configuration-reference/#machine-executor-linux

[resource_class]: https://circleci.com/docs/2.0/configuration-reference/#resource_class
