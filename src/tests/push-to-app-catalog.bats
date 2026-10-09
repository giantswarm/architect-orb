#!/usr/bin/env bats
# Tests of src/scripts/push-to-app-catalog.sh against a local catalog
# repository that other builds push to concurrently. A fake helm stands in for
# `helm repo index`: it inserts my-chart before z-chart and stamps its own
# `generated:` line. A git wrapper lets another build push a chart of its own
# right before each of this build's first RACES pushes, between this build's
# fetch and its push; with OVERLAP set, that build's change is a my-chart
# version at the same place in the index.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/push-to-app-catalog.sh"
  export PARAM_CHART=my-chart PARAM_TRIES=4 PARAM_BACKOFF_SECONDS=1
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL=/dev/null LC_ALL=C
  cd "${BATS_TEST_TMPDIR}" || exit 1

  git init -q --bare -b master remote.git
  git clone -q remote.git seed
  cat > seed/index.yaml <<'EOF'
apiVersion: v1
entries:
  a-chart:
  - version: 1.0.0
  z-chart:
  - version: 1.0.0
generated: "seed"
EOF
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
sed -e '/^  z-chart:$/i\  my-chart:\n  - version: 1.0.0' \
  -e "s/^generated: .*/generated: \"helm-${calls}\"/" "$6" > "$7/index.yaml"
EOF
  cat > bin/other-build <<'EOF'
#!/bin/bash
# Another build pushes chart number $1 to the catalog.
set -euo pipefail
cd "${BATS_TEST_TMPDIR}/other"
"${REAL_GIT}" pull -q --rebase
if [[ -n "${OVERLAP:-}" ]]; then
  sed -i '/^  z-chart:$/i\  my-chart:\n  - version: 0.9.0' index.yaml
  name="my-chart-0.9.0"
else
  sed -i "/^entries:\$/a\\  other-chart-$1:\\n  - version: 1.0.0" index.yaml
  name="other-chart-$1"
fi
sed -i "s/^generated: .*/generated: \"${name}\"/" index.yaml
echo chart > "${name}.tgz"
"${REAL_GIT}" add -A
"${REAL_GIT}" commit -q -m "add ${name}.tgz"
"${REAL_GIT}" push -q origin master
EOF
  cat > bin/git <<'EOF'
#!/bin/bash
if [[ "$1" == push && "${PWD}" == */.app_catalog ]]; then
  pushes=$(( $(cat "${BATS_TEST_TMPDIR}/pushes" 2>/dev/null || echo 0) + 1 ))
  echo "${pushes}" > "${BATS_TEST_TMPDIR}/pushes"
  if [[ "${pushes}" -le "${RACES:-0}" ]]; then
    other-build "${pushes}"
  fi
fi
exec "${REAL_GIT}" "$@"
EOF
  chmod +x bin/*
  REAL_GIT="$(command -v git)"
  export REAL_GIT
  export PATH="${PWD}/bin:${PATH}"
}

remote_file() {
  git -C remote.git show "master:$1"
}

helm_calls() {
  cat "${BATS_TEST_TMPDIR}/helm-calls"
}

@test "a push without a concurrent build lands at the first attempt" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(remote_file my-chart-1.0.0.tgz)" = chart ]
  [ "$(git -C remote.git log -1 --format=%s master)" = "add my-chart-1.0.0.tgz" ]
  [[ "${output}" != *"Attempt 2/"* ]]
  [ "$(remote_file index.yaml)" = "$(cat <<'EOF'
apiVersion: v1
entries:
  a-chart:
  - version: 1.0.0
  my-chart:
  - version: 1.0.0
  z-chart:
  - version: 1.0.0
generated: "helm-1"
EOF
)" ]
}

@test "a lost push merges the chart onto the remote's head without indexing again" {
  export RACES=3
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Attempt 4/4"* ]]
  [ "$(helm_calls)" -eq 1 ]
  [ "$(remote_file my-chart-1.0.0.tgz)" = chart ]
  for n in 1 2 3; do
    [ "$(remote_file "other-chart-${n}.tgz")" = chart ]
  done
  [ "$(remote_file index.yaml)" = "$(cat <<'EOF'
apiVersion: v1
entries:
  other-chart-3:
  - version: 1.0.0
  other-chart-2:
  - version: 1.0.0
  other-chart-1:
  - version: 1.0.0
  a-chart:
  - version: 1.0.0
  my-chart:
  - version: 1.0.0
  z-chart:
  - version: 1.0.0
generated: "helm-1"
EOF
)" ]
  [ "$(git -C remote.git rev-list --count master)" -eq 5 ]
}

@test "a change overlapping another build's indexes again on the remote's head" {
  export RACES=1 OVERLAP=1
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Attempt 2/4: the chart's index entries overlap another build's, indexing again."* ]]
  [ "$(helm_calls)" -eq 2 ]
  [ "$(remote_file my-chart-0.9.0.tgz)" = chart ]
  [ "$(remote_file my-chart-1.0.0.tgz)" = chart ]
  index="$(remote_file index.yaml)"
  [[ "${index}" == *"version: 0.9.0"* ]]
  [[ "${index}" != *"<<<<<<<"* ]]
  [[ "${index}" == *'generated: "helm-2"' ]]
}

@test "it gives up after the last attempt with the push's error and the time spent" {
  export RACES=4
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Giving up after 4 push attempts to giantswarm-test-catalog in "*"s. Last error:"*"[rejected]"* ]]
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
