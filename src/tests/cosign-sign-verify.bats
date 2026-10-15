#!/usr/bin/env bats
# Tests of src/scripts/cosign-sign-verify.sh: a Rekor duplicate-entry answer
# never leaves an OCI artifact unsigned in the registry. The script runs as
# CircleCI runs a step, under `bash -eo pipefail`.
# cosign and circleci are stubs on the PATH. The cosign stub keeps the registry
# as files in REGISTRY: `sign`/`attest` play the outcomes listed in
# SIGN_OUTCOMES one call after the other, `verify`/`verify-attestation` pass
# only when the registry holds the signature. Outcomes:
#   ok        the signature is logged and attached
#   dup       Rekor answers 409 and nothing is attached, as when cosign's own
#             client retried a logged upload and stopped before the attach
#   dup-held  Rekor answers 409 and the registry already holds a signature
# Every cosign call is recorded in COSIGN_CALLS.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/cosign-sign-verify.sh"
  export PARAM_REFS_FILE="${BATS_TEST_TMPDIR}/refs"
  export PARAM_BACKOFF_SECONDS=0
  export REGISTRY="${BATS_TEST_TMPDIR}/registry"
  export COSIGN_CALLS="${BATS_TEST_TMPDIR}/cosign.calls"
  export SIGN_OUTCOMES="${BATS_TEST_TMPDIR}/sign.outcomes"
  mkdir -p "${REGISTRY}" "${BATS_TEST_TMPDIR}/bin"
  : > "${COSIGN_CALLS}"

  cat > "${BATS_TEST_TMPDIR}/bin/circleci" <<'STUB'
#!/bin/bash
echo "stub-oidc-token"
STUB
  cat > "${BATS_TEST_TMPDIR}/bin/cosign" <<'STUB'
#!/bin/bash
echo "$*" >> "${COSIGN_CALLS}"
ref="${*: -1}"
case "$1" in
  version) echo "cosign stub" ;;
  sign|attest)
    held="${REGISTRY}/${1/sign/sig}-${ref//[^a-zA-Z0-9]/_}"
    outcome=$(head -n 1 "${SIGN_OUTCOMES}")
    sed -i 1d "${SIGN_OUTCOMES}"
    case "${outcome}" in
      ok) touch "${held}" ;;
      dup-held)
        touch "${held}"
        echo "Error: signing ${ref}: [POST /api/v1/log/entries][409] createLogEntryConflict an equivalent entry already exists in the transparency log" >&2
        exit 1 ;;
      dup)
        echo "Error: signing ${ref}: [POST /api/v1/log/entries][409] createLogEntryConflict an equivalent entry already exists in the transparency log" >&2
        exit 1 ;;
    esac ;;
  verify|verify-attestation)
    held="${REGISTRY}/$([[ "$1" == verify ]] && echo sig || echo attest)-${ref//[^a-zA-Z0-9]/_}"
    if [[ -e "${held}" ]]; then
      echo "Verification for ${ref} -- The cosign claims were validated" >&2
    else
      echo "Error: no signatures found" >&2
      exit 1
    fi ;;
esac
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/circleci" "${BATS_TEST_TMPDIR}/bin/cosign"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

outcomes() { printf '%s\n' "$@" > "${SIGN_OUTCOMES}"; }
calls() { grep -c "^$1 " "${COSIGN_CALLS}" || true; }

REF="gsoci.azurecr.io/giantswarm/muster@sha256:79ba113b"

@test "oci: a signed digest verifies" {
  echo "${REF}" > "${PARAM_REFS_FILE}"
  outcomes ok
  PARAM_KIND=oci run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(calls sign)" -eq 1 ]
  [[ "$output" == *"Verification for ${REF}"* ]]
}

@test "oci: a Rekor duplicate with nothing in the registry signs again and verifies" {
  echo "${REF}" > "${PARAM_REFS_FILE}"
  outcomes dup ok
  PARAM_KIND=oci run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(calls sign)" -eq 2 ]
  [[ "$output" == *"│ Error: signing ${REF}"*"an equivalent entry already exists"* ]]
  [[ "$output" == *"The registry holds no verifiable signature"* ]]
  [[ "$output" == *"Verification for ${REF}"* ]]
  [ -e "${REGISTRY}/sig-${REF//[^a-zA-Z0-9]/_}" ]
}

@test "oci: a Rekor duplicate whose signature the registry holds is not signed again" {
  echo "${REF}" > "${PARAM_REFS_FILE}"
  outcomes dup-held
  PARAM_KIND=oci run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(calls sign)" -eq 1 ]
  [[ "$output" == *"The registry holds a verifiable signature; not signing again."* ]]
  [[ "$output" == *"Verification for ${REF}"* ]]
}

@test "oci: a Rekor duplicate that never ends in a registry signature fails the step" {
  echo "${REF}" > "${PARAM_REFS_FILE}"
  outcomes dup dup dup dup
  PARAM_KIND=oci run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ "$(calls sign)" -eq 4 ]
  [[ "$output" == *"the registry still holds no verifiable signature"* ]]
}

@test "attest: a Rekor duplicate with nothing in the registry attests again and verifies" {
  echo "${REF} spdxjson ${BATS_TEST_TMPDIR}/sbom.json" > "${PARAM_REFS_FILE}"
  outcomes dup ok
  PARAM_KIND=attest run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(calls attest)" -eq 2 ]
  [[ "$output" == *"Verification for ${REF}"* ]]
}

@test "attest: a Rekor duplicate whose attestation the registry holds is not attested again" {
  echo "${REF} spdxjson ${BATS_TEST_TMPDIR}/sbom.json" > "${PARAM_REFS_FILE}"
  outcomes dup-held
  PARAM_KIND=attest run bash -eo pipefail "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(calls attest)" -eq 1 ]
}
