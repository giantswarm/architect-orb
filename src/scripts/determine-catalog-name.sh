#!/bin/bash
# architect/determine-catalog-name: choose the app catalog a chart is pushed to.
#
# Inputs, set by the command from its parameters:
#   PARAM_APP_CATALOG       the production catalog
#   PARAM_APP_CATALOG_TEST  the test catalog
#   PARAM_ON_TAG            1 (true): a tag releases, 0 (false): master releases.
#                           CircleCI renders a boolean parameter in a step's
#                           environment as 1 or 0; true and false are taken
#                           as well, for a run by hand.
# CircleCI's own:
#   CIRCLE_TAG              the tag a tag pipeline was triggered by; empty on a
#                           branch pipeline
#   CIRCLE_BRANCH           the branch a branch pipeline was triggered by
#   CIRCLE_SHA1             the commit the pipeline builds
#
# Writes .app_catalog_name (the catalog) and .reference (the tag, or the commit
# when on_tag is false).
#
# A release goes to the production catalog, everything else to the test
# catalog. A tag whose version carries a pre-release (v1.2.3-rc.1,
# api/v2.0.0-beta.1) is a release candidate, not a release: it goes to the test
# catalog like a branch build. Its chart still reaches the OCI registry
# unchanged. The production catalog feeds every management cluster's
# AppCatalogEntries, whose `latest` label, happa and kubectl-gs would otherwise
# offer the candidate as the newest version. Build metadata (+...) is no
# pre-release.
set -euo pipefail

on_tag() {
  case "${PARAM_ON_TAG}" in
    1 | true) return 0 ;;
    0 | false) return 1 ;;
    *)
      echo "PARAM_ON_TAG is \"${PARAM_ON_TAG}\", expected 1 or 0." >&2
      exit 1
      ;;
  esac
}

is_prerelease() {
  local version="${1##*/}"
  version="${version%%+*}"
  [[ "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+- ]]
}

if on_tag; then
  if [[ -n "${CIRCLE_TAG:-}" ]] && ! is_prerelease "${CIRCLE_TAG}"; then
    catalog="${PARAM_APP_CATALOG}"
  else
    catalog="${PARAM_APP_CATALOG_TEST}"
  fi
  reference="${CIRCLE_TAG:-}"
else
  if [[ "${CIRCLE_BRANCH:-}" == master ]]; then
    catalog="${PARAM_APP_CATALOG}"
  else
    catalog="${PARAM_APP_CATALOG_TEST}"
  fi
  reference="${CIRCLE_SHA1:-}"
fi

if [[ -n "${CIRCLE_TAG:-}" ]] && is_prerelease "${CIRCLE_TAG}"; then
  echo "The tag ${CIRCLE_TAG} is a pre-release: its chart goes to the test catalog ${catalog}."
fi
echo -n "${catalog}" | tee .app_catalog_name
echo
echo -n "${reference}" | tee .reference
echo
