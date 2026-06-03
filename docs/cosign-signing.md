# Cosign signing in architect-orb

Starting with v9, architect-orb signs every public artifact it produces
using cosign keyless OIDC. This page describes what gets signed, where the
signatures live, how to verify them, and the constraints that drive the
design.

## What gets signed

| Artifact | Produced by | Signature lands as | Default |
|---|---|---|---|
| Container image (manifest index) | `push-to-registries` | OCI 1.1 referrer tag on the image | `sign: true` |
| Helm chart (OCI) | `push-to-app-catalog`, `push-helm` | OCI 1.1 referrer tag on the chart | `sign: true` |
| Go binary | `go-build` | Sibling `<binary>-<GOOS>-<GOARCH>.bundle` Sigstore bundle | `sign: true` |
| SPDX SBOM attestation (per platform) | `push-to-registries` | Signed cosign DSSE attestation (OCI referrer) on each platform manifest | `sign && sbom` |
| CycloneDX SBOM attestation (per platform) | `push-to-registries` | Signed cosign DSSE attestation (OCI referrer) on each platform manifest | `sign && sbom-cyclonedx` |

In addition, `push-to-registries` produces:

- **SLSA provenance** attestation (`provenance: min` by default; `max` is
  opt-in because it embeds `--build-arg` values verbatim). Stored **inline**
  in the image index (as the `unknown/unknown` manifest entries you see in
  `docker manifest inspect`); currently **unsigned**.
- **SPDX SBOM** attestation (`sbom: true` by default). buildx stores it
  **inline** too. On **public** images with `sign: true`, the *exact* SPDX
  predicate buildx produced is additionally extracted and re-signed as a
  cosign keyless attestation (`--type spdxjson`) so it can be verified
  independently of the registry. The signed predicate is the same SBOM
  content as the inline one — we extract `.predicate` from the buildx in-toto
  statement rather than regenerating the SBOM. It is semantically identical
  but re-serialized (jq and cosign re-marshal the JSON), so the two copies are
  not byte-for-byte equal; compare predicate content, not raw bytes.

BuildKit does not yet support OCI 1.1 referrer storage for its own
attestations, which is why the inline copies remain; `docker buildx
imagetools inspect` displays them with proper labels. The cosign-signed
copies use cosign's own referrer push path.

## Public-only

Private images, private Helm charts, and private repositories are skipped
at runtime. Signing them would publish digest + timestamp metadata to the
public Rekor transparency log, which leaks private build activity.

Public/private classification:

- **Images**: target registry visibility on `registries-data` line.
- **Charts**: source GitHub repo visibility (via the GitHub API).
- **Binaries**: source GitHub repo visibility.

`force-public: true` on `push-to-registries` flips an image to public for
the duration of the job.

## OIDC token mechanics

Cosign signing requires an OIDC token whose `aud` claim matches what
Fulcio's CircleCI federation accepts. The auto-injected `CIRCLE_OIDC_TOKEN_V2`
has the wrong audience.

The `cosign-prepare` command mints a fresh token:

```bash
SIGSTORE_ID_TOKEN=$(circleci run oidc get --claims '{"aud":"sigstore"}' --root-issuer)
```

and exports it via `BASH_ENV` so subsequent `cosign sign` and
`cosign verify` calls in the same job pick it up.

## Verify-after-sign

Every `cosign sign` call is followed immediately by a `cosign verify`
call with the same identity assertions used by downstream consumers:

```bash
cosign verify \
  --certificate-oidc-issuer-regexp '^https://oidc\.circleci\.com' \
  --certificate-identity-regexp '^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$' \
  "$ref"
```

This catches silent regressions where the sign succeeds but the resulting
signature isn't actually verifiable (wrong audience, wrong issuer, identity
mismatch). Without it we'd ship "signed" artifacts that no consumer can
verify and only find out from a downstream report.

## Verifying signatures as a consumer

### Container image

```bash
cosign verify \
  --certificate-oidc-issuer-regexp '^https://oidc\.circleci\.com' \
  --certificate-identity-regexp '^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$' \
  gsoci.azurecr.io/giantswarm/myapp:v1.2.3
```

### Helm chart

```bash
cosign verify \
  --certificate-oidc-issuer-regexp '^https://oidc\.circleci\.com' \
  --certificate-identity-regexp '^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$' \
  gsoci.azurecr.io/charts/giantswarm/myapp:1.2.3
```

### Go binary (Sigstore bundle)

```bash
cosign verify-blob \
  --bundle myapp-linux-amd64.bundle \
  --certificate-oidc-issuer-regexp '^https://oidc\.circleci\.com' \
  --certificate-identity-regexp '^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$' \
  myapp-linux-amd64
```

### SBOM attestations (SPDX / CycloneDX)

SBOMs are signed **per platform**, so verify against a platform digest (not
the index tag). Resolve one with `docker buildx imagetools inspect`, then:

```bash
# SPDX
cosign verify-attestation \
  --type spdxjson \
  --certificate-oidc-issuer-regexp '^https://oidc\.circleci\.com' \
  --certificate-identity-regexp '^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$' \
  gsoci.azurecr.io/giantswarm/myapp@sha256:<platform-digest>

# CycloneDX (when sbom-cyclonedx was enabled)
cosign verify-attestation \
  --type cyclonedx \
  --certificate-oidc-issuer-regexp '^https://oidc\.circleci\.com' \
  --certificate-identity-regexp '^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$' \
  gsoci.azurecr.io/giantswarm/myapp@sha256:<platform-digest>
```

`verify-attestation` succeeds only if a matching signature exists and the
signing identity matches; a substituted or tampered SBOM fails. To read the
verified SBOM payload, pipe the output through
`jq -r '.payload | @base64d | fromjson | .predicate'`.

`verify-attestation` prints one DSSE envelope per matching attestation, and
attestations accumulate when the same content-addressed digest is attested
more than once (e.g. a rebuild of the same image). So that `jq` can emit
several concatenated predicates — append `| jq -s 'last'` (or otherwise
select) to pick a single one.

## Identity model and the friendly-source-repo OID

CircleCI's Fulcio integration sets the cert's SAN URI to a UUID-based
identity:

```
https://circleci.com/api/v2/projects/<project-uuid>/pipeline-definitions/<pipeline-uuid>
```

That's stable but opaque. The cert also carries the friendly
`github.com/<org>/<repo>` value in **OID `1.3.6.1.4.1.57264.1.12`**
(Sigstore "source repository URI" extension).

In cosign v3.0.x, `cosign verify` does not expose this OID as a CLI flag.
A policy file (`--policy …rego`) can match on it, but that's heavy for
most consumers. The SAN regex above catches: invalid signature chain,
wrong OIDC issuer, wrong overall SAN shape. Stronger repo-pinning awaits
cosign exposing the newer Sigstore OIDs via flags.

## Inline attestations vs. referrer artifacts

| Artifact type | Storage | Why |
|---|---|---|
| Cosign image signature | OCI 1.1 referrer | cosign's own implementation, registry-agnostic |
| Cosign chart signature | OCI 1.1 referrer | same |
| Signed SBOM attestation (SPDX / CycloneDX) | OCI 1.1 referrer (public images) | cosign attest uses its own referrer push path |
| Provenance | Inline (`unknown/unknown` entry in index) | BuildKit doesn't yet support referrer storage for attestations |
| Inline SBOM (SPDX) | Inline (`unknown/unknown` entry in index) | buildx storage; the signed copy above mirrors this exact predicate |

Inspect inline attestations with:

```bash
docker buildx imagetools inspect --format '{{ json .Provenance }}' gsoci.azurecr.io/giantswarm/myapp:v1.2.3
docker buildx imagetools inspect --format '{{ json .SBOM }}'       gsoci.azurecr.io/giantswarm/myapp:v1.2.3
```

When BuildKit ships referrer-mode attestation storage, we will move
provenance/SBOM there too.

## Opt-out

If a specific repo can't ship signing (e.g. publishing to a registry that
doesn't support OCI 1.1 referrers), opt the relevant job out:

```yaml
- architect/push-to-registries:
    image: giantswarm/myapp
    sign: false
    provenance: false
    sbom: false
```
