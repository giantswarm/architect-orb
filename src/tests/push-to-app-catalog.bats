#!/usr/bin/env bats
# Tests of src/scripts/push-to-app-catalog.sh against a local catalog
# repository that other builds push to concurrently. A fake helm stands in for
# `helm repo index`; on each of its first RACES calls another build pushes a
# chart of its own to the catalog, between this build's fetch and its push.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/push-to-app-catalog.sh"
  export PARAM_CHART=my-chart PARAM_TRIES=4 PARAM_BACKOFF_SECONDS=1
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL=/dev/null LC_ALL=C
  cd "${BATS_TEST_TMPDIR}" || exit 1

  git init -q --bare -b master remote.git
  git clone -q remote.git seed
  echo "entries:" > seed/index.yaml
  git -C seed add index.yaml
  git -C seed commit -q -m init
  git -C seed push -q origin master

  git clone -q --depth=1 --single-branch "file://${PWD}/remote.git" .app_catalog
  git clone -q remote.git other
  echo -n giantswarm-test-catalog > .app_catalog_name
  mkdir build
  echo chart > build/my-chart-1.0.0.tgz

  mkdir bin
  cat > bin/helm <<'EOF'
#!/bin/bash
# helm repo index --url <url> --merge <index> <dir>
set -euo pipefail
calls=$(( $(cat "${BATS_TEST_TMPDIR}/helm-calls" 2>/dev/null || echo 0) + 1 ))
echo "${calls}" > "${BATS_TEST_TMPDIR}/helm-calls"
{ cat "$6"; echo "  my-chart: 1.0.0"; } > "$7/index.yaml"
if [[ "${calls}" -le "${RACES:-0}" ]]; then
  cd "${BATS_TEST_TMPDIR}/other"
  git pull -q --rebase
  echo chart > "other-chart-${calls}.tgz"
  echo "  other-chart: ${calls}" >> index.yaml
  git add -A
  git commit -q -m "add other-chart-${calls}.tgz"
  git push -q origin master
fi
EOF
  chmod +x bin/helm
  export PATH="${PWD}/bin:${PATH}"
}

remote_file() {
  git -C remote.git show "master:$1"
}

@test "a push without a concurrent build lands at the first attempt" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(remote_file my-chart-1.0.0.tgz)" = chart ]
  [ "$(git -C remote.git log -1 --format=%s master)" = "add my-chart-1.0.0.tgz" ]
  [[ "${output}" != *"Attempt 2/"* ]]
}

@test "every attempt starts from the remote's head and keeps the other builds' charts" {
  export RACES=3
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Attempt 4/4"* ]]
  [ "$(remote_file my-chart-1.0.0.tgz)" = chart ]
  for n in 1 2 3; do
    [ "$(remote_file "other-chart-${n}.tgz")" = chart ]
  done
  index="$(remote_file index.yaml)"
  [[ "${index}" == *"other-chart: 3"* ]]
  [[ "${index}" == *"my-chart: 1.0.0"* ]]
  [ "$(git -C remote.git rev-list --count master)" -eq 5 ]
}

@test "it gives up after the last attempt with the push's error" {
  export RACES=4
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Giving up after 4 push attempts to giantswarm-test-catalog. Last error:"*"[rejected]"* ]]
  run remote_file my-chart-1.0.0.tgz
  [ "${status}" -ne 0 ]
}

@test "the wait between attempts is jittered and bounded" {
  export RACES=3 PARAM_BACKOFF_SECONDS=1
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  for line in $(echo "${output}" | sed -nE 's/.*waiting ([0-9]+)s.*/\1/p'); do
    [ "${line}" -ge 1 ] && [ "${line}" -le 4 ]
  done
}
