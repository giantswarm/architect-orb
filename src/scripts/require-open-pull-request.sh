#!/bin/bash
# architect/require-open-pull-request: end the job, successfully, unless an open
# pull request covers the commit being built.
#
# Inputs, from the job's environment (CircleCI's own and the architect context's):
#   GITHUB_TOKEN             installation token minted by generate-github-token
#   CIRCLE_PROJECT_USERNAME, CIRCLE_PROJECT_REPONAME, CIRCLE_SHA1, CIRCLE_BRANCH
#   CIRCLE_TAG, CIRCLE_PULL_REQUEST, CIRCLE_PR_NUMBER
#
# The gate fails open: whenever it cannot tell, the commit builds.
set -u -o pipefail

build() { printf 'BUILD: %s\n' "$1"; exit 0; }

api="https://api.github.com"
owner="${CIRCLE_PROJECT_USERNAME:-}"
repo="${CIRCLE_PROJECT_REPONAME:-}"

# gh_open_pr_count <url> — prints the number of open pull requests the
# call returned, or fails when the call itself did not succeed, so a
# permission problem is never read as "there is no pull request".
gh_open_pr_count() {
  local out status body
  out=$(curl -sS --connect-timeout 5 --max-time 20 -w '\n%{http_code}' \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$1") || return 1
  status=${out##*$'\n'}
  body=${out%$'\n'*}
  case "$status" in
    2*) ;;
    *) printf 'GET %s returned HTTP %s\n' "$1" "$status" >&2
       printf '%s\n' "$body" | head -5 >&2
       return 1 ;;
  esac
  printf '%s' "$body" | jq -r '[.[] | select(.state == "open")] | length'
}

# A tag has no pull request to find. build-chart runs on the branch and
# the tag path from one job entry, so this step is reached on tags too.
if [ -n "${CIRCLE_TAG:-}" ]; then
  build "tag build ${CIRCLE_TAG}."
fi

# CircleCI's own values, when set, already answer the question — and on
# a forked pull request they are the only answer there is, because
# CircleCI withholds the context, and with it the GitHub App
# credentials, from forked builds. They are absent under the GitHub App
# integration and unreliable for same-repo pull requests under OAuth,
# so they are a shortcut, never the mechanism. Openness is deliberately
# not re-checked here: re-running an old build of a merged pull request
# is a human asking for that build.
if [ -n "${CIRCLE_PULL_REQUEST:-}${CIRCLE_PR_NUMBER:-}" ]; then
  build "CircleCI associated this build with a pull request."
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  build "no GitHub token (forked pull request, or no 'context: architect' on this job), so the gate cannot check."
fi

# Pull requests containing the exact commit that was built. Preferred
# over ?head=owner:branch because it needs no knowledge of the head
# repository's owner, and because it matches a pull request opened
# after this commit was pushed — which is the case the whole rule turns
# on.
if ! n=$(gh_open_pr_count "${api}/repos/${owner}/${repo}/commits/${CIRCLE_SHA1:-}/pulls?per_page=100"); then
  build "could not reach GitHub; the gate fails open."
fi
if [ "$n" -gt 0 ]; then
  build "${n} open pull request(s) contain ${CIRCLE_SHA1:-}."
fi

# Fallback for same-repo branches, in case the commit-to-pull-request
# association index has not caught up yet. The branch is required and
# percent-encoded: an empty one, or one containing a `&` or `#` (both
# legal in git), turns `head=` into no filter at all and GitHub then
# answers with every open pull request in the repository.
if [ -n "${CIRCLE_BRANCH:-}" ]; then
  head_filter=$(jq -rn --arg b "${CIRCLE_BRANCH}" '$b|@uri')
  if ! n=$(gh_open_pr_count "${api}/repos/${owner}/${repo}/pulls?head=${owner}:${head_filter}&state=open&per_page=100"); then
    build "could not reach GitHub; the gate fails open."
  fi
  if [ "$n" -gt 0 ]; then
    build "${n} open pull request(s) have ${CIRCLE_BRANCH} as their head branch."
  fi
fi

echo "No open pull request covers ${CIRCLE_SHA1:-this commit}; skipping this job."
echo "Open a pull request and this job runs on that commit and on every commit after it."
circleci-agent step halt
