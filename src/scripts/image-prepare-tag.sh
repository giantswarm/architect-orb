#!/bin/bash
# architect/image-prepare-tag: compute the build version from git state.
#
# Inputs, set by the command from its parameters:
#   PARAM_GIT_TAG_PREFIX  tag prefix of a mono repo, "" on a single-project repo
#   PARAM_TAG_SUFFIX      appended to the version, "" by default
# CircleCI's own:
#   CIRCLE_TAG            the tag a tag pipeline was triggered by; empty on a
#                         branch pipeline
#   CIRCLE_BRANCH         the branch a branch pipeline was triggered by
#   BASH_ENV              the file every later step sources
#
# Writes /tmp/.docker_image_tag and exports DOCKER_IMAGE_TAG (the version plus
# the tag-suffix), DOCKER_IMAGE_VERSION (the version alone) and
# GS_GIT_TAG_PREFIX through BASH_ENV.
#
# The version is the one pin-version recorded for the workflow in
# .pipeline_version, when the job attached it from the workspace; otherwise
# `gitsemver get` resolves it. Either way the version comes from git state
# alone: at a commit carrying a release tag it is that release version, whichever ref the
# pipeline was triggered by. A release version is only ever published by the
# tag's own pipeline, so on a branch pipeline the version must be a dev
# version, and a release version there means the branch's head is a tagged
# commit -- a temporary branch a bot pushed at the release commit, a pull
# request opened from one, a rerun of a branch pipeline after the tag was cut.
# Every later step treats a release version as a release: the China mirror
# joins the push set, the tagged index and the chart are written again under
# the released version. This step ends the job instead, before anything is
# built, and ends it successfully (`circleci-agent step halt`): the branch
# pipeline posts its statuses on the tagged commit, under the same contexts as
# the tag's own pipeline, and a failure there would mark a green release as
# failed and keep it from being promoted.
set -euo pipefail

export GS_GIT_TAG_PREFIX="${PARAM_GIT_TAG_PREFIX}"
echo "export GS_GIT_TAG_PREFIX=\"${PARAM_GIT_TAG_PREFIX}\"" >> "${BASH_ENV}"

# A version pin-version resolved at the start of the workflow, attached from
# the workspace, wins: every job of the workflow then builds with the same
# version, even when a stable tag lands while it runs. Without the file the
# version is resolved here, from the git state of this job's checkout.
pinned=".pipeline_version"
if [[ -n "${PARAM_GIT_TAG_PREFIX}" ]]; then
  pinned="${pinned}-${PARAM_GIT_TAG_PREFIX}"
fi
if [[ -s "${pinned}" ]]; then
  version="$(tr -d '\n' < "${pinned}")"
  echo "Using the version pin-version resolved for this workflow (${pinned}): ${version}" >&2
else
  version="$(gitsemver get | tr -d '\n')"
fi
if [[ -z "${version}" ]]; then
  echo "ERROR: gitsemver get returned no version." >&2
  exit 1
fi

if [[ -z "${CIRCLE_TAG:-}" ]] && ! gitsemver validate --type dev "${version}" >/dev/null 2>&1; then
  cat <<EOF
NOTE: a branch pipeline resolved the release version ${version}; this job ends here, successfully, without building.

This pipeline was triggered by the branch '${CIRCLE_BRANCH:-}' (CIRCLE_TAG is empty),
but the branch's head carries the release tag for ${version}: gitsemver reads
the git state, not the trigger. A release version is published by the tag's own
pipeline alone. From here it would be pushed a second time -- the tagged image
index and the chart replaced under the released version, the China mirror
included -- so this job stops before anything is built, and stops green: its
status lands on the release commit next to the tag pipeline's.

Nothing is wrong with the release. If this branch needs an image or a chart of
its own, push a commit: the next commit after a tag resolves to a dev version.
EOF
  # Ends the job after this step, as a success. Without circleci-agent (outside
  # CircleCI) this fails, which still builds nothing.
  circleci-agent step halt
  exit 0
fi

tag="${version}${PARAM_TAG_SUFFIX}"
printf '%s' "${tag}" > /tmp/.docker_image_tag
echo "export DOCKER_IMAGE_TAG=\"${tag}\"" >> "${BASH_ENV}"
# The version without the suffix: what a sibling image of this pipeline, built
# without a tag-suffix, is tagged with. A Dockerfile that builds on that image
# takes it as a build argument (build-args: BASE_VERSION=${DOCKER_IMAGE_VERSION}).
echo "export DOCKER_IMAGE_VERSION=\"${version}\"" >> "${BASH_ENV}"
echo "${tag}"
