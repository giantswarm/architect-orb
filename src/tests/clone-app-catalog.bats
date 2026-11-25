#!/usr/bin/env bats
# Tests of src/scripts/clone-app-catalog.sh against a local catalog
# repository. The job's global git configuration rewrites https://github.com to
# SSH, as CircleCI's checkout does for a project with a deploy key; the test's
# own rewrite maps the catalog's token URL to the local repository. A git
# wrapper fails this build's first CLONE_FAILURES clones, with CLONE_ERROR as
# the message when it is set.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/clone-app-catalog.sh"
  export PARAM_TRIES=3 PARAM_BACKOFF_SECONDS=1 GITHUB_TOKEN=test-token LC_ALL=C GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  cd "${BATS_TEST_TMPDIR}" || exit 1

  export GIT_CONFIG_GLOBAL="${PWD}/gitconfig"
  cat > gitconfig <<CONFIG
[url "ssh://git@github.com"]
	insteadOf = https://github.com
[url "file://${PWD}/"]
	insteadOf = https://x-access-token@github.com/giantswarm/
CONFIG

  git init -q --bare -b master giantswarm-test-catalog.git
  git -C giantswarm-test-catalog.git config uploadpack.allowFilter true
  git clone -q giantswarm-test-catalog.git seed 2>/dev/null
  echo "apiVersion: v1" > seed/index.yaml
  echo unrelated > seed/unrelated-1.0.0.tgz
  mkdir -p seed/release-aws-1.0.0.tgz-meta build/release-aws-1.0.0.tgz-meta
  echo existing > seed/release-aws-1.0.0.tgz
  echo metadata > seed/release-aws-1.0.0.tgz-meta/main.yaml
  echo replacement > build/release-aws-1.0.0.tgz
  echo metadata > build/release-aws-1.0.0.tgz-meta/main.yaml
  git -C seed add .
  git -C seed commit -q -m init
  git -C seed push -q origin master
  echo -n giantswarm-test-catalog > .app_catalog_name

  mkdir bin
  cat > bin/git <<'WRAPPER'
#!/bin/bash
if [[ "$*" == *" clone "* ]]; then
  clones=$(( $(cat "${BATS_TEST_TMPDIR}/clones" 2>/dev/null || echo 0) + 1 ))
  echo "${clones}" > "${BATS_TEST_TMPDIR}/clones"
  if [[ "${clones}" -le "${CLONE_FAILURES:-0}" ]]; then
    mkdir -p .app_catalog/partial
    printf '%b\n' "${CLONE_ERROR:-fatal: unable to access the catalog}" >&2
    exit 128
  fi
fi
if [[ "$*" == *" reset "* && -n "${CHECKOUT_FAILURES:-}" ]]; then
  checkouts=$(( $(cat "${BATS_TEST_TMPDIR}/checkouts" 2>/dev/null || echo 0) + 1 ))
  echo "${checkouts}" > "${BATS_TEST_TMPDIR}/checkouts"
  if [[ "${checkouts}" -le "${CHECKOUT_FAILURES}" ]]; then
    echo 'fatal: unable to fetch catalog index' >&2
    exit 128
  fi
fi
exec "${REAL_GIT}" "$@"
WRAPPER
  chmod +x bin/git
  REAL_GIT="$(command -v git)"
  export REAL_GIT
  export PATH="${PWD}/bin:${PATH}"
}

@test "the catalog is cloned with the token URL, not rewritten to SSH" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat .app_catalog/index.yaml)" = "apiVersion: v1" ]
  [ "$(git -C .app_catalog config remote.origin.url)" = "https://x-access-token@github.com/giantswarm/giantswarm-test-catalog.git" ]
  [[ "${output}" != *"ssh://"* ]]
}

@test "the token's helper and the author are the clone's own configuration" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(git -C .app_catalog config --local user.name)" = "circleci-architect[bot]" ]
  [ "$(git -C .app_catalog config --local user.email)" = "240937895+circleci-architect[bot]@users.noreply.github.com" ]
  [ "$(git -C .app_catalog config --local gc.auto)" = 0 ]
  [ -z "$(git -C .app_catalog config --local http.extraHeader)" ]
  run git config --global --get-regexp '^credential\.'
  [ "${status}" -ne 0 ]
  run bash -c 'printf "protocol=https\nhost=github.com\nusername=x-access-token\n\n" | git -C .app_catalog credential fill'
  [[ "${output}" == *"password=test-token"* ]]
  [[ "$(cat .app_catalog/.git/config)" != *"test-token"* ]]
}

@test "only the index and exact build paths are checked out and downloaded" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat .app_catalog/release-aws-1.0.0.tgz)" = existing ]
  [ "$(cat .app_catalog/release-aws-1.0.0.tgz-meta/main.yaml)" = metadata ]
  [ ! -e .app_catalog/unrelated-1.0.0.tgz ]
  unrelated="$(git -C seed rev-parse HEAD:unrelated-1.0.0.tgz)"
  missing="$(git -C .app_catalog rev-list --objects --missing=print HEAD)"
  [[ "${missing}" == *"?${unrelated}"* ]]
  [ -z "$(git -C .app_catalog status --porcelain)" ]
}

@test "build path pattern characters are literal" {
  echo literal > 'seed/package[1].tgz'
  echo different > seed/package1.tgz
  echo replacement > 'build/package[1].tgz'
  git -C seed add . && git -C seed commit -q -m patterns && git -C seed push -q
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat '.app_catalog/package[1].tgz')" = literal ]
  [ ! -e .app_catalog/package1.tgz ]
}

@test "a failed sparse checkout retries the whole clone" {
  export CHECKOUT_FAILURES=1
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/clones")" -eq 2 ]
  [ "$(cat .app_catalog/index.yaml)" = "apiVersion: v1" ]
}

@test "a failing clone is retried with a fresh directory" {
  export CLONE_FAILURES=2
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/clones")" -eq 3 ]
  [[ "${output}" == *"Attempt 2 failed (2/3), waiting "* ]]
  [ ! -e .app_catalog/partial ]
  [[ "${output}" == *"Cloned giantswarm-test-catalog at attempt 3."* ]]
}

@test "a refused clone gives up at once" {
  export CLONE_FAILURES=10
  for refusal in \
    "remote: Repository not found.\nfatal: repository 'https://github.com/giantswarm/giantswarm-test-catalog.git/' not found"; do
    rm -f "${BATS_TEST_TMPDIR}/clones"
    CLONE_ERROR="${refusal}" run bash "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/clones")" -eq 1 ]
    [[ "${output}" != *"waiting"* ]]
    [[ "${output}" == *"The clone of giantswarm-test-catalog was refused, giving up. Error: fatal: "* ]]
  done
}

@test "a rejected token is retried, GitHub may not know a token it just minted" {
  export CLONE_FAILURES=1 CLONE_ERROR="remote: Invalid username or token. Password authentication is not supported for Git operations.\nfatal: Authentication failed for 'https://github.com/giantswarm/giantswarm-test-catalog.git/'"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/clones")" -eq 2 ]
}

@test "it gives up after PARAM_TRIES failed clones" {
  export CLONE_FAILURES=10
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/clones")" -eq 3 ]
  [[ "${output}" == *"Giving up after 3 attempts to clone giantswarm-test-catalog. Last error: fatal: unable to access the catalog"* ]]
}

@test "it fails without a token" {
  unset GITHUB_TOKEN
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"GITHUB_TOKEN is not set"* ]]
}
