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
# and its push ("fetch first"). Every attempt therefore starts from the
# remote's current head: fetch, reset onto it, merge the chart into the
# catalog's index, commit and push. A lost race waits a random time up to a
# doubling bound (2, 4, 8, ... seconds for a base of 2, at most 30) before the
# next attempt, so builds that collided once spread out instead of colliding
# again.
set -euo pipefail

readonly max_wait=30

app_catalog_name="$(cat .app_catalog_name)"
readonly app_catalog_name
readonly build_dir="${PWD}/build"

cd .app_catalog

branch="$(git rev-parse --abbrev-ref HEAD)"
readonly branch

last_error=""
for i in $(seq 1 "${PARAM_TRIES}"); do
  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: git fetch origin ${branch} && git reset --hard FETCH_HEAD"
  git fetch -q --depth=1 origin "${branch}"
  git reset -q --hard FETCH_HEAD
  git clean -q -fd

  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: helm repo index --url https://giantswarm.github.io/${app_catalog_name} --merge index.yaml ${build_dir}"
  helm repo index --url "https://giantswarm.github.io/${app_catalog_name}" --merge index.yaml "${build_dir}"

  echo "====> Attempt ${i}/${PARAM_TRIES}: Running: cp -r ${build_dir}/* ."
  cp -r "${build_dir}"/* .

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

echo "Giving up after ${PARAM_TRIES} push attempts to ${app_catalog_name}. Last error: ${last_error}" >&2
echo "Another build pushed to the catalog between this build's fetch and its push every time; a rerun from failed retries." >&2
exit 1
