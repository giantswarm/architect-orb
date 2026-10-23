#!/bin/bash
# architect/push-helm-package: clone the app catalog repository into
# .app_catalog, set up to push with the architect GitHub App's installation
# token.
#
# Inputs, set by the command from its parameters:
#   PARAM_TRIES             the number of attempts a failing clone gets
#   PARAM_BACKOFF_SECONDS   the base of the wait after a failed attempt
# GITHUB_TOKEN is the token generate-github-token exported; .app_catalog_name
# holds the catalog's name.
#
# CircleCI's checkout of a project with a deploy key rewrites https://github.com
# to ssh://git@github.com for the whole job (a global url.<base>.insteadOf),
# which would send the catalog's clone and push over SSH with the source
# repository's deploy key. The catalog's URL names the user x-access-token, so
# it does not start with https://github.com and is not rewritten. Git asks the
# helper for the password, the helper hands it the token from the environment:
# the token is never written into a URL or a config file. The helper, the
# author and gc.auto are the clone's own configuration: no other git command of
# the job authenticates with the token. An empty http.extraHeader drops any
# Authorization header the checkout configures, so the token is what git sends.
#
# A clone that fails is retried after a random wait up to a doubling bound (2,
# 4, 8, ... seconds for a base of 2, at most 60), unless GitHub refused it: a
# catalog the App cannot see. A rejected token is retried, GitHub may reject a
# token it minted seconds ago.
set -euo pipefail

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is not set. Did the generate-github-token step succeed?" >&2
  exit 1
fi

readonly max_wait=60
readonly refused='Repository not found|repository .* not found'
# shellcheck disable=SC2016 # the helper reads GITHUB_TOKEN when git runs it.
readonly helper='!f() { test "$1" = get || return 0; echo username=x-access-token; echo "password=${GITHUB_TOKEN}"; }; f'

app_catalog_name="$(cat .app_catalog_name)"
readonly app_catalog_name
readonly url="https://x-access-token@github.com/giantswarm/${app_catalog_name}.git"

for i in $(seq 1 "${PARAM_TRIES}"); do
  rm -rf .app_catalog
  echo "====> Attempt ${i}: Running: git clone --depth=1 --single-branch ${url} .app_catalog"
  # An empty credential.helper first drops any helper the image configures.
  if output="$(git -c http.extraHeader= -c credential.helper= -c "credential.helper=${helper}" \
    clone -q --depth=1 --single-branch "${url}" .app_catalog 2>&1)"; then
    # The empty helper drops any helper of the image's or the job's configuration.
    git -C .app_catalog config credential.helper ""
    git -C .app_catalog config --add credential.helper "${helper}"
    git -C .app_catalog config http.extraHeader ""
    git -C .app_catalog config gc.auto 0
    # The App's bot user, so the catalog's commits are attributed to it on GitHub.
    git -C .app_catalog config user.name "circleci-architect[bot]"
    git -C .app_catalog config user.email "240937895+circleci-architect[bot]@users.noreply.github.com"
    echo "====> Cloned ${app_catalog_name} at attempt ${i}."
    exit 0
  fi
  echo "${output}" >&2
  error="$(echo "${output}" | grep -m1 -E '^error:|^fatal:' || echo "${output}" | tail -n1)"
  if echo "${output}" | grep -q -E "${refused}"; then
    echo "The clone of ${app_catalog_name} was refused, giving up. Error: ${error}" >&2
    echo "The job clones with the architect GitHub App's token: check that the job has the architect context and that the App may read the catalog." >&2
    exit 1
  fi
  if [[ "${i}" -ge "${PARAM_TRIES}" ]]; then
    echo "Giving up after ${i} attempts to clone ${app_catalog_name}. Last error: ${error}" >&2
    exit 1
  fi
  bound=$((PARAM_BACKOFF_SECONDS * 2 ** (i - 1)))
  [[ "${bound}" -gt "${max_wait}" ]] && bound="${max_wait}"
  delay=$((RANDOM % bound + 1))
  echo "====> Attempt ${i} failed (${i}/${PARAM_TRIES}), waiting ${delay}s before the next one." >&2
  sleep "${delay}"
done
