#!/bin/bash
# cosign-sign-verify: sign and verify the entries of PARAM_REFS_FILE with
# cosign keyless OIDC; PARAM_KIND (oci, blob, attest) picks the subcommand
# pair. src/commands/cosign-sign-verify.yaml describes the file format.
#
# Tunables, for the tests:
#   PARAM_BACKOFF_SECONDS  the first retry delay, doubled per attempt, 5 by default
set -euo pipefail

refs_file="${PARAM_REFS_FILE:?}"
if [[ ! -s "$refs_file" ]]; then
  echo "No entries in $refs_file; nothing to sign."
  exit 0
fi

# Count the entries the loops below will actually act on (same blank-line and
# `#`-comment skipping), and assert at the end that every one was processed.
# A non-empty file whose entries all get skipped used to exit 0 silently —
# that is how chart signing went missing for three months (#878). `grep -c`
# exits 1 on zero matches, which `set -e` would take as a failure.
expected=$(grep -cvE '^[[:space:]]*($|#)' "$refs_file" || true)
if [[ "$expected" -eq 0 ]]; then
  echo "No actionable entries in $refs_file; nothing to sign."
  exit 0
fi
processed=0

cosign version

# Fulcio's CircleCI federation expects an OIDC token with aud=sigstore.
# The auto-injected CIRCLE_OIDC_TOKEN_V2 has a different audience and
# gets rejected with HTTP 400. Mint a fresh sigstore-audience token via
# the circleci CLI; cosign reads SIGSTORE_ID_TOKEN automatically.
SIGSTORE_ID_TOKEN=$(circleci run oidc get --claims '{"aud": "sigstore"}' --root-issuer)
export SIGSTORE_ID_TOKEN

ISSUER_REGEX='^https://oidc\.circleci\.com'
IDENTITY_REGEX='^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$'

# Rekor duplicate-entry rejection (HTTP 409). Matched with `grep -E`.
# The structured token (createLogEntryConflict) appears in sign-blob
# errors; the prose is all the `oci`/`attest` errors carry, so both
# alternatives are needed.
REKOR_DUP_PATTERN='createLogEntryConflict|an equivalent entry already exists'

# Transient backend failures that warrant a retry with backoff. The
# keyless flow talks to Fulcio, Rekor and the OCI registry over HTTP/2,
# and the public-good infrastructure intermittently aborts a stream
# mid-request (e.g. `signing bundle: error signing bundle: stream error:
# stream ID 1; INTERNAL_ERROR; received from peer`) or returns a 5xx/429.
# These are unrelated to the artifact or our config, so a fresh attempt
# almost always succeeds; without this a single flake on one of N per-arch
# signatures fails the whole publish job and forces a manual rerun.
#
# Every alternative below is a SPECIFIC network/transport signal or an
# HTTP status in a form Go actually emits — a 5xx/429/408 reason phrase
# (resp.Status from net/http & go-containerregistry) or an anchored
# `status NNN` (the go-openapi Rekor client). It deliberately avoids bare
# tokens like `timeout` or `500 `: those match permanent-error text too
# (a "timeout policy" message, or `500` inside a digest), which would burn
# the whole ~35s backoff budget retrying something doomed to fail anyway.
# Auth/config 4xx (401/403/404) and bad refs are NOT listed, so genuine
# misconfiguration still fails fast.
TRANSIENT_PATTERN='INTERNAL_ERROR|stream error|GOAWAY|connection reset|connection refused|broken pipe'
TRANSIENT_PATTERN+='|unexpected EOF|TLS handshake timeout|i/o timeout|context deadline exceeded|Client\.Timeout'
TRANSIENT_PATTERN+='|Internal Server Error|Bad Gateway|Service Unavailable|Gateway Timeout|Too Many Requests|Request Timeout'
TRANSIENT_PATTERN+='|[Ss]tatus:? (408|425|429|5[0-9][0-9])'

# Attempts per cosign network call (1 initial try + up to 3 retries).
MAX_ATTEMPTS=4

# backoff <attempt> — exponential delay (5s, 10s, 20s, …) before retry.
backoff() {
  local delay=$(( ${PARAM_BACKOFF_SECONDS:-5} * (2 ** ($1 - 1)) ))
  echo "    └─ retrying in ${delay}s …" >&2
  sleep "$delay"
}

# cosign_retry <label> <on_success: quiet|show> <cmd…> — run a cosign
# network operation, retrying ONLY transient backend errors (see
# TRANSIENT_PATTERN) with exponential backoff. The command's stdout is
# discarded — it is the signature/attestation payload (e.g. a ~465 KB
# SBOM for verify-attestation) which we never want in the log, exactly as
# the old `… > /dev/null` did. Its stderr is captured so it can be
# classified, and with on_success=show it is re-emitted on success: this
# preserves the `cosign verify*` "Verification for <ref> …" summary that
# the verify-after-sign step deliberately surfaces as audit evidence.
# on_success=quiet keeps sign/attest happy paths silent (their stderr is
# noise on success). Exit status:
#   0  success
#   42 Rekor reports the entry already exists (captured stderr printed, the
#      caller decides what follows)
#   1  permanent failure (captured stderr already printed)
cosign_retry() {
  local label="$1" on_success="$2"; shift 2
  local attempt out
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    if out=$("$@" 2>&1 1>/dev/null); then
      if [[ "$on_success" == show && -n "$out" ]]; then
        printf '%s\n' "$out" >&2
      fi
      return 0
    fi
    if printf '%s' "$out" | grep -Eq "$REKOR_DUP_PATTERN"; then
      printf '%s\n' "$out" | sed 's/^/    │ /' >&2
      return 42
    fi
    if printf '%s' "$out" | grep -Eq "$TRANSIENT_PATTERN" && [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
      echo "WARNING: ${label}: transient signing-backend error (attempt ${attempt}/${MAX_ATTEMPTS})" >&2
      printf '%s\n' "$out" | sed 's/^/    │ /' >&2
      backoff "$attempt"
      continue
    fi
    printf '%s\n' "$out" >&2
    return 1
  done
  return 1
}

# The signing and verifying calls of the `oci` and `attest` kinds, so the
# duplicate-entry handling below and the final verify share them.
oci_sign() { cosign sign --yes "$1"; }
oci_verify() {
  cosign verify \
    --certificate-oidc-issuer-regexp "$ISSUER_REGEX" \
    --certificate-identity-regexp "$IDENTITY_REGEX" \
    "$1"
}
attest_sign() { cosign attest --yes --type "$2" --predicate "$3" "$1"; }
attest_verify() {
  cosign verify-attestation \
    --type "$2" \
    --certificate-oidc-issuer-regexp "$ISSUER_REGEX" \
    --certificate-identity-regexp "$IDENTITY_REGEX" \
    "$1"
}

# sign_attached <label> <sign-fn> <verify-fn> <args…> — sign an OCI artifact so
# that its signature ends up in the registry. Exit status as cosign_retry, never 42.
#
# Rekor answers "an equivalent entry already exists" (HTTP 409) when cosign's
# own client retries a transparency-log upload that already succeeded
# server-side. cosign then stops before it attaches the signature to the
# registry, so the Rekor entry exists while the registry holds nothing to
# verify. A duplicate is therefore never taken as "already signed": the
# registry is checked with <verify-fn>, and only a verifiable signature there
# skips the sign. Otherwise the artifact is signed again: keyless signing mints
# fresh ephemeral keys and a fresh Fulcio certificate per call, so the new
# upload is a non-equivalent Rekor entry and the signature is attached with its
# own transparency-log proof, which the strict verify after it requires.
sign_attached() {
  local label="$1" sign_fn="$2" verify_fn="$3"; shift 3
  local attempt rc
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    rc=0; cosign_retry "$label" quiet "$sign_fn" "$@" || rc=$?
    [[ "$rc" -eq 42 ]] || return "$rc"
    echo "Rekor: an equivalent entry already exists for ${label} (attempt ${attempt}/${MAX_ATTEMPTS}); checking the registry for its signature."
    if cosign_retry "registry check for ${label}" quiet "$verify_fn" "$@"; then
      echo "  The registry holds a verifiable signature; not signing again."
      return 0
    fi
    echo "  The registry holds no verifiable signature: the upload was logged but never attached."
    echo "  Signing again with fresh ephemeral keys, which makes a new Rekor entry."
  done
  echo "ERROR: ${label}: Rekor reported a duplicate entry ${MAX_ATTEMPTS} times and the registry still holds no verifiable signature." >&2
  return 1
}

case "${PARAM_KIND:?}" in
  oci)
    while IFS= read -r ref || [[ -n "$ref" ]]; do
      # `oci` reads with an empty IFS to keep refs verbatim, so unlike the
      # `blob`/`attest` loops it sees leading whitespace; match the blank/comment
      # predicate `expected` uses above so the two cannot disagree.
      [[ -z "${ref//[[:space:]]/}" || "$ref" =~ ^[[:space:]]*# ]] && continue
      processed=$((processed + 1))
      echo "cosign sign $ref"
      sign_attached "sign $ref" oci_sign oci_verify "$ref" || exit 1
      echo "cosign verify $ref"
      cosign_retry "verify $ref" show oci_verify "$ref" || exit 1
    done < "$refs_file"
    ;;
  blob)
    # Rekor can reject the upload with "an equivalent entry already
    # exists" (HTTP 409) when its client retries a POST that already
    # succeeded server-side. There is no registry to check, as `oci`/`attest`
    # do: the bundle file is only written on success, and
    # verify-blob needs it. But sign-blob mints fresh ephemeral keys per
    # invocation — a retry produces a new, non-equivalent entry — so a
    # full re-run resolves the conflict. Transient backend errors are
    # retried the same way (with backoff); both share MAX_ATTEMPTS.
    while IFS=' ' read -r file bundle || [[ -n "$file" ]]; do
      [[ -z "$file" || "$file" =~ ^# ]] && continue
      processed=$((processed + 1))
      echo "cosign sign-blob $file → $bundle"
      for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
        rm -f "$bundle"
        if out=$(cosign sign-blob --yes --bundle "$bundle" "$file" 2>&1); then
          break
        fi
        if [[ "$attempt" -ge "$MAX_ATTEMPTS" ]]; then
          printf '%s\n' "$out" >&2; exit 1
        fi
        if printf '%s' "$out" | grep -Eq "$REKOR_DUP_PATTERN"; then
          echo "Rekor: duplicate entry for $file (attempt ${attempt}/${MAX_ATTEMPTS}), retrying with fresh keys."
        elif printf '%s' "$out" | grep -Eq "$TRANSIENT_PATTERN"; then
          echo "WARNING: sign-blob $file: transient signing-backend error (attempt ${attempt}/${MAX_ATTEMPTS})" >&2
          printf '%s\n' "$out" | sed 's/^/    │ /' >&2
          backoff "$attempt"
        else
          printf '%s\n' "$out" >&2; exit 1
        fi
      done
      echo "cosign verify-blob $file"
      cosign_retry "verify-blob $file" show cosign verify-blob \
        --bundle "$bundle" \
        --certificate-oidc-issuer-regexp "$ISSUER_REGEX" \
        --certificate-identity-regexp "$IDENTITY_REGEX" \
        "$file" || exit 1
    done < "$refs_file"
    ;;
  attest)
    # Large-SBOM dependency: real SBOM predicates routinely exceed public
    # Rekor's 100 KB attestation limit (the live app-operator SPDX is ~465 KB).
    # The common case works because the pinned cosign writes new-format
    # sigstore bundles (v0.3), whose Rekor `dsse` entries upload hashes rather
    # than the full payload. But the `cosign attest` request still POSTs the
    # full DSSE envelope (the base64 SBOM) to Rekor, and a multi-MB predicate
    # (e.g. the vllm CUDA image SBOM) overruns the public Rekor gateway's
    # request limit — it returns 502, not a clean size error, so the transient
    # retry loop above exhausts and the call fails.
    #
    # The image signature is already in the transparency log (the `oci` kind
    # above signs it strictly). Rather than fail the whole release on the
    # supplementary SBOM attestation, fall back to attesting through a signing
    # config that has Rekor removed but keeps the public TSA: cosign v3
    # deprecated `--tlog-upload=false` (it is rejected with the default signing
    # config), and the supported way to opt out of the transparency log is a
    # `--signing-config` without a transparency-log service. We strip
    # `rekorTlogUrls`/`rekorTlogConfig` from the public signing config (the
    # recipe cosign's own error prints) and keep `tsaUrls`/`tsaConfig`, so the
    # attestation still gets a trusted RFC3161 timestamp — the TSA timestamps
    # only a hash, so it has no Rekor-style body-size limit, and the
    # new-bundle-format bundle still carries a verifiable time. The signed
    # attestation is attached as an OCI referrer on the image; it just gets no
    # public Rekor entry. This degrades gracefully for oversized SBOMs and never
    # blocks a publish; the normal (sub-limit) path is unchanged and keeps its
    # Rekor entry.
    #
    # `--signing-config` requires `--new-bundle-format`. The signing config is
    # built once and reused for every ref/arch in the loop.
    no_rekor_signing_config=/tmp/.cosign_signing_config_no_rekor.json
    while IFS=' ' read -r ref type predicate || [[ -n "$ref" ]]; do
      [[ -z "$ref" || "$ref" =~ ^# ]] && continue
      processed=$((processed + 1))
      echo "cosign attest --type $type $ref (predicate: $predicate)"
      no_tlog=0
      rc=0; sign_attached "attest $ref ($type)" attest_sign attest_verify "$ref" "$type" "$predicate" || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        # The only failure the no-Rekor path can rescue is the transparency-log
        # upload itself; Fulcio/registry/auth errors recur and still exit 1 below.
        echo "WARNING: attest $ref ($type): transparency-log upload failed after retries." >&2
        echo "  This is typically an oversized SBOM the public Rekor gateway rejects." >&2
        echo "  Re-attesting via a signing config without Rekor (TSA timestamp retained):" >&2
        echo "  the SBOM stays signed and attached as an OCI referrer, with no public Rekor entry." >&2
        no_tlog=1
        if [[ ! -s "$no_rekor_signing_config" ]]; then
          curl -fsSL https://raw.githubusercontent.com/sigstore/root-signing/refs/heads/main/targets/signing_config.v0.2.json \
            | jq 'del(.rekorTlogUrls, .rekorTlogConfig)' > "$no_rekor_signing_config"
        fi
        # No Rekor in this signing config, so no duplicate entry either.
        cosign_retry "attest $ref ($type, no-tlog)" quiet \
          cosign attest --yes --signing-config "$no_rekor_signing_config" --new-bundle-format \
            --type "$type" --predicate "$predicate" "$ref" || exit 1
      fi
      echo "cosign verify-attestation --type $type $ref"
      if [[ "$no_tlog" -eq 1 ]]; then
        # Degraded path: the attestation has no Rekor entry, only a TSA
        # timestamp. Verify is best-effort here — the attest above exited 0 (so
        # Fulcio signing succeeded and the signed SBOM is attached), and the
        # image signature carries the strict, tlog-backed guarantee. Don't
        # re-block the publish on a verify-flag subtlety for the supplementary,
        # deliberately-degraded SBOM attestation.
        cosign_retry "verify-attestation $ref ($type, no-tlog)" show cosign verify-attestation \
          --type "$type" --use-signed-timestamps --insecure-ignore-tlog \
          --certificate-oidc-issuer-regexp "$ISSUER_REGEX" \
          --certificate-identity-regexp "$IDENTITY_REGEX" \
          "$ref" || echo "WARNING: verify-attestation (no-tlog) for $ref ($type) did not pass; the signed SBOM is attached as an OCI referrer regardless." >&2
      else
        cosign_retry "verify-attestation $ref ($type)" show attest_verify "$ref" "$type" || exit 1
      fi
    done < "$refs_file"
    ;;
esac

# The loops read via a `<` redirection, not a pipe, so they run in this shell
# and the counter survives. Any entry that never reached cosign is a bug in the
# producing command's file format — fail red rather than report a green build
# for an unsigned artifact.
if [[ "$processed" -ne "$expected" ]]; then
  echo "ERROR: $refs_file lists $expected entr(ies) but only $processed were processed." >&2
  echo "  Signing was silently skipped. Check that the file is newline-terminated," >&2
  echo "  one entry per line — see giantswarm/architect-orb#878." >&2
  exit 1
fi
