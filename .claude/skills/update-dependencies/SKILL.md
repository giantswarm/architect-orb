---
description: Process for updating dependencies as far as possible without code changes
---

When initiated by the user, follow the procedure in this skill.

The goal is to update several related dependencies.

The user may give you the URL of a PR where several dependencies are being upgraded. If the checks in that PR succeed, there is nothing to do right now.

If in that PR, checks are failing, it's likely that the new dependency versions introduce API changes incompatible with the code in the project. In that case we try to upgrade the depencies only as far as possible, while keeping our code base unchanged otherwise.

If, for example, the PR attempts to upgrade a dependency

   github.com/giantswarm/kubeconfig

from v1.1.1 to v1.2.0, we have to check whether there were other compatible versions in-between that we could upgrade to.

A good way to get the release history for a Go module is pkg.go.dev. For example, for `github.com/giantswarm/kubeconfig`, we can access the release history at https://pkg.go.dev/github.com/giantswarm/kubeconfig?tab=versions . If you know better or faster programmatic ways, use your own poison.

It's best to test versions step by step. In each step, update the direct dependency version in `go.mod`, then run `go mod tidy`, then `go build`. If that succeeds, we can be pretty sure the dependency is compatible. We don't need to execute tests in every step.

Only finally we verify the result be executing `go test ./...`.
