#!/bin/bash
# architect/run-tests-with-ats: end the job, successfully, when the gated job
# that packages the chart left no chart archive in the workspace.
#
# Inputs, set by the command from its parameters:
#   PARAM_CHART_ARCHIVE_PREFIX  prefix of the chart archive in build/
set -euo pipefail

if [[ -n "$(find build -name "${PARAM_CHART_ARCHIVE_PREFIX}*.tgz" -print -quit 2>/dev/null)" ]]; then
  exit 0
fi
echo "No chart archive in the workspace: the job that packages it was skipped because no open pull request covers this commit."
circleci-agent step halt
