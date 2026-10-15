#!/bin/bash
# go-test: scan the Go dependencies for known vulnerabilities with nancy.
#
# Tunables, for the tests:
#   NANCY_RESULTS           the scan log, /tmp/nancy-results.txt by default
#   NANCY_TEST_RESULTS_DIR  where the JUnit result goes, /tmp/nancy-test-results by default
#   NANCY_CACHE_DIR         nancy's response cache, ~/.cache/nancy by default
#   NANCY_CACHE_STATE       the checksum of that cache after the scan, the save key's last part,
#                           /tmp/nancy-cache-state by default
#
# The scan log stays out of the working tree: this step runs between
# `make test` and the binary link, and a stray untracked file in the repo makes
# Go's buildvcs stamp `vcs.modified=true`, so release binaries would report
# `vX.Y.Z+dirty`.
#
# A scan that fails because the external scanner cannot answer (an OSS Index
# or Sonatype Guide outage, a rate limit, an exhausted credit quota) does not
# fail the build, so an unrelated pull request is not blocked by it. It is
# never reported as a scan either: the step says that no dependency was
# scanned, and the JUnit result records a failed test, which the job's Tests
# tab and CircleCI's test insights show while the job stays green.
# CircleCI runs the step with `-eo pipefail`; nancy's exit code is evaluated
# below, so a failing scan must not end the script.
set +e -uo pipefail

results="${NANCY_RESULTS:-/tmp/nancy-results.txt}"
junit_dir="${NANCY_TEST_RESULTS_DIR:-/tmp/nancy-test-results}"
cache_dir="${NANCY_CACHE_DIR:-$HOME/.cache/nancy}"
cache_state="${NANCY_CACHE_STATE:-/tmp/nancy-cache-state}"

write_junit() {
  local failures="$1" message="$2"
  mkdir -p "$junit_dir"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo "<testsuites><testsuite name=\"nancy\" tests=\"1\" failures=\"${failures}\">"
    echo '<testcase classname="nancy" name="Go dependencies are scanned for known vulnerabilities">'
    if [[ "$failures" -ne 0 ]]; then
      echo "<failure message=\"${message}\"/>"
    fi
    echo '</testcase></testsuite></testsuites>'
  } > "$junit_dir/nancy.xml"
}

go list -json -deps ./... \
  | nancy sleuth --skip-update-check \
    --db-cache-path "$cache_dir" \
    --quiet --exclude-vulnerability-file ./.nancy-ignore \
    --additional-exclude-vulnerability-files ./.nancy-ignore.generated 2>&1 \
  | tee "$results"
nancy_result=${PIPESTATUS[1]}

# The cache is saved under a key that ends in its checksum: a scan that added
# reports saves a new cache, one that added none (or could not run) saves
# nothing new, so an empty cache never takes a window's key.
cat "$cache_dir"/* 2>/dev/null | sha256sum > "$cache_state"

if [[ "$nancy_result" -eq 0 ]]; then
  write_junit 0 ""
  exit 0
fi

if ! grep -qF \
    -e 'error accessing OSS Index' \
    -e 'Error: guide API request failed' \
    -e 'rate limited by OSS Index' \
    "$results"; then
  write_junit 1 "nancy found vulnerable dependencies or failed (exit code ${nancy_result})"
  exit "$nancy_result"
fi

# The Sonatype Guide client decodes an error answer (HTTP 400, 401, 402, 500)
# as a component report, so an exhausted credit quota or rejected credentials
# read as this decode error rather than as their status.
reason="the external scanner could not answer"
if grep -qF 'cannot unmarshal object into Go value of type []sonatypeguide.ComponentReportPost' "$results"; then
  reason="the Sonatype Guide API answered with an error instead of a report (an exhausted credit quota or rejected credentials)"
fi

echo
echo "NOT SCANNED: no Go dependency was checked for known vulnerabilities: ${reason}."
echo "The build is not failed for a scanner outage. The JUnit result records the missing scan."
write_junit 1 "NOT SCANNED: ${reason}"
exit 0
