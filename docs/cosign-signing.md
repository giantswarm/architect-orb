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

In addition, `push-to-registries` produces:

- **SLSA provenance** attestation (`provenance: min` by default; `max` is
  opt-in because it embeds `--build-arg` values verbatim).
- **SPDX SBOM** attestation (`sbom: true` by default).

Both are stored **inline** in the image index (as the `unknown/unknown`
manifest entries you see in `docker manifest inspect`) because BuildKit
does not yet support OCI 1.1 referrer storage for attestations.
`docker buildx imagetools inspect` displays them with proper labels.

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
| Provenance | Inline (`unknown/unknown` entry in index) | BuildKit doesn't yet support referrer storage for attestations |
| SBOM | Inline (`unknown/unknown` entry in index) | same |

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
