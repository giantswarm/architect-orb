#!/usr/bin/env bats
# Tests of src/scripts/run-tests-with-ats-skip-release-commit.sh: whether the
# chart tests end, successfully, before testing. They end on a branch pipeline
# at a release-tagged commit that left no chart archive in the workspace, and
# run in every other case. circleci-agent is a stand-in on PATH that records
# the arguments it was called with.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/run-tests-with-ats-skip-release-commit.sh"
  export PARAM_CHART_ARCHIVE_PREFIX="agent"
  unset CIRCLE_TAG

  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=architect GIT_AUTHOR_EMAIL=architect@example.com
  export GIT_COMMITTER_NAME=architect GIT_COMMITTER_EMAIL=architect@example.com
  REPO="${BATS_TEST_TMPDIR}/repo"
  git init -q -b main "${REPO}"
  cd "${REPO}" || exit 1
  git commit -q --allow-empty -m "release"
  mkdir build

  AGENT_CALLS="${BATS_TEST_TMPDIR}/circleci-agent.calls"
  export AGENT_CALLS
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/circleci-agent" <<'AGENT'
#!/bin/bash
echo "$*" >> "${AGENT_CALLS}"
AGENT
  chmod +x "${BATS_TEST_TMPDIR}/bin/circleci-agent"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

halted() {
  [ "$(cat "${AGENT_CALLS}" 2>/dev/null)" = "step halt" ]
}

@test "a branch pipeline at an rc-tagged commit without a chart ends the job" {
  git tag v2.0.3-rc.7
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  halted
  [[ "${output}" == *"release tag(s) v2.0.3-rc.7 and no chart was built"* ]]
}

@test "a branch pipeline at a mono repo's tagged commit without a chart ends the job" {
  git tag api/v1.0.0
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  halted
}

@test "a branch pipeline with a chart archive tests it" {
  git tag v2.0.3
  touch build/agent-2.0.3.tgz
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  ! halted
}

@test "a branch pipeline without a chart and without a release tag tests (and fails there)" {
  git tag some-marker
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  ! halted
}

@test "a tag pipeline tests" {
  git tag v2.0.3
  export CIRCLE_TAG=v2.0.3
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  ! halted
}
