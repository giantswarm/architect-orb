#!/bin/bash
# architect/push-helm-package: push the packaged chart into the app catalog
# repository.
#
# Inputs, set by the command from its parameters:
#   PARAM_CHART             the chart's name, for the commit message
#   PARAM_TRIES             the number of push attempts
#   PARAM_BACKOFF_SECONDS   the base of the wait between attempts
#
# Runs in the job's working directory: .app_catalog_name holds the catalog's
# name, .app_catalog is its clone and build/ holds the packaged chart.
#
# Every build of the fleet pushes to the same few catalog repositories, so a
# push races the others and loses when one lands between this build's fetch
# and its push ("fetch first"). The window has to be short: merging the chart
# into a catalog's index with `helm repo index --merge` reads and rewrites the
# whole index (tens of megabytes, tens of seconds), so it runs once. Every
# attempt after a lost race fetches the remote's head and three-way merges the
# chart's index change onto the head's index (`git merge-file`, about a
# second), then commits and pushes. Only a change that overlaps another
# build's (a version of the same chart inserted at the same place) runs helm
# again on the new head. The `generated:` line, which every push rewrites, is
# kept out of the merge and set to helm's afterwards. A lost race waits a
# random time up to a doubling bound (2, 4, 8, ... seconds for a base of 2, at
# most 60) before the next attempt, so builds that collided once spread out
# instead of colliding again.
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

fetch_head() {
  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: git fetch origin ${branch} && git reset --hard FETCH_HEAD"
  git fetch -q --depth=1 origin "${branch}"
  git reset -q --hard FETCH_HEAD
  git clean -q -fd
}

# index_chart: merge the chart into the checked-out head's index with helm.
# Leaves the merge inputs in the work directory: base.yaml (the head's index)
# and chart.yaml (helm's index), both with the head's `generated:` line, and
# helm's own `generated:` line in helm_generated.
index_chart() {
  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: helm repo index --url https://giantswarm.github.io/${app_catalog_name} --merge index.yaml ${build_dir}"
  helm repo index --url "https://giantswarm.github.io/${app_catalog_name}" --merge index.yaml "${build_dir}"
  local head_generated
  head_generated="$(grep -m1 '^generated: ' index.yaml)"
  cp index.yaml "${work_dir}/base.yaml"
  helm_generated="$(grep -m1 '^generated: ' "${build_dir}/index.yaml")"
  with_generated "${head_generated}" "${build_dir}/index.yaml" > "${work_dir}/chart.yaml"
  cp "${work_dir}/chart.yaml" "${work_dir}/merged.yaml"
}

# merge_chart: three-way merge the chart's index change onto the checked-out
# head's index into merged.yaml; fails when it overlaps another build's change.
merge_chart() {
  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: git merge-file the chart's index entries onto the head's index.yaml"
  with_generated "$(grep -m1 '^generated: ' "${work_dir}/base.yaml")" index.yaml > "${work_dir}/merged.yaml"
  git merge-file -q "${work_dir}/merged.yaml" "${work_dir}/base.yaml" "${work_dir}/chart.yaml"
}

start="${SECONDS}"
last_error=""
for i in $(seq 1 "${PARAM_TRIES}"); do
  fetch_head
  if [[ "${i}" -eq 1 ]]; then
    index_chart
  elif ! merge_chart; then
    echo "====> Attempt ${i}/${PARAM_TRIES}: the chart's index entries overlap another build's, indexing again."
    index_chart
  fi

  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: cp -r ${build_dir}/* ."
  cp -r "${build_dir}"/* .
  with_generated "${helm_generated}" "${work_dir}/merged.yaml" > index.yaml

  git add -A
  added="$(git status --porcelain | cut -c4- | grep "${PARAM_CHART}")"
  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: git commit -m \"add ${added}\""
  git commit -q -m "add ${added}"

  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: git push origin HEAD:${branch}"
  if push_output="$(git push origin "HEAD:${branch}" 2>&1)"; then
    echo "${push_output}"
    exit 0
  fi
  echo "${push_output}" >&2
  last_error="$(echo "${push_output}" | grep -m1 -E '^ ! |^error:|^fatal:' || echo "${push_output}" | tail -n1)"

  if [[ "${i}" -lt "${PARAM_TRIES}" ]]; then
    bound=$((PARAM_BACKOFF_SECONDS * 2 ** (i - 1)))
    [[ "${bound}" -gt "${max_wait}" ]] && bound="${max_wait}"
    delay=$((RANDOM % bound + 1))
    echo "====> Attempt ${i}/${PARAM_TRIES} lost the push, waiting ${delay}s before the next one." >&2
    sleep "${delay}"
  fi
done

echo "Giving up after ${PARAM_TRIES} push attempts to ${app_catalog_name} in $((SECONDS - start))s. Last error: ${last_error}" >&2
echo "Another build pushed to the catalog between this build's fetch and its push every time; a rerun from failed retries." >&2
exit 1
