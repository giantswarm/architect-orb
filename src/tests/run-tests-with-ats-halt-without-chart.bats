#!/usr/bin/env bats
# Tests of src/scripts/run-tests-with-ats-halt-without-chart.sh: the chart tests
# end, successfully, when the gated job that packages the chart left no archive
# in the workspace, and run when it did. circleci-agent is a stand-in on PATH
# that records the arguments it was called with.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/run-tests-with-ats-halt-without-chart.sh"
  export PARAM_CHART_ARCHIVE_PREFIX="agent"
  cd "${BATS_TEST_TMPDIR}" || exit 1
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

@test "a workspace without the chart archive ends the job" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${AGENT_CALLS}")" = "step halt" ]
}

@test "a workspace with the chart archive runs the tests" {
  touch build/agent-1.2.3.tgz
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -e "${AGENT_CALLS}" ]
}

@test "an archive of another chart does not count" {
  touch build/other-1.2.3.tgz
  run bash "${SCRIPT}"
  [ "$(cat "${AGENT_CALLS}")" = "step halt" ]
}
