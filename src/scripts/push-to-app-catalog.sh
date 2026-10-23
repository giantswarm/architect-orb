#!/bin/bash
# architect/push-helm-package: push the packaged chart into the app catalog
# repository.
#
# Inputs, set by the command from its parameters:
#   PARAM_CHART             the chart's name, for the commit message
#   PARAM_TIMEOUT_SECONDS   how long the push may keep losing races
#   PARAM_TRIES             the number of attempts a failing fetch or push
#                           (other than a lost race) gets
#   PARAM_BACKOFF_SECONDS   the base of the wait after such a failure
#
# Runs in the job's working directory: .app_catalog_name holds the catalog's
# name, .app_catalog is its clone and build/ holds the packaged chart.
#
# Every build of the fleet pushes to the same few catalog repositories, so a
# push races the others and loses when one lands between this build's fetch
# and its push ("fetch first", "cannot lock ref"). The hosted catalog takes a
# push every ten seconds or so; a wave of builds keeps it saturated for many
# minutes, and a build only wins when it fetches right after another build's
# push landed. So a lost race is retried at once, never after a growing wait:
# a build that waits comes back in the middle of another build's push and
# loses again, round after round, until its attempts run out. The races a
# build may lose are bounded by time, long enough for a wave to drain. Other
# failures of the fetch or the push (the network, the remote) wait a random
# time up to a doubling bound (2, 4, 8, ... seconds for a base of 2, at most
# 60) and end the push after PARAM_TRIES of them in a row.
#
# The window between fetch and push has to be short: merging the chart into a
# catalog's index with `helm repo index --merge` reads and rewrites the whole
# index (tens of megabytes, tens of seconds), so it runs once, on the cloned
# head. Every attempt fetches the remote's head and three-way merges the
# chart's index change onto the head's index (`git merge-file`, about a
# second), then commits and pushes. Only a change that overlaps another
# build's (a version of the same chart inserted at the same place) runs helm
# again on the new head. The `generated:` line, which every push rewrites, is
# kept out of the merge and set to helm's afterwards.
set -euo pipefail

readonly max_wait=60

app_catalog_name="$(cat .app_catalog_name)"
readonly app_catalog_name
readonly build_dir="${PWD}/build"
work_dir="$(mktemp -d)"
readonly work_dir

cd .app_catalog

branch="$(git rev-parse --abbrev-ref HEAD)"
readonly branch

# with_generated <line> <file>: the file with its `generated:` line replaced.
with_generated() {
  sed "s/^generated: .*/$1/" "$2"
}

# fetch_head: check out the remote's head.
fetch_head() {
  echo "====> Attempt ${i}: Running: git fetch origin ${branch} && git reset --hard FETCH_HEAD"
  git fetch -q --depth=1 origin "${branch}" 2>&1 &&
    git reset -q --hard FETCH_HEAD 2>&1 &&
    git clean -q -fd 2>&1
}

# index_chart: merge the chart into the checked-out head's index with helm.
# Leaves the merge inputs in the work directory: base.yaml (the head's index)
# and chart.yaml (helm's index), both with the head's `generated:` line, and
# helm's own `generated:` line in helm_generated.
index_chart() {
  echo "====> Running: helm repo index --url https://giantswarm.github.io/${app_catalog_name} --merge index.yaml ${build_dir}"
  helm repo index --url "https://giantswarm.github.io/${app_catalog_name}" --merge index.yaml "${build_dir}"
  local head_generated
  head_generated="$(grep -m1 '^generated: ' index.yaml)"
  cp index.yaml "${work_dir}/base.yaml"
  helm_generated="$(grep -m1 '^generated: ' "${build_dir}/index.yaml")"
  with_generated "${head_generated}" "${build_dir}/index.yaml" > "${work_dir}/chart.yaml"
}

# merge_chart: three-way merge the chart's index change onto the checked-out
# head's index into merged.yaml; fails when it overlaps another build's change.
merge_chart() {
  echo "====> Attempt ${i}: Running: git merge-file the chart's index entries onto the head's index.yaml"
  with_generated "$(grep -m1 '^generated: ' "${work_dir}/base.yaml")" index.yaml > "${work_dir}/merged.yaml"
  git merge-file -q "${work_dir}/merged.yaml" "${work_dir}/base.yaml" "${work_dir}/chart.yaml"
}

# failed <error>: a fetch or push failure that is no lost race; waits before
# the next attempt or gives up after PARAM_TRIES of them in a row.
failed() {
  last_error="$1"
  failures=$((failures + 1))
  if [[ "${failures}" -ge "${PARAM_TRIES}" ]]; then
    echo "Giving up after ${failures} failures in a row to reach ${app_catalog_name} in $((SECONDS - start))s. Last error: ${last_error}" >&2
    exit 1
  fi
  local bound=$((PARAM_BACKOFF_SECONDS * 2 ** (failures - 1)))
  [[ "${bound}" -gt "${max_wait}" ]] && bound="${max_wait}"
  local delay=$((RANDOM % bound + 1))
  echo "====> Attempt ${i} failed (${failures}/${PARAM_TRIES}), waiting ${delay}s before the next one." >&2
  sleep "${delay}"
}

start="${SECONDS}"
deadline=$((SECONDS + PARAM_TIMEOUT_SECONDS))
last_error=""
failures=0
i=0
index_chart
while [[ "${SECONDS}" -lt "${deadline}" ]]; do
  i=$((i + 1))
  if ! fetch_output="$(fetch_head)"; then
    echo "${fetch_output}" >&2
    failed "$(echo "${fetch_output}" | grep -m1 -E '^error:|^fatal:' || echo "${fetch_output}" | tail -n1)"
    continue
  fi
  echo "${fetch_output}"
  if ! merge_chart; then
    echo "====> Attempt ${i}: the chart's index entries overlap another build's, indexing again."
    index_chart
    cp "${work_dir}/chart.yaml" "${work_dir}/merged.yaml"
  fi

  echo "====> Attempt ${i}: Running: cp -r ${build_dir}/* ."
  cp -r "${build_dir}"/* .
  with_generated "${helm_generated}" "${work_dir}/merged.yaml" > index.yaml

  git add -A
  # The commit names the added paths that carry the chart's name. A chart
  # packaged under another name (giantswarm/releases passes its directory,
  # release-chart, and packages release-<provider>-<version>.tgz) names its
  # archives instead: a name that matches nothing never fails the push.
  added="$(git status --porcelain | cut -c4- | grep "${PARAM_CHART}" || true)"
  if [[ -z "${added}" ]]; then
    added="$(git status --porcelain | cut -c4- | grep '\.tgz$' || true)"
  fi
  echo "====> Attempt ${i}: Running: git commit -m \"add ${added:-chart}\""
  git commit -q -m "add ${added:-chart}"

  echo "====> Attempt ${i}: Running: git push origin HEAD:${branch}"
  if push_output="$(git push origin "HEAD:${branch}" 2>&1)"; then
    echo "${push_output}"
    echo "====> Pushed at attempt ${i} after $((SECONDS - start))s."
    exit 0
  fi
  echo "${push_output}" >&2
  error="$(echo "${push_output}" | grep -m1 -E '^ ! |^error:|^fatal:' || echo "${push_output}" | tail -n1)"
  # A lost race: another build's push landed first, or was landing.
  if echo "${push_output}" | grep -q -E 'fetch first|non-fast-forward|cannot lock ref|incorrect old value|failed to update ref'; then
    last_error="${error}"
    failures=0
    echo "====> Attempt ${i} lost the race to another build's push, fetching its head at once." >&2
  # A refused push: the token is rejected or lacks write access, or the branch
  # is protected against it. Another attempt is refused the same way. A bare
  # 403 is no refusal: GitHub throttles busy pushers with one.
  elif echo "${push_output}" | grep -q -E 'Authentication failed|Invalid username or token|Permission to .* denied|GH006|GH013'; then
    echo "The push to ${app_catalog_name} was refused, giving up. Error: ${error}" >&2
    echo "The job pushes with the architect GitHub App's token: check that the job has the architect context and that the App may push to the catalog's ${branch} branch. The token lasts an hour: after a long job a rerun mints a new one." >&2
    exit 1
  else
    failed "${error}"
  fi
done

echo "Giving up after ${i} push attempts to ${app_catalog_name} in $((SECONDS - start))s. Last error: ${last_error}" >&2
echo "Another build pushed to the catalog between this build's fetch and its push every time; a rerun from failed retries." >&2
exit 1
