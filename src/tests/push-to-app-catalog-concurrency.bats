#!/usr/bin/env bats
# A concurrency test of src/scripts/push-to-app-catalog.sh against a busy
# catalog. The catalog is a local bare repository whose pre-receive hook takes
# LATENCY to twice LATENCY seconds, as the hosted catalog's push processing
# does, so pushes overlap and all but the first to update the head lose with
# "fetch first" or "incorrect old value". A fleet of FLEET other builds, from
# shallow clones as in CI, pushes a chart, retries a lost push at once and
# pushes the next one, up to FLEET_CHARTS each, keeping the catalog saturated;
# BUILDS builds run the script at the same time. Every
# build has to land, and the catalog has to keep every build's and every fleet
# chart's entry.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/push-to-app-catalog.sh"
  export PARAM_TRIES=5 PARAM_BACKOFF_SECONDS=1 PARAM_TIMEOUT_SECONDS=90
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL=/dev/null LC_ALL=C
  export LATENCY=0.5 FLEET=3 FLEET_CHARTS=120 BUILDS=3
  cd "${BATS_TEST_TMPDIR}" || exit 1

  git init -q --bare -b master remote.git
  cat > remote.git/hooks/pre-receive <<'EOF'
#!/bin/bash
cat >/dev/null
sleep "$(awk -v l="${LATENCY}" -v r="${RANDOM}" 'BEGIN { print l * (1 + r / 32768) }')"
EOF
  chmod +x remote.git/hooks/pre-receive
  git clone -q remote.git seed 2>/dev/null
  printf 'apiVersion: v1\nentries:\n  a-chart:\n  - version: 1.0.0\n  z-chart:\n  - version: 1.0.0\ngenerated: "seed"\n' > seed/index.yaml
  git -C seed add index.yaml
  git -C seed commit -q -m init
  git -C seed push -q origin master

  mkdir bin
  # A fake `helm repo index --url <url> --merge <index> <dir>`: inserts the
  # chart packaged in <dir> into the index at its sorted place, after a second
  # of work, and stamps its own `generated:` line.
  cat > bin/helm <<'EOF'
#!/bin/bash
set -euo pipefail
sleep 1
chart="$(basename "$(ls "$7"/*.tgz)" -1.0.0.tgz)"
insert-entry "${chart}" "$6" > "$7/index.yaml.new"
sed -i "s/^generated: .*/generated: \"helm-${chart}\"/" "$7/index.yaml.new"
mv "$7/index.yaml.new" "$7/index.yaml"
EOF
  # insert-entry <chart> <index>: the index with the chart's entry at its
  # sorted place among the top-level entries.
  cat > bin/insert-entry <<'EOF'
#!/bin/bash
awk -v chart="$1" '
  /^  [^ -].*:$/ && !done { name = substr($0, 3, length($0) - 3); if (name > chart) { print "  " chart ":\n  - version: 1.0.0"; done = 1 } }
  /^generated: / && !done { print "  " chart ":\n  - version: 1.0.0"; done = 1 }
  { print }
' "$2"
EOF
  # fleet-build <n>: another build that pushes fleet-<n>-<k> charts until
  # the stop file appears, retrying a lost push at once.
  cat > bin/fleet-build <<'EOF'
#!/bin/bash
set -uo pipefail
cd "${BATS_TEST_TMPDIR}"
git clone -q --depth=1 --single-branch "file://${PWD}/remote.git" "fleet-$1"
cd "fleet-$1"
k=0
while [[ ! -e "${BATS_TEST_TMPDIR}/stop" && "${k}" -lt "${FLEET_CHARTS}" ]]; do
  k=$((k + 1))
  chart="fleet-$1-${k}"
  while [[ ! -e "${BATS_TEST_TMPDIR}/stop" ]]; do
    git fetch -q --depth=1 origin master && git reset -q --hard FETCH_HEAD || continue
    insert-entry "${chart}" index.yaml > index.yaml.new && mv index.yaml.new index.yaml
    sed -i "s/^generated: .*/generated: \"${chart}\"/" index.yaml
    echo chart > "${chart}-1.0.0.tgz"
    git add -A && git commit -q -m "add ${chart}-1.0.0.tgz"
    if git push -q origin HEAD:master 2>/dev/null; then
      echo "${chart}" >> "${BATS_TEST_TMPDIR}/fleet-landed"
      break
    fi
  done
done
EOF
  chmod +x bin/*
  export PATH="${PWD}/bin:${PATH}"

  for n in $(seq 1 "${BUILDS}"); do
    mkdir "build-${n}"
    git clone -q --depth=1 --single-branch "file://${PWD}/remote.git" "build-${n}/.app_catalog"
    echo -n giantswarm-test-catalog > "build-${n}/.app_catalog_name"
    mkdir "build-${n}/build"
    echo chart > "build-${n}/build/my-chart-${n}-1.0.0.tgz"
  done
}

teardown() {
  touch "${BATS_TEST_TMPDIR}/stop"
  wait
}

@test "every build lands on a catalog that other builds keep saturated" {
  for n in $(seq 1 "${FLEET}"); do
    fleet-build "${n}" 3>&- &
  done
  # The fleet saturates the catalog before the builds start.
  sleep 2
  pids=()
  for n in $(seq 1 "${BUILDS}"); do
    (cd "build-${n}" && PARAM_CHART="my-chart-${n}" exec bash "${SCRIPT}" > ../"build-${n}.log" 2>&1) 3>&- &
    pids+=("$!")
  done
  failed=0
  for n in $(seq 1 "${BUILDS}"); do
    wait "${pids[$((n - 1))]}" || { failed=$((failed + 1)); echo "build ${n} failed:"; tail -n 3 "build-${n}.log"; }
  done
  touch stop
  wait

  echo "fleet charts landed: $(wc -l < fleet-landed)"
  [ "${failed}" -eq 0 ]
  [ "$(wc -l < fleet-landed)" -ge 20 ]

  index="$(git -C remote.git show master:index.yaml)"
  [[ "${index}" != *"<<<<<<<"* ]]
  for n in $(seq 1 "${BUILDS}"); do
    [ "$(git -C remote.git show "master:my-chart-${n}-1.0.0.tgz")" = chart ]
    [[ "${index}" == *"  my-chart-${n}:"* ]]
  done
  while read -r chart; do
    [ "$(git -C remote.git show "master:${chart}-1.0.0.tgz")" = chart ]
    [[ "${index}" == *"  ${chart}:"* ]]
  done < fleet-landed
}
