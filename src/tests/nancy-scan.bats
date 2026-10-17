#!/usr/bin/env bats
# Tests of src/scripts/nancy-scan.sh: a clean scan passes, vulnerable
# dependencies fail the step, and a scanner outage passes the step while it
# says that nothing was scanned and records a failed JUnit test.
# The script runs as CircleCI runs a step, under `bash -eo pipefail`.
# go, nancy and curl are stubs on the PATH: nancy prints NANCY_OUTPUT, exits
# with NANCY_EXIT and records its arguments; curl answers CURL_STATUS with
# CURL_BODY and records its arguments and its stdin.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/nancy-scan.sh"
  export NANCY_RESULTS="${BATS_TEST_TMPDIR}/nancy-results.txt"
  export NANCY_TEST_RESULTS_DIR="${BATS_TEST_TMPDIR}/test-results"
  export NANCY_CACHE_DIR="${BATS_TEST_TMPDIR}/cache"
  export NANCY_CACHE_STATE="${BATS_TEST_TMPDIR}/cache-state"
  export NANCY_ARGS="${BATS_TEST_TMPDIR}/nancy.args"
  export NANCY_OUTPUT="Audited Dependencies 237"
  export NANCY_EXIT=0
  export CURL_ARGS="${BATS_TEST_TMPDIR}/curl.args"
  export CURL_STDIN="${BATS_TEST_TMPDIR}/curl.stdin"
  export CURL_STATUS=402
  export CURL_BODY='{"code":"CREDIT_LIMIT_EXCEEDED","message":"Insufficient credits for batch of 2 components (requires 0.2 credits, 0.1 available)","tier":"paid","resetDate":"2026-10-28","creditsRequired":0.2,"creditsRemaining":0.1}'
  export CURL_EXIT=0
  unset GUIDE_TOKEN OSSI_USERNAME OSSI_TOKEN OSSI_OSSINDEXURL OSSIndexURL
  GUIDE_ERROR="Error: guide API request failed: json: cannot unmarshal object into Go value of type []sonatypeguide.ComponentReportPost"
  JUNIT="${NANCY_TEST_RESULTS_DIR}/nancy.xml"

  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/go" <<'STUB'
#!/bin/bash
echo '{"ImportPath": "example.com/stub"}'
exit "${GO_EXIT:-0}"
STUB
  cat > "${BATS_TEST_TMPDIR}/bin/nancy" <<'STUB'
#!/bin/bash
cat > /dev/null
echo "$*" > "${NANCY_ARGS}"
echo "${NANCY_OUTPUT}"
exit "${NANCY_EXIT}"
STUB
  cat > "${BATS_TEST_TMPDIR}/bin/curl" <<'STUB'
#!/bin/bash
echo "$*" > "${CURL_ARGS}"
cat > "${CURL_STDIN}"
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then out="$2"; shift; fi
  shift
done
if [[ "${CURL_EXIT}" -ne 0 ]]; then
  printf '000'
  exit "${CURL_EXIT}"
fi
printf '%s' "${CURL_BODY}" > "${out}"
printf '%s' "${CURL_STATUS}"
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/go" "${BATS_TEST_TMPDIR}/bin/nancy" "${BATS_TEST_TMPDIR}/bin/curl"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "a clean scan passes and records a passed test" {
  run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Audited Dependencies 237"* ]]
  [[ "$(cat "${NANCY_ARGS}")" == *"--db-cache-path ${NANCY_CACHE_DIR}"* ]]
  grep -q 'failures="0"' "${JUNIT}"
  ! grep -q '<failure' "${JUNIT}"
  [ -s "${NANCY_CACHE_STATE}" ]
}

@test "vulnerable dependencies fail the step" {
  NANCY_OUTPUT="Vulnerable Dependencies 1" NANCY_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" != *"NOT SCANNED"* ]]
  grep -q 'failures="1"' "${JUNIT}"
}

@test "an exhausted Sonatype Guide quota passes the step but says nothing was scanned, with the status and the reset date" {
  GUIDE_TOKEN=guide-token-value NANCY_OUTPUT="${GUIDE_ERROR}" NANCY_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT SCANNED: no Go dependency was checked"* ]]
  [[ "$output" == *"Sonatype Guide answered HTTP 402 CREDIT_LIMIT_EXCEEDED: 0.1 credits left on the paid tier, the quota resets on 2026-10-28"* ]]
  grep -q '<failure message="NOT SCANNED: .*HTTP 402 CREDIT_LIMIT_EXCEEDED.*2026-10-28' "${JUNIT}"
  [ -s "${NANCY_CACHE_STATE}" ]
}

@test "the status check sends the credentials on curl's stdin, never on its command line" {
  GUIDE_TOKEN=guide-token-value OSSI_OSSINDEXURL=https://guide.example/ NANCY_OUTPUT="${GUIDE_ERROR}" NANCY_EXIT=1 \
    run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  ! grep -q guide-token-value "${CURL_ARGS}"
  grep -q 'https://guide.example/api/v3/component-report' "${CURL_ARGS}"
  grep -qF 'header = "Authorization: Bearer guide-token-value"' "${CURL_STDIN}"
}

@test "rejected OSS Index credentials name the status and the API's message" {
  OSSI_USERNAME=ci@example.com OSSI_TOKEN=ossi-token-value CURL_STATUS=401 CURL_BODY='{"code":401,"message":"Invalid credentials"}' \
    NANCY_OUTPUT="${GUIDE_ERROR}" NANCY_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT SCANNED"*"Sonatype Guide answered HTTP 401: Invalid credentials"* ]]
  grep -qF 'user = "ci@example.com:ossi-token-value"' "${CURL_STDIN}"
  ! grep -q ossi-token-value "${CURL_ARGS}"
}

@test "a Guide error without credentials says so" {
  NANCY_OUTPUT="${GUIDE_ERROR}" NANCY_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT SCANNED"*"no Sonatype Guide credentials are set"* ]]
  [ ! -e "${CURL_ARGS}" ]
}

@test "an unreachable Guide API after the error still says nothing was scanned" {
  GUIDE_TOKEN=guide-token-value CURL_EXIT=6 NANCY_OUTPUT="${GUIDE_ERROR}" NANCY_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT SCANNED"*"could not be reached to recover its answer"* ]]
  grep -q '<failure message="NOT SCANNED' "${JUNIT}"
}

@test "an OSS Index rate limit passes the step but says nothing was scanned" {
  NANCY_OUTPUT="Error: You have been rate limited by OSS Index." NANCY_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT SCANNED"* ]]
  [[ "$output" == *"the external scanner could not answer"* ]]
  grep -q '<failure message="NOT SCANNED' "${JUNIT}"
}

@test "a failing go list fails the step, nancy's empty pass is no scan" {
  GO_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 1 ]
  grep -q '<failure message="go list failed' "${JUNIT}"
}
