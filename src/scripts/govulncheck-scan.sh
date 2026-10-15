#!/bin/bash
# go-test: check the Go code for known vulnerabilities it reaches, with govulncheck.
#
# govulncheck reads the Go vulnerability database (vuln.go.dev), which needs no
# account or credits, and reports a vulnerability only when the code calls an
# affected function. The step fails closed: a reachable vulnerability fails it,
# and so does a scan that could not run (the database is unreachable, the code
# does not build). A green step therefore always means "scanned, nothing
# reachable".
#
# `.govulncheck-ignore` excludes reviewed findings, one per line:
#   GO-2026-5932 until=2026-12-31  # why, and the issue that tracks the fix
# The ID is the Go vulnerability ID or one of its aliases (a CVE or GHSA ID).
# `until=` is required and an entry past its date no longer applies, so an
# exclusion cannot outlive its review.
#
# Tunables, for the tests:
#   GOVULNCHECK_DB                the vulnerability database, https://vuln.go.dev by default
#   GOVULNCHECK_RESULTS           the JSON report, /tmp/govulncheck-results.json by default
#   GOVULNCHECK_TEST_RESULTS_DIR  where the JUnit result goes, /tmp/govulncheck-test-results by default
#   GOVULNCHECK_IGNORE            the exclusion file, ./.govulncheck-ignore by default
#   GOVULNCHECK_TODAY             today's date (YYYY-MM-DD) for `until=`, the UTC date by default
#
# The report stays out of the working tree: a stray untracked file in the repo
# makes Go's buildvcs stamp `vcs.modified=true` on the binaries built after it.
# CircleCI runs the step with `-eo pipefail`; govulncheck's exit code is
# evaluated below, so a failing scan must not end the script.
set +e -uo pipefail

db="${GOVULNCHECK_DB:-https://vulndb.invalid}"  # PROOF ONLY: a forced scanner error, never merged
results="${GOVULNCHECK_RESULTS:-/tmp/govulncheck-results.json}"
junit_dir="${GOVULNCHECK_TEST_RESULTS_DIR:-/tmp/govulncheck-test-results}"
ignore_file="${GOVULNCHECK_IGNORE:-./.govulncheck-ignore}"
today="${GOVULNCHECK_TODAY:-$(date --utc '+%F')}"

write_junit() {
  local failures="$1" message="$2"
  mkdir -p "$junit_dir"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo "<testsuites><testsuite name=\"govulncheck\" tests=\"1\" failures=\"${failures}\">"
    echo '<testcase classname="govulncheck" name="Go code reaches no known vulnerability">'
    if [[ "$failures" -ne 0 ]]; then
      echo "<failure message=\"${message}\"/>"
    fi
    echo '</testcase></testsuite></testsuites>'
  } > "$junit_dir/govulncheck.xml"
}

# In JSON mode govulncheck exits 0 whether or not it finds vulnerabilities and
# non-zero only when the scan itself failed.
govulncheck -format json -db "$db" ./... > "$results"
scan_result=$?
if [[ "$scan_result" -ne 0 ]]; then
  echo
  echo "NOT SCANNED: govulncheck could not check the code (exit code ${scan_result}), see its error above."
  echo "The step fails closed: a scan that did not run is never reported as clean."
  write_junit 1 "NOT SCANNED: govulncheck failed (exit code ${scan_result})"
  exit 1
fi

modules=$(jq -s '[.[] | select(.SBOM) | .SBOM.modules[]] | length' "$results")
echo "govulncheck checked ${modules} modules against ${db}."

# The IDs `.govulncheck-ignore` still excludes today.
ignored='[]'
if [[ -f "$ignore_file" ]]; then
  ignored=$(sed -e 's/#.*//' "$ignore_file" | awk -v today="$today" '
    NF == 0 { next }
    {
      until = ""
      for (i = 2; i <= NF; i++) if ($i ~ /^until=/) until = substr($i, 7)
      if (until == "") { print "ignoring " $1 ": no until= date" > "/dev/stderr"; next }
      if (until < today) { print "ignoring " $1 ": expired on " until > "/dev/stderr"; next }
      print $1
    }' | jq -R . | jq -s .)
fi

# A finding whose first trace frame names a function is one the code calls.
reachable=$(jq -s --argjson ignored "$ignored" '
  (map(select(.osv) | {key: .osv.id, value: ([.osv.id] + (.osv.aliases // []))}) | from_entries) as $ids
  | [.[] | select(.finding and .finding.trace[0].function) | .finding
     | select(($ids[.osv] // [.osv]) as $all | ($ignored | any(. as $i | $all | index($i))) | not)
     | {id: .osv, module: .trace[0].module, version: .trace[0].version, fixed: (.fixed_version // "no fix")}]
  | unique_by(.id)' "$results")
count=$(jq 'length' <<<"$reachable")

if [[ "$count" -eq 0 ]]; then
  echo "No reachable known vulnerability."
  write_junit 0 ""
  exit 0
fi

echo
echo "The code reaches ${count} known vulnerabilities:"
jq -r '.[] | "  \(.id)  \(.module)@\(.version)  fixed in: \(.fixed)  https://pkg.go.dev/vuln/\(.id)"' <<<"$reachable"
echo
echo "Bump the module to its fixed version. A finding without a fix, or one that cannot be bumped yet, goes into"
echo ".govulncheck-ignore with an until= date and the issue that tracks it. 'govulncheck ./...' shows the call traces."
write_junit 1 "the code reaches ${count} known vulnerabilities"
exit 1
