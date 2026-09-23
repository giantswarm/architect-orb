#!/bin/bash
# The architect and app-build-suite executors each compute the build version
# with the gitsemver they bundle: push-to-registries tags the image in the
# first, push-to-app-catalog stamps the chart, and the image reference in it,
# in the second. For the same commit both must compute the same version, or a
# branch chart names an image tag that was never pushed and its pods never
# start. Runs the two executor images of this revision (src/executors) against
# one repository at a dev commit (one commit after a release tag, on a branch)
# and fails when their `gitsemver get` differ.
set -euo pipefail

image_of() {
  awk '$1 == "image:" { print $2; exit }' "src/executors/$1.yaml"
}

repo="$(mktemp -d)"
trap 'rm -rf "${repo}"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=architect GIT_AUTHOR_EMAIL=architect@example.com
export GIT_COMMITTER_NAME=architect GIT_COMMITTER_EMAIL=architect@example.com
export GIT_AUTHOR_DATE=2026-01-27T09:49:59Z GIT_COMMITTER_DATE=2026-01-27T09:49:59Z
git -C "${repo}" init -q -b main
git -C "${repo}" commit -q --allow-empty -m release
git -C "${repo}" tag v1.2.3
git -C "${repo}" checkout -q -b feature/executors-agree
git -C "${repo}" commit -q --allow-empty -m next

declare -A versions
for executor in architect app-build-suite; do
  image="$(image_of "${executor}")"
  versions[${executor}]="$(docker run --rm -v "${repo}:/src:ro" -w /src --entrypoint /bin/sh "${image}" \
    -c 'git config --global --add safe.directory /src && gitsemver --version >&2 && gitsemver get')"
  echo "${executor} (${image}): ${versions[${executor}]}"
done

if [[ "${versions[architect]}" != "${versions[app-build-suite]}" ]]; then
  echo "ERROR: the executors compute different dev versions for one commit, so a branch chart would reference an image tag that is never pushed. Bundle the same gitsemver in both images." >&2
  exit 1
fi
