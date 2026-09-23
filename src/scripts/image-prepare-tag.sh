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
# Writes /tmp/.docker_image_tag and exports DOCKER_IMAGE_TAG and
# GS_GIT_TAG_PREFIX through BASH_ENV.
#
# The version comes from `gitsemver get`, which reads the git state alone: at
# a commit carrying a release tag it is that release version, whichever ref the
# pipeline was triggered by. A release version is only ever published by the
# tag's own pipeline, so on a branch pipeline the version must be a dev
# version, and a release version there means the branch's head is a tagged
# commit -- a temporary branch a bot pushed at the release commit, a pull
# request opened from one, a rerun of a branch pipeline after the tag was cut.
# Every later step treats a release version as a release: the China mirror
# joins the push set, the tagged index and the chart are written again under
# the released version. This step refuses instead, before anything is built.
set -euo pipefail

export GS_GIT_TAG_PREFIX="${PARAM_GIT_TAG_PREFIX}"
echo "export GS_GIT_TAG_PREFIX=\"${PARAM_GIT_TAG_PREFIX}\"" >> "${BASH_ENV}"

version="$(gitsemver get | tr -d '\n')"
if [[ -z "${version}" ]]; then
  echo "ERROR: gitsemver get returned no version." >&2
  exit 1
fi

if [[ -z "${CIRCLE_TAG:-}" ]] && ! gitsemver validate --type dev "${version}" >/dev/null 2>&1; then
  cat >&2 <<EOF
ERROR: a branch pipeline resolved the release version ${version}.

This pipeline was triggered by the branch '${CIRCLE_BRANCH:-}' (CIRCLE_TAG is empty),
but the branch's head carries the release tag for ${version}: gitsemver reads
the git state, not the trigger. A release version is published by the tag's own
pipeline alone. From here it would be pushed a second time -- the tagged image
index and the chart replaced under the released version, the China mirror
included -- so this build stops before anything is built.

Nothing is wrong with the release. If this branch needs an image or a chart of
its own, push a commit: the next commit after a tag resolves to a dev version.
EOF
  exit 1
fi

tag="${version}${PARAM_TAG_SUFFIX}"
printf '%s' "${tag}" > /tmp/.docker_image_tag
echo "export DOCKER_IMAGE_TAG=\"${tag}\"" >> "${BASH_ENV}"
echo "${tag}"
