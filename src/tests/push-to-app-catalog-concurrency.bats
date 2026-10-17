#!/usr/bin/env bats
# A concurrency test of src/scripts/push-to-app-catalog.sh against a busy
# catalog. The catalog is a local bare repository whose pre-receive hook takes
# LATENCY to twice LATENCY seconds, as the hosted catalog's push processing
# does, so the BUILDS builds that run the script at the same time overlap and
# all but the first to update the head lose with "fetch first", "cannot lock
# ref" or "incorrect old value". The hook also stands in for a fleet of other
# builds that keeps the catalog saturated: before each build's first RACES
# pushes it lands another build's chart, fleet-<build>-<k>, on the head, so
# that push loses its race once the hook returns. The lost races are counted,
# not timed: the test lands the same charts on a loaded machine as on an idle
# one. Every build has to land, after losing at least its RACES injected
# races, and the catalog has to keep every build's and every fleet chart's
# entry.

# bats-core cuts a test that runs longer than this; the script's own deadline,
# PARAM_TIMEOUT_SECONDS, ends a build well before.
BATS_TEST_TIMEOUT=180

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/push-to-app-catalog.sh"
  export PARAM_TRIES=5 PARAM_BACKOFF_SECONDS=1 PARAM_TIMEOUT_SECONDS=120
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL=/dev/null LC_ALL=C
  export LATENCY=0.5 BUILDS=3 RACES=3
  cd "${BATS_TEST_TMPDIR}" || exit 1

  git init -q --bare -b master remote.git
  # The catalog's push processing. A build's push (its commit adds
  # my-chart-<n>-1.0.0.tgz) that still has injected races to lose has a fleet
  # chart land first; the fleet's own pushes pass at once. Every push, the
  # builds' and the fleet's, updates the one ref master, so the hook reads the
  # first ref line only.
  cat > remote.git/hooks/pre-receive <<'EOF'
#!/bin/bash
read -r _ new _
cat >/dev/null
[[ -n "${FLEET_PUSH:-}" ]] && exit 0
build="$(git log -1 --format=%s "${new}" | sed -n 's/^add my-chart-\([0-9]*\)-1\.0\.0\.tgz$/\1/p')"
if [[ -n "${build}" ]]; then
  lost="$(cat "${BATS_TEST_TMPDIR}/races-${build}" 2>/dev/null || echo 0)"
  if [[ "${lost}" -lt "${RACES}" ]]; then
    echo $((lost + 1)) > "${BATS_TEST_TMPDIR}/races-${build}"
    fleet-push "fleet-${build}-$((lost + 1))" >&2
  fi
fi
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
  # fleet-push <chart>: another build lands the chart on the catalog's head,
  # from a shallow clone of its own as in CI. Runs inside the hook of a
  # build's push, outside that push's quarantine, and retries a push that a
  # concurrent fleet push beat, a bounded number of times.
  cat > bin/fleet-push <<'EOF'
#!/bin/bash
set -euo pipefail
unset GIT_DIR GIT_QUARANTINE_PATH GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PUSH_OPTION_COUNT
export FLEET_PUSH=1
cd "${BATS_TEST_TMPDIR}"
git clone -q --depth=1 --single-branch "file://${PWD}/remote.git" "$1"
cd "$1"
for _ in $(seq 1 10); do
  insert-entry "$1" index.yaml > index.yaml.new && mv index.yaml.new index.yaml
  sed -i "s/^generated: .*/generated: \"$1\"/" index.yaml
  echo chart > "$1-1.0.0.tgz"
  git add -A && git commit -q -m "add $1-1.0.0.tgz"
  if git push -q origin HEAD:master 2>/dev/null; then
    echo "$1" >> "${BATS_TEST_TMPDIR}/fleet-landed"
    exit 0
  fi
  git fetch -q --depth=1 origin master && git reset -q --hard FETCH_HEAD
done
echo "fleet-push: $1 did not land" >&2
exit 1
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

@test "every build lands on a catalog that other builds keep saturated" {
  pids=()
  for n in $(seq 1 "${BUILDS}"); do
    (cd "build-${n}" && PARAM_CHART="my-chart-${n}" exec bash "${SCRIPT}" > ../"build-${n}.log" 2>&1) 3>&- &
    pids+=("$!")
  done
  failed=0
  for n in $(seq 1 "${BUILDS}"); do
    wait "${pids[$((n - 1))]}" || { failed=$((failed + 1)); echo "build ${n} failed:"; tail -n 3 "build-${n}.log"; }
  done

  echo "fleet charts landed: $(wc -l < fleet-landed)"
  [ "${failed}" -eq 0 ]
  [ "$(wc -l < fleet-landed)" -eq $((BUILDS * RACES)) ]

  index="$(git -C remote.git show master:index.yaml)"
  [[ "${index}" != *"<<<<<<<"* ]]
  for n in $(seq 1 "${BUILDS}"); do
    lost="$(grep -c 'lost the race' "build-${n}.log")"
    echo "build ${n} lost ${lost} races"
    [ "${lost}" -ge "${RACES}" ]
    [ "$(git -C remote.git show "master:my-chart-${n}-1.0.0.tgz")" = chart ]
    [[ "${index}" == *"  my-chart-${n}:"* ]]
  done
  while read -r chart; do
    [ "$(git -C remote.git show "master:${chart}-1.0.0.tgz")" = chart ]
    [[ "${index}" == *"  ${chart}:"* ]]
  done < fleet-landed
}
