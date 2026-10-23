#!/bin/bash
# architect/pin-version: resolve the pipeline's version once and record it for
# every later job of the workflow.
#
# Inputs, set by the command from its parameters:
#   PARAM_GIT_TAG_PREFIX  tag prefix of a mono repo, "" on a single-project repo
#
# Writes the version `gitsemver get` resolves to .pipeline_version (with a tag
# prefix: .pipeline_version-<prefix>), which the command persists to the
# workspace. image-prepare-tag in a job that attaches the workspace takes the
# version from that file instead of resolving it again.
#
# `gitsemver get` builds a dev version on the most recent stable tag reachable
# from the commit, and every job fetches the tags anew when it checks out. A
# stable tag that lands while the workflow runs -- a promote tagging a commit
# the branch contains -- therefore moves the base between jobs: the image is
# tagged with one version and the chart that references it is stamped with
# another. One resolution at the start of the workflow keeps them equal.
#
# The file records the version as resolved, release versions included: the
# jobs that build with it apply image-prepare-tag's rule for a branch pipeline
# at a tagged commit to the pinned version.
set -euo pipefail

export GS_GIT_TAG_PREFIX="${PARAM_GIT_TAG_PREFIX}"

file=".pipeline_version"
if [[ -n "${PARAM_GIT_TAG_PREFIX}" ]]; then
  file="${file}-${PARAM_GIT_TAG_PREFIX}"
fi

version="$(gitsemver get | tr -d '\n')"
if [[ -z "${version}" ]]; then
  echo "ERROR: gitsemver get returned no version." >&2
  exit 1
fi

printf '%s' "${version}" > "${file}"
echo "${file}: ${version}"
