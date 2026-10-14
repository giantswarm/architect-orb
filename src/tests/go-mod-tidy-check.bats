#!/usr/bin/env bats
# Tests of src/scripts/go-mod-tidy-check.sh: a transient `go mod tidy` failure
# is retried, a tidy that keeps failing or leaves a diff fails the step.
# go and git are stubs on the PATH: go fails its first GO_FAILS calls, git
# exits with GIT_DIFF_EXIT; both record each call in a log of their own.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/go-mod-tidy-check.sh"
  export GO_MOD_TIDY_BACKOFF=0
  export GO_LOG="${BATS_TEST_TMPDIR}/go.log"
  export GIT_LOG="${BATS_TEST_TMPDIR}/git.log"
  : > "${GO_LOG}"
  : > "${GIT_LOG}"
  export GO_FAILS=0
  export GIT_DIFF_EXIT=0

  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/go" <<'STUB'
#!/bin/bash
echo "$*" >> "${GO_LOG}"
if (( $(wc -l < "${GO_LOG}") <= GO_FAILS )); then
  echo 'read "https://proxy.golang.org/cached-only/github.com/onsi/gomega/@v/v1.39.0.zip": stream error: stream ID 19; INTERNAL_ERROR; received from peer' >&2
  exit 1
fi
STUB
  cat > "${BATS_TEST_TMPDIR}/bin/git" <<'STUB'
#!/bin/bash
echo "$*" >> "${GIT_LOG}"
exit "${GIT_DIFF_EXIT}"
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/go" "${BATS_TEST_TMPDIR}/bin/git"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "a tidy module passes on the first attempt" {
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(cat "${GO_LOG}")" = "mod tidy" ]
  [ "$(cat "${GIT_LOG}")" = "diff --exit-code" ]
}

@test "a transient proxy error is retried and passes" {
  GO_FAILS=2 run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${GO_LOG}")" -eq 3 ]
  [[ "$output" == *"attempt 1 of 3"* ]]
  [[ "$output" == *"attempt 2 of 3"* ]]
  [ "$(cat "${GIT_LOG}")" = "diff --exit-code" ]
}

@test "a tidy that keeps failing fails after three attempts" {
  GO_FAILS=3 run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ "$(wc -l < "${GO_LOG}")" -eq 3 ]
  [[ "$output" == *"failed 3 times"* ]]
  [ ! -s "${GIT_LOG}" ]
}

@test "an untidy go.mod or go.sum fails without a retry" {
  GIT_DIFF_EXIT=1 run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ "$(wc -l < "${GO_LOG}")" -eq 1 ]
}

@test "GO_MOD_TIDY_ATTEMPTS bounds the attempts" {
  GO_FAILS=5 GO_MOD_TIDY_ATTEMPTS=5 run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ "$(wc -l < "${GO_LOG}")" -eq 5 ]
}
