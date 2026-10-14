#!/bin/bash
# go-test: fail when go.mod or go.sum are not tidy.
#
# Tunables, for the tests:
#   GO_MOD_TIDY_ATTEMPTS  how often `go mod tidy` runs before the step fails, 3 by default
#   GO_MOD_TIDY_BACKOFF   seconds before the first retry, doubled after each, 10 by default
#
# `go mod tidy` downloads the test dependencies of every dependency, so a large
# module graph makes a transient module proxy error likely (`stream error ...
# INTERNAL_ERROR; received from peer` from proxy.golang.org). Such an error
# fails tidy itself with no code cause, so tidy is retried with backoff. A
# retry is safe: tidy writes go.mod and go.sum only once it succeeds, and the
# same inputs give the same result.
#
# An untidy module is no tidy failure: tidy succeeds, rewrites go.mod or
# go.sum, and `git diff --exit-code` fails the step on the first attempt.
set -euo pipefail

attempts="${GO_MOD_TIDY_ATTEMPTS:-3}"
delay="${GO_MOD_TIDY_BACKOFF:-10}"

attempt=1
until go mod tidy; do
  if (( attempt >= attempts )); then
    echo "go mod tidy failed ${attempts} times, giving up." >&2
    exit 1
  fi
  echo "go mod tidy failed (attempt ${attempt} of ${attempts}), retrying in ${delay}s." >&2
  sleep "${delay}"
  delay=$(( delay * 2 ))
  attempt=$(( attempt + 1 ))
done

git diff --exit-code
