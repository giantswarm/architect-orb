# Migrating from architect-orb v8.x to v9

v9 collapses the dual single-arch / multi-arch paths into a single buildx
path, drops several deprecated parameters and commands, and turns on
cosign signing, SLSA provenance, SPDX SBOMs, and OCI labels by default.

This page lists every breaking change with a before/after snippet, plus what
you get automatically without changing anything.

## Breaking changes

### 1. `push-to-registries-multiarch` job → removed

The job was deprecated in v7.0. Rename to `push-to-registries`.

```yaml
# v8.x
- architect/push-to-registries-multiarch:
    image: giantswarm/myapp

# v9
- architect/push-to-registries:
    image: giantswarm/myapp
```

### 2. `multiarch:` parameter on `push-to-registries` → removed

The job always uses `docker buildx` now. Consumers of the previous default
(`multiarch: false`) get multi-arch builds automatically.

```yaml
# v8.x
- architect/push-to-registries:
    image: giantswarm/myapp
    multiarch: true

# v9
- architect/push-to-registries:
    image: giantswarm/myapp
```

### 3. `architecture` (singular) parameter on `go-build` → removed

Replaced entirely by `architectures` (plural). Matrix-based callers
switch to a single job with a comma-separated list.

```yaml
# v8.x (matrix)
- architect/go-build:
    matrix:
      parameters:
        architecture: ["linux/amd64", "linux/arm64"]
    binary: myapp

# v9
- architect/go-build:
    binary: myapp
    architectures: "linux/amd64,linux/arm64"
```

Tests run once instead of per-arch; CircleCI startup overhead is paid once.

### 4. `os` parameter on `go-build` → removed

The parameter has been ignored since v8.1. Remove it from your config.

### 5. `image-build-with-docker` and `image-push-to-registries` commands → removed

These backed the single-arch `docker build` / `docker push` path inside the
orb. Nothing else referenced them. Direct command callers (rare) switch to
`image-build-and-push` (see §6).

### 6. `image-build-and-push-multiarch` command → renamed to `image-build-and-push`

Multi-arch is no longer a distinguishing trait. Direct command callers
update the name; `push-to-registries` job consumers are unaffected.

### 7. `push-helm` legacy auth parameters → removed

`registry_url`, `username_envar`, `password_envar` on the `push-helm`
command (and the two `[deprecated]` legacy OCI auth/push run steps that
read them) are gone. The live OCI push flow uses `generate-github-token`
and the giantswarm OCI authenticator; the registry hosts (`gsoci`,
`gsociprivate`) and `ACR_GSOCI_*` / `ACR_GSOCIPRIVATE_*` env vars are
hardcoded.

If you were overriding any of these, you need to push to your own registry
out-of-band — the orb only targets the giantswarm registries.

## What's on by default in v9

No config changes needed; these all activate automatically on the v9 jobs:

| Feature | Default | Scope | Opt-out |
|---|---|---|---|
| Cosign keyless image signing | `sign: true` | `push-to-registries` (public images) | `sign: false` |
| Cosign keyless chart signing | `sign: true` | `push-to-app-catalog` (public charts) | `sign: false` |
| Cosign keyless binary signing (`.bundle` sidecars) | `sign: true` | `go-build` (public repos) | `sign: false` |
| SLSA provenance attestation | `provenance: min` | `push-to-registries` | `provenance: false` |
| SPDX SBOM attestation | `sbom: true` | `push-to-registries` | `sbom: false` |
| OCI image labels + index annotations | `oci-labels: true` | `push-to-registries` | `oci-labels: false` |
| hadolint Dockerfile lint | `hadolint: warn` | `push-to-registries` | `hadolint: skip` |
| `cosign verify` after every `cosign sign` | always | image / chart paths | — |

Private images, charts, and repos are skipped for signing at runtime so
nothing leaks into the public Rekor transparency log.

See [Cosign signing](./cosign-signing.md) for verification commands and the
end-to-end identity model.

## New surface in v9

- `upload-release-assets` job — attaches workspace-persisted
  `<binary>-<GOOS>-<GOARCH>` files plus their `.bundle` siblings to the
  GitHub Release for the current tag. See CHANGELOG for parameters.
- `cosign-prepare` command — mints a sigstore-audience CircleCI OIDC
  token and exports `SIGSTORE_ID_TOKEN` via `BASH_ENV`. Used internally by
  the signing steps; direct callers are rare.

## Quick sanity check after migration

```bash
# Make sure no v8-only parameters remain.
grep -nE 'multiarch:|architecture:[^s]|push-to-registries-multiarch|password_envar|username_envar|registry_url' .circleci/config.yml || echo "OK"
```
