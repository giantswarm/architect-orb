#!/usr/bin/env bats
# Tests of src/scripts/determine-catalog-name.sh: the catalog a chart is pushed
# to for a release tag, a pre-release tag and a branch build, with on_tag true
# and false.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/determine-catalog-name.sh"
  export PARAM_APP_CATALOG=giantswarm-catalog PARAM_APP_CATALOG_TEST=giantswarm-test-catalog
  export PARAM_ON_TAG=true
  export CIRCLE_BRANCH=main CIRCLE_SHA1=0123abc
  unset CIRCLE_TAG
  cd "${BATS_TEST_TMPDIR}" || exit 1
}

catalog() {
  cat .app_catalog_name
}

reference() {
  cat .reference
}

@test "a release tag goes to the production catalog" {
  export CIRCLE_TAG=v1.2.3
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(catalog)" = giantswarm-catalog ]
  [ "$(reference)" = v1.2.3 ]
}

@test "a release candidate tag goes to the test catalog" {
  export CIRCLE_TAG=v1.3.0-rc.1
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(catalog)" = giantswarm-test-catalog ]
  [ "$(reference)" = v1.3.0-rc.1 ]
  [[ "${output}" == *"The tag v1.3.0-rc.1 is a pre-release"* ]]
}

@test "any pre-release goes to the test catalog" {
  for tag in v1.3.0-alpha.1 v1.3.0-beta.2 1.3.0-rc.1 v1.3.0-rc.1+build.5; do
    export CIRCLE_TAG="${tag}"
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(catalog)" = giantswarm-test-catalog ]
  done
}

@test "build metadata alone is no pre-release" {
  export CIRCLE_TAG=v1.2.3+build.5
  run bash "${SCRIPT}"
  [ "$(catalog)" = giantswarm-catalog ]
}

@test "a mono repo's prefixed tags follow the version after the prefix" {
  export CIRCLE_TAG=api/v2.0.0
  run bash "${SCRIPT}"
  [ "$(catalog)" = giantswarm-catalog ]
  export CIRCLE_TAG=api/v2.0.0-rc.1
  run bash "${SCRIPT}"
  [ "$(catalog)" = giantswarm-test-catalog ]
}

@test "a prefix with a dash does not make a release a pre-release" {
  export CIRCLE_TAG=my-api/v2.0.0
  run bash "${SCRIPT}"
  [ "$(catalog)" = giantswarm-catalog ]
}

@test "a branch build goes to the test catalog with an empty reference" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(catalog)" = giantswarm-test-catalog ]
  [ -z "$(reference)" ]
}

@test "on_tag false: master goes to the production catalog" {
  export PARAM_ON_TAG=false CIRCLE_BRANCH=master
  run bash "${SCRIPT}"
  [ "$(catalog)" = giantswarm-catalog ]
  [ "$(reference)" = 0123abc ]
}

@test "on_tag false: another branch goes to the test catalog" {
  export PARAM_ON_TAG=false CIRCLE_BRANCH=feature
  run bash "${SCRIPT}"
  [ "$(catalog)" = giantswarm-test-catalog ]
  [ "$(reference)" = 0123abc ]
}
