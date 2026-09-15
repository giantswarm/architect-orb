#!/usr/bin/env bats
# Tests of src/scripts/require-open-pull-request.sh: whether a build job ends,
# successfully, before building. It ends when no open pull request covers the
# commit and builds in every other case, including every case where it cannot
# tell (the gate fails open). curl and circleci-agent are stand-ins on PATH:
# curl answers the two GitHub endpoints from files, and records each URL it was
# asked for; circleci-agent records the arguments it was called with.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/require-open-pull-request.sh"
  unset CIRCLE_TAG CIRCLE_PULL_REQUEST CIRCLE_PR_NUMBER
  export CIRCLE_PROJECT_USERNAME=giantswarm CIRCLE_PROJECT_REPONAME=app
  export CIRCLE_SHA1=abc123 CIRCLE_BRANCH=my-branch GITHUB_TOKEN=token

  FAKE="${BATS_TEST_TMPDIR}/fake"
  mkdir -p "${FAKE}" "${BATS_TEST_TMPDIR}/bin"
  export FAKE
  # Default: both endpoints answer 200 with no pull request.
  commits_answer 200 '[]'
  head_answer 200 '[]'

  cat > "${BATS_TEST_TMPDIR}/bin/curl" <<'CURL'
#!/bin/bash
url="${*: -1}"
echo "${url}" >> "${FAKE}/urls"
case "${url}" in
  */commits/*/pulls*) kind=commits ;;
  */pulls\?head=*) kind=head ;;
  *) echo "unexpected url ${url}" >&2; exit 2 ;;
esac
cat "${FAKE}/${kind}.body"
printf '\n%s' "$(cat "${FAKE}/${kind}.code")"
CURL
  cat > "${BATS_TEST_TMPDIR}/bin/circleci-agent" <<'AGENT'
#!/bin/bash
echo "$*" >> "${FAKE}/agent"
AGENT
  chmod +x "${BATS_TEST_TMPDIR}/bin/curl" "${BATS_TEST_TMPDIR}/bin/circleci-agent"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

commits_answer() { printf '%s' "$2" > "${FAKE}/commits.body"; printf '%s' "$1" > "${FAKE}/commits.code"; }
head_answer() { printf '%s' "$2" > "${FAKE}/head.body"; printf '%s' "$1" > "${FAKE}/head.code"; }

halted() {
  [ "$(cat "${FAKE}/agent" 2>/dev/null)" = "step halt" ]
}

@test "a push with no pull request ends the job" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  halted
}

@test "an open pull request containing the commit lets the job build" {
  commits_answer 200 '[{"state":"open"}]'
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -e "${FAKE}/agent" ]
}

@test "a pull request that is closed does not count" {
  commits_answer 200 '[{"state":"closed"}]'
  run bash "${SCRIPT}"
  halted
}

@test "an open pull request with the branch as head lets the job build when the commit lookup has not caught up" {
  head_answer 200 '[{"state":"open"}]'
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -e "${FAKE}/agent" ]
}

@test "the branch is percent-encoded in the head filter" {
  CIRCLE_BRANCH='feat/a&b#c' run bash "${SCRIPT}"
  grep -q 'head=giantswarm:feat%2Fa%26b%23c&state=open' "${FAKE}/urls"
}

@test "an empty branch never queries the head filter, which would match every pull request" {
  CIRCLE_BRANCH='' run bash "${SCRIPT}"
  run grep -q 'pulls?head=' "${FAKE}/urls"
  [ "${status}" -ne 0 ]
  halted
}

@test "a tag build is never gated" {
  CIRCLE_TAG=v1.2.3 run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -e "${FAKE}/agent" ]
  [ ! -e "${FAKE}/urls" ]
}

@test "CircleCI's own pull request variable lets the job build without asking GitHub" {
  CIRCLE_PULL_REQUEST=https://github.com/giantswarm/app/pull/7 run bash "${SCRIPT}"
  [ ! -e "${FAKE}/agent" ]
  [ ! -e "${FAKE}/urls" ]
}

@test "the gate fails open without a GitHub token" {
  unset GITHUB_TOKEN
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -e "${FAKE}/agent" ]
}

@test "the gate fails open when GitHub answers an error" {
  commits_answer 403 '{"message":"rate limited"}'
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -e "${FAKE}/agent" ]
}
