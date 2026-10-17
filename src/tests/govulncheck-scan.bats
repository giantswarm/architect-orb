#!/usr/bin/env bats
# Tests of src/scripts/govulncheck-scan.sh: a clean scan passes, a reachable
# vulnerability fails the step, a scan that could not run fails the step, and
# `.govulncheck-ignore` excludes reviewed findings until their date.
# The script runs as CircleCI runs a step, under `bash -eo pipefail`.
# govulncheck is a stub on the PATH: it prints GOVULNCHECK_OUTPUT (a JSON
# stream), exits with GOVULNCHECK_EXIT and records its arguments.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/govulncheck-scan.sh"
  export GOVULNCHECK_RESULTS="${BATS_TEST_TMPDIR}/results.json"
  export GOVULNCHECK_TEST_RESULTS_DIR="${BATS_TEST_TMPDIR}/test-results"
  export GOVULNCHECK_IGNORE="${BATS_TEST_TMPDIR}/govulncheck-ignore"
  export GOVULNCHECK_TODAY="2026-10-15"
  export GOVULNCHECK_ARGS="${BATS_TEST_TMPDIR}/govulncheck.args"
  export GOVULNCHECK_EXIT=0
  JUNIT="${GOVULNCHECK_TEST_RESULTS_DIR}/govulncheck.xml"

  SBOM='{"SBOM":{"modules":[{"path":"example.com/app"},{"path":"golang.org/x/net","version":"v0.58.0"},{"path":"golang.org/x/crypto","version":"v0.56.0"}]}}'
  OSV_NET='{"osv":{"id":"GO-2026-6603","aliases":["CVE-2026-1111"]}}'
  OSV_CRYPTO='{"osv":{"id":"GO-2026-5932","aliases":[]}}'
  CALLED_NET='{"finding":{"osv":"GO-2026-6603","fixed_version":"v0.60.0","trace":[{"module":"golang.org/x/net","version":"v0.58.0","package":"golang.org/x/net/html","function":"Parse"}]}}'
  IMPORTED_CRYPTO='{"finding":{"osv":"GO-2026-5932","trace":[{"module":"golang.org/x/crypto","version":"v0.56.0","package":"golang.org/x/crypto/openpgp"}]}}'
  CALLED_CRYPTO='{"finding":{"osv":"GO-2026-5932","trace":[{"module":"golang.org/x/crypto","version":"v0.56.0","package":"golang.org/x/crypto/openpgp","function":"init"}]}}'
  export GOVULNCHECK_OUTPUT="${SBOM}"

  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/govulncheck" <<'STUB'
#!/bin/bash
echo "$*" > "${GOVULNCHECK_ARGS}"
if [[ "${GOVULNCHECK_EXIT}" -ne 0 ]]; then
  echo "creating client: unrecognized vulndb format" >&2
  exit "${GOVULNCHECK_EXIT}"
fi
echo "${GOVULNCHECK_OUTPUT}"
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/govulncheck"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "a clean scan passes, says how many modules it checked and records a passed test" {
  run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"govulncheck checked 3 modules against https://vuln.go.dev"* ]]
  [[ "$output" == *"No reachable known vulnerability."* ]]
  [[ "$(cat "${GOVULNCHECK_ARGS}")" == "-format json -db https://vuln.go.dev ./..." ]]
  grep -q 'failures="0"' "${JUNIT}"
  ! grep -q '<failure' "${JUNIT}"
}

@test "a vulnerability in an imported package the code does not call passes" {
  GOVULNCHECK_OUTPUT="${SBOM} ${OSV_CRYPTO} ${IMPORTED_CRYPTO}" run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -q 'failures="0"' "${JUNIT}"
}

@test "a reachable vulnerability fails the step and names its fix" {
  GOVULNCHECK_OUTPUT="${SBOM} ${OSV_NET} ${CALLED_NET} ${OSV_CRYPTO} ${CALLED_CRYPTO}" run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"reaches 2 known vulnerabilities"* ]]
  [[ "$output" == *"GO-2026-6603  golang.org/x/net@v0.58.0  fixed in: v0.60.0"* ]]
  [[ "$output" == *"GO-2026-5932  golang.org/x/crypto@v0.56.0  fixed in: no fix"* ]]
  grep -q '<failure message="the code reaches 2 known vulnerabilities"' "${JUNIT}"
}

@test "a scan that could not run fails the step and says nothing was scanned" {
  GOVULNCHECK_DB="https://vulndb.invalid" GOVULNCHECK_EXIT=1 run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT SCANNED: govulncheck could not check the code (exit code 1)"* ]]
  [[ "$(cat "${GOVULNCHECK_ARGS}")" == *"-db https://vulndb.invalid"* ]]
  grep -q '<failure message="NOT SCANNED' "${JUNIT}"
}

@test "an ignore entry by ID or alias excludes a finding until its date" {
  printf '%s\n' '# reviewed' 'GO-2026-5932 until=2026-12-31  # no fix upstream' 'CVE-2026-1111 until=2026-10-15' > "${GOVULNCHECK_IGNORE}"
  GOVULNCHECK_OUTPUT="${SBOM} ${OSV_NET} ${CALLED_NET} ${OSV_CRYPTO} ${CALLED_CRYPTO}" run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -q 'failures="0"' "${JUNIT}"
}

@test "an expired or undated ignore entry no longer applies" {
  printf '%s\n' 'GO-2026-5932 until=2026-10-14' 'GO-2026-6603' > "${GOVULNCHECK_IGNORE}"
  GOVULNCHECK_OUTPUT="${SBOM} ${OSV_NET} ${CALLED_NET} ${OSV_CRYPTO} ${CALLED_CRYPTO}" run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ignoring GO-2026-5932: expired on 2026-10-14"* ]]
  [[ "$output" == *"ignoring GO-2026-6603: no until= date"* ]]
  [[ "$output" == *"reaches 2 known vulnerabilities"* ]]
}
