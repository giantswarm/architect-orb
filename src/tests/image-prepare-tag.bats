#!/usr/bin/env bats
# Tests of src/scripts/image-prepare-tag.sh: the version a pipeline resolves
# from a git repository, for a tag pipeline and for a branch pipeline, at a
# tagged commit and after one. Needs git and gitsemver, as the architect
# executor has them; a tag pipeline is CIRCLE_TAG set, a branch pipeline
# CIRCLE_TAG unset.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/image-prepare-tag.sh"
  export BASH_ENV="${BATS_TEST_TMPDIR}/bash_env"
  : > "${BASH_ENV}"
  export PARAM_GIT_TAG_PREFIX="" PARAM_TAG_SUFFIX=""
  export CIRCLE_BRANCH="changesets-ghcommit-temp/changeset-release/main"
  unset CIRCLE_TAG

  # A repository of this test's own: no user or system git configuration
  # (signing, hooks), a deterministic author, one commit tagged v1.2.3.
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=architect GIT_AUTHOR_EMAIL=architect@example.com
  export GIT_COMMITTER_NAME=architect GIT_COMMITTER_EMAIL=architect@example.com
  REPO="${BATS_TEST_TMPDIR}/repo"
  git init -q -b main "${REPO}"
  cd "${REPO}" || exit 1
  git commit -q --allow-empty -m "release"
  git tag v1.2.3
  rm -f /tmp/.docker_image_tag
}

teardown() {
  rm -f /tmp/.docker_image_tag
}

resolved_tag() {
  cat /tmp/.docker_image_tag
}

exported() {
  # The variable a later step sees after sourcing BASH_ENV.
  (. "${BASH_ENV}" && printf '%s' "${!1:-}")
}

@test "a branch pipeline at a tagged commit fails before writing the tag" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"branch pipeline resolved the release version 1.2.3"* ]]
  [[ "${output}" == *"triggered by the branch 'changesets-ghcommit-temp/changeset-release/main'"* ]]
  [ ! -e /tmp/.docker_image_tag ]
  [ -z "$(exported DOCKER_IMAGE_TAG)" ]
}

@test "a branch pipeline at an rc-tagged commit fails the same way" {
  git commit -q --allow-empty -m "candidate"
  git tag v1.3.0-rc.1
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"release version 1.3.0-rc.1"* ]]
  [ ! -e /tmp/.docker_image_tag ]
}

@test "a tag pipeline at the tagged commit resolves the release version" {
  export CIRCLE_TAG=v1.2.3
  unset CIRCLE_BRANCH
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "1.2.3" ]
  [ "$(resolved_tag)" = "1.2.3" ]
  [ "$(exported DOCKER_IMAGE_TAG)" = "1.2.3" ]
  [ "$(exported DOCKER_IMAGE_VERSION)" = "1.2.3" ]
  [ "$(exported GS_GIT_TAG_PREFIX)" = "" ]
}

@test "a branch pipeline one commit after the tag resolves a dev version" {
  git checkout -q -b feature/next
  git commit -q --allow-empty -m "next"
  export CIRCLE_BRANCH=feature/next
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  gitsemver validate --type dev "$(resolved_tag)"
  [ "$(exported DOCKER_IMAGE_TAG)" = "$(resolved_tag)" ]
  [ "$(exported DOCKER_IMAGE_VERSION)" = "$(resolved_tag)" ]
}

@test "tag-suffix is appended to the version" {
  export CIRCLE_TAG=v1.2.3 PARAM_TAG_SUFFIX=-debug
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(resolved_tag)" = "1.2.3-debug" ]
  [ "$(exported DOCKER_IMAGE_TAG)" = "1.2.3-debug" ]
  [ "$(exported DOCKER_IMAGE_VERSION)" = "1.2.3" ]
}

@test "git-tag-prefix selects the mono repo's tags and is exported" {
  git tag api/v2.0.0
  export CIRCLE_TAG=api/v2.0.0 PARAM_GIT_TAG_PREFIX=api
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(resolved_tag)" = "2.0.0" ]
  [ "$(exported GS_GIT_TAG_PREFIX)" = "api" ]
}

@test "a branch pipeline at a mono repo's tagged commit fails too" {
  git tag api/v2.0.0
  export PARAM_GIT_TAG_PREFIX=api
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"release version 2.0.0"* ]]
  [ ! -e /tmp/.docker_image_tag ]
}
