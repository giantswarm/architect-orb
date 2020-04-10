# Common

This page contains documentation for common parts of all jobs defined in
architect orb.



## Parameters

### `resource_class` (optional string, default="medium")

Allows specifying [CircleCI `resource_class`] for the job if the default is not
sufficient. Note that there are differences between [docker executers] and [machine executors] and that the resource class has an effect on [credits pricing]. 



[CircleCI `resource_class`]: https://circleci.com/docs/2.0/configuration-reference/#resource_class
[credits pricing]: https://circleci.com/pricing/#compute-options-table
[docker executers]: https://circleci.com/docs/2.0/configuration-reference/#docker-executor
[machine executors]: https://circleci.com/docs/2.0/configuration-reference/#machine-executor-linux

