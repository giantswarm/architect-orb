#!/usr/bin/env bats
# Tests of src/scripts/nancy-scan.sh: a clean scan passes, vulnerable
# dependencies fail the step, and a scanner outage passes the step while it
# says that nothing was scanned and records a failed JUnit test.
# go and nancy are stubs on the PATH: nancy prints NANCY_OUTPUT, exits with
# NANCY_EXIT and records its arguments.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/nancy-scan.sh"
  export NANCY_RESULTS="${BATS_TEST_TMPDIR}/nancy-results.txt"
  export NANCY_TEST_RESULTS_DIR="${BATS_TEST_TMPDIR}/test-results"
  export NANCY_CACHE_DIR="${BATS_TEST_TMPDIR}/cache"
  export NANCY_ARGS="${BATS_TEST_TMPDIR}/nancy.args"
  export NANCY_OUTPUT="Audited Dependencies 237"
  export NANCY_EXIT=0
  JUNIT="${NANCY_TEST_RESULTS_DIR}/nancy.xml"

  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/go" <<'STUB'
#!/bin/bash
echo '{"ImportPath": "example.com/stub"}'
STUB
  cat > "${BATS_TEST_TMPDIR}/bin/nancy" <<'STUB'
#!/bin/bash
cat > /dev/null
echo "$*" > "${NANCY_ARGS}"
echo "${NANCY_OUTPUT}"
exit "${NANCY_EXIT}"
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/go" "${BATS_TEST_TMPDIR}/bin/nancy"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "a clean scan passes and records a passed test" {
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Audited Dependencies 237"* ]]
  [[ "$(cat "${NANCY_ARGS}")" == *"--db-cache-path ${NANCY_CACHE_DIR}"* ]]
  grep -q 'failures="0"' "${JUNIT}"
  ! grep -q '<failure' "${JUNIT}"
}

@test "vulnerable dependencies fail the step" {
  NANCY_OUTPUT="Vulnerable Dependencies 1" NANCY_EXIT=1 run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" != *"NOT SCANNED"* ]]
  grep -q 'failures="1"' "${JUNIT}"
}

@test "an exhausted Sonatype Guide quota passes the step but says nothing was scanned" {
  NANCY_OUTPUT="Error: guide API request failed: json: cannot unmarshal object into Go value of type []sonatypeguide.ComponentReportPost" \
    NANCY_EXIT=1 run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT SCANNED: no Go dependency was checked"* ]]
  [[ "$output" == *"exhausted credit quota"* ]]
  grep -q '<failure message="NOT SCANNED' "${JUNIT}"
}

@test "an OSS Index rate limit passes the step but says nothing was scanned" {
  NANCY_OUTPUT="Error: You have been rate limited by OSS Index." NANCY_EXIT=1 run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT SCANNED"* ]]
  [[ "$output" == *"the external scanner could not answer"* ]]
  grep -q '<failure message="NOT SCANNED' "${JUNIT}"
}
