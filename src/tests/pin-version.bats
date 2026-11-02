#!/usr/bin/env bats
# Tests of src/scripts/pin-version.sh: the version a workflow pins at its
# start, and that image-prepare-tag builds with it after a promote moved the
# git state. Needs git and gitsemver, as the architect executor has them.

bats_require_minimum_version 1.5.0

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/pin-version.sh"
  PREPARE="${BATS_TEST_DIRNAME}/../scripts/image-prepare-tag.sh"
  export BASH_ENV="${BATS_TEST_TMPDIR}/bash_env"
  : > "${BASH_ENV}"
  export PARAM_GIT_TAG_PREFIX="" PARAM_TAG_SUFFIX=""
  unset CIRCLE_TAG

  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=architect GIT_AUTHOR_EMAIL=architect@example.com
  export GIT_COMMITTER_NAME=architect GIT_COMMITTER_EMAIL=architect@example.com
  REPO="${BATS_TEST_TMPDIR}/repo"
  git init -q -b main "${REPO}"
  cd "${REPO}" || exit 1
  git commit -q --allow-empty -m "release"
  git tag v1.2.3
  git commit -q --allow-empty -m "candidate"
  git checkout -q -b feature/next
  git commit -q --allow-empty -m "next"
  export CIRCLE_BRANCH=feature/next
  rm -f /tmp/.docker_image_tag
}

teardown() {
  rm -f /tmp/.docker_image_tag
}

@test "records the version gitsemver resolves" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat .pipeline_version)" = "$(gitsemver get)" ]
  [ "${output}" = ".pipeline_version: $(gitsemver get)" ]
}

@test "the image and the chart keep the pinned version when a promote lands mid-workflow" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  pinned="$(cat .pipeline_version)"
  [[ "${pinned}" == 1.2.4-* ]]
  # The image job, before the promote.
  run bash "${PREPARE}"
  [ "${status}" -eq 0 ]
  image="$(cat /tmp/.docker_image_tag)"
  # The promote: a stable tag on a commit the branch contains.
  git tag v1.3.0 main
  [[ "$(gitsemver get)" == 1.3.1-* ]]
  # The chart job, after it.
  run bash "${PREPARE}"
  [ "${status}" -eq 0 ]
  chart="$(cat /tmp/.docker_image_tag)"
  [ "${image}" = "${pinned}" ]
  [ "${chart}" = "${pinned}" ]
}

@test "a tag prefix names the file after the prefix" {
  git tag api/v2.0.0 main~1
  export PARAM_GIT_TAG_PREFIX=api
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -e .pipeline_version ]
  [[ "$(cat .pipeline_version-api)" == 2.0.1-* ]]
}

@test "records a release version as resolved" {
  git checkout -q main
  git tag v1.3.0
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat .pipeline_version)" = "1.3.0" ]
}
