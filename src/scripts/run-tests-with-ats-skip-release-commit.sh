#!/bin/bash
# architect/run-tests-with-ats: end the job, successfully, when the job that
# should have built the chart skipped a release commit.
#
# Inputs, set by the command from its parameters:
#   PARAM_CHART_ARCHIVE_PREFIX  prefix of the chart archive in build/
# CircleCI's own:
#   CIRCLE_TAG                  the tag a tag pipeline was triggered by; empty
#                               on a branch pipeline
#
# A branch pipeline at a commit carrying a release tag builds nothing:
# image-prepare-tag ends the chart job there, as a success, so its status on
# the release commit stays green (src/scripts/image-prepare-tag.sh). The tests
# that require that job then start with no chart archive in the workspace, and
# would fail on the release commit in its place. They end here instead, under
# the same three conditions: a branch pipeline, no chart archive, and a release
# tag (`[<prefix>/]vX.Y.Z[-pre]`) on the checked-out commit. Any other missing
# archive is left to fail the test step, as before.
set -euo pipefail

if [[ -n "${CIRCLE_TAG:-}" ]]; then
  exit 0
fi
if [[ -n "$(find build -name "${PARAM_CHART_ARCHIVE_PREFIX}*.tgz" -print -quit 2>/dev/null)" ]]; then
  exit 0
fi
release_tags="$(git tag --points-at HEAD | grep -E '(^|/)v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' || true)"
if [[ -z "${release_tags}" ]]; then
  exit 0
fi

echo "NOTE: this branch pipeline's commit carries the release tag(s) ${release_tags//$'\n'/, } and no chart was built for it;"
echo "the job that builds the chart skips a release commit, so there is nothing to test. This job ends here, successfully."
echo "The release is built and published by its tag's own pipeline."
circleci-agent step halt
