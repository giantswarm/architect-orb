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
# nancy reads its Sonatype Guide credentials (GUIDE_TOKEN, or OSSI_USERNAME and
# OSSI_TOKEN) and its base URL (OSSI_OSSINDEXURL) from the job's context.
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
# Credentials that Sonatype Guide rejects (HTTP 401) are not an outage
# but a broken context, and fail the step.
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
      message=$(printf '%s' "$message" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g')
      echo "<failure message=\"${message}\"/>"
    fi
    echo '</testcase></testsuite></testsuites>'
  } > "$junit_dir/nancy.xml"
}

# nancy picks the same credentials in the same order as guide_error_reason.
guide_has_credentials() {
  [[ -n "${GUIDE_TOKEN:-}" || -n "${OSSI_USERNAME:-}" || -n "${OSSI_TOKEN:-}" ]]
}

# nancy's Sonatype Guide client (2.1.0 and 2.1.1) decodes the body of an HTTP
# 400, 401, 402 or 500 answer as a component report: a JSON object reads
# `cannot unmarshal object into Go value of type []sonatypeguide.ComponentReportPost`,
# a body that is not JSON reads `undefined response type` or a JSON syntax
# error, and only an empty body keeps the status (`401 Unauthorized`). Any other
# status is named whatever the body (`guide API request failed: 503 Service Unavailable`).
# One check of two dependencies with nancy's URL and credentials recovers the
# status and the API's reason: a refused check costs no credits, and one that
# is answered costs at most two dependencies' worth. The credentials reach curl
# on stdin, never on its command line.
# Sets guide_status (empty when unknown) and reason.
guide_error_reason() {
  local base="${OSSI_OSSINDEXURL:-${OSSIndexURL:-https://api.guide.sonatype.com}}"
  local auth body message
  guide_status=""
  if [[ -n "${GUIDE_TOKEN:-}" ]]; then
    auth="header = \"Authorization: Bearer ${GUIDE_TOKEN}\""
  elif [[ -n "${OSSI_USERNAME:-}" ]]; then
    auth="user = \"${OSSI_USERNAME}:${OSSI_TOKEN:-}\""
  elif [[ -n "${OSSI_TOKEN:-}" ]]; then
    auth="header = \"Authorization: Bearer ${OSSI_TOKEN}\""
  else
    reason="no Sonatype Guide credentials are set (GUIDE_TOKEN, or OSSI_USERNAME and OSSI_TOKEN)"
    return
  fi

  body=$(mktemp)
  guide_status=$(printf '%s\n' "$auth" | curl -sS --max-time 30 -K - -o "$body" -w '%{http_code}' \
    -X POST "${base%/}/api/v3/component-report" -H 'Content-Type: application/json' \
    -d '{"coordinates":["pkg:golang/golang.org/x/text@v0.3.8","pkg:golang/golang.org/x/net@v0.7.0"]}') || guide_status=""
  message=$(jq -r 'if type == "object" then (.message // .code // empty | tostring | gsub("\\s+"; " ")) else empty end' "$body" 2>/dev/null) || message=""

  case "$guide_status" in
    402)
      reason=$(jq -r 'if type == "object" then "Sonatype Guide answered HTTP 402 \(.code // "Payment Required"): \(.creditsRemaining // "no") credits left on the \(.tier // "unknown") tier, the quota resets on \(.resetDate // "an unknown date")" else empty end' \
        "$body" 2>/dev/null) || reason=""
      [[ -n "$reason" ]] || reason="Sonatype Guide answered HTTP 402 Payment Required${message:+: ${message}}"
      ;;
    2??)
      reason="Sonatype Guide answered a check of two dependencies, so its refusal of the scan was transient or specific to the scan's batch"
      ;;
    ""|000)
      guide_status=""
      reason="the Sonatype Guide API could not be reached to recover its answer"
      ;;
    *)
      reason="Sonatype Guide answered HTTP ${guide_status}${message:+: ${message}}"
      ;;
  esac
  rm -f "$body"
  [[ -n "$reason" ]] || reason="Sonatype Guide answered HTTP ${guide_status} without a reason"
}

go list -json -deps ./... \
  | nancy sleuth --skip-update-check \
    --db-cache-path "$cache_dir" \
    --quiet --exclude-vulnerability-file ./.nancy-ignore \
    --additional-exclude-vulnerability-files ./.nancy-ignore.generated 2>&1 \
  | tee "$results"
statuses=("${PIPESTATUS[@]}")
go_list_result=${statuses[0]}
nancy_result=${statuses[1]}

# The cache is saved under a key that ends in its checksum: a scan that added
# reports saves a new cache, one that added none (or could not run) saves
# nothing new, so an empty cache never takes a window's key.
cat "$cache_dir"/* 2>/dev/null | sha256sum > "$cache_state"

# Without the dependency list nancy audits nothing and passes.
if [[ "$go_list_result" -ne 0 ]]; then
  write_junit 1 "go list failed (exit code ${go_list_result}), no dependency was scanned"
  exit "$go_list_result"
fi

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

reason="the external scanner could not answer"
guide_status=""
# A status that nancy names is kept, except that a 402 is checked again for its
# credit balance and reset date; a Guide error without a status is checked for one.
nancy_status=$(grep -m 1 -oE 'guide API request failed: [0-9]{3}( [^[:cntrl:]]*)?' "$results" \
  | sed -e 's/^guide API request failed: //') || nancy_status=""
if [[ -n "$nancy_status" && "${nancy_status%% *}" != 402 ]]; then
  guide_status="${nancy_status%% *}"
  reason="Sonatype Guide answered HTTP ${nancy_status}"
  guide_has_credentials || reason="no Sonatype Guide credentials are set (GUIDE_TOKEN, or OSSI_USERNAME and OSSI_TOKEN)"
elif grep -qF 'guide API request failed' "$results"; then
  guide_error_reason
  # The check did not confirm the 402 nancy named (it is a smaller batch, the
  # API is unreachable now, or it answers anything else, even a 401): report
  # nancy's status, and a quota is never a failed step.
  if [[ -n "$nancy_status" && "$guide_status" != 402 ]] && guide_has_credentials; then
    guide_status=402
    reason="Sonatype Guide answered HTTP ${nancy_status}"
  fi
fi

# Rejected credentials are no outage: the context that holds them is broken,
# only we can fix it, and every build that uses it goes unscanned until then.
# A 403 is not counted: a firewall or an IP block in front of the API answers it
# too, and that is an outage.
if [[ "$guide_status" == 401 ]] && guide_has_credentials; then
  echo
  echo "SCAN FAILED: Sonatype Guide rejected the job's credentials: ${reason}."
  echo "Check GUIDE_TOKEN (or OSSI_USERNAME and OSSI_TOKEN) in the job's CircleCI context."
  write_junit 1 "SCAN FAILED: credentials rejected: ${reason}"
  exit 1
fi

echo
echo "NOT SCANNED: no Go dependency was checked for known vulnerabilities: ${reason}."
echo "The build is not failed for a scanner outage. The JUnit result records the missing scan."
write_junit 1 "NOT SCANNED: ${reason}"
exit 0
