# push-to-registries

Joins the per-architecture digests produced by [`build-image`](build-image.md)
into one tagged, signed multi-arch index in each configured registry.

**This job does not build the image.** Since v10 the build lives in
`build-image`, one job per architecture. See
[Migrating from v9 to v10](../migration-v9-to-v10.md) if you are moving a config
that had `push-to-registries` do everything.

```
build-image (linux/amd64, small)      \
                                        --> push-to-registries
build-image (linux/arm64, arm.medium) /     merge -> tag -> sign -> attest
```

The index is tagged with the version produced by `gitsemver get`. The registry
hosts come from `registries-data` (or the `REGISTRIES_DATA_BASE64` environment
variable) — `image` should only be `repository/image`, no host. `tag-suffix` adds
a suffix to the generated tag.

## Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION
workflows:
  build:
    jobs:
      - architect/go-build:
          binary: myapp

      - architect/build-image:
          name: build-image-amd64
          platform: linux/amd64
          resource_class: small
          requires: [architect/go-build]

      - architect/build-image:
          name: build-image-arm64
          platform: linux/arm64
          resource_class: arm.medium
          requires: [architect/go-build]

      - architect/push-to-registries:
          image: giantswarm/myapp
          platforms: "linux/amd64,linux/arm64"
          requires: [build-image-amd64, build-image-arm64]
```

By default this emits OCI index annotations and — on public images — a cosign
keyless signature on the index *and* on each platform's SPDX SBOM attestation.
Each is individually controllable: `sbom: true|false`, `oci-labels: true|false`,
`sign: true|false`. Set `sbom-cyclonedx: true` to add a (signed, on public)
CycloneDX SBOM. SLSA provenance and the inline SPDX SBOM are produced by
`build-image`, not here.

### Restricting to release tags

```yaml
- architect/push-to-registries:
    platforms: "linux/amd64,linux/arm64"
    requires: [build-image-amd64, build-image-arm64]
    filters:
      tags:
        only: /^v[0-9]+\.[0-9]+\.[0-9]+$/
      branches:
        ignore: /.*/
```

The `build-image` jobs need the same filters. On a branch path that only
validates the Dockerfile, the `build-image` jobs run with `push: false` and there
is no `push-to-registries` job at all — there is no digest to join.

### Custom OCI index annotations

Only the prefixes `imagetools create` accepts are allowed: `index:`,
`index-descriptor:` and `manifest-descriptor:`. A bare key or a `manifest:`
prefix is rejected with an explanation — per-platform annotations belong on
`build-image`, which is the only place that can attach them to a platform
manifest.

```yaml
- architect/push-to-registries:
    annotations: |
      index:io.giantswarm.klaus.type=toolchain
```

## How the merge works

**`docker buildx imagetools create`, not `docker manifest create`.** Each
`build-image` job pushed an index containing its image manifest *and* its
attestation manifest. `imagetools` copies the whole child index, preserving the
attestation manifests and the `vnd.docker.reference.*` annotations that link each
one to the platform manifest it describes. `docker manifest create` strips them,
which would silently break the SPDX signing below.

**Once per registry.** `imagetools create` builds a manifest by reference and
requires its sources to already exist in the registry it writes to — it relies on
same-host cross-repository blob mounting and has no cross-registry equivalent. So
each `build-image` job pushes its digest to *every* eligible registry, and this
job merges once per registry against digests that are identical everywhere
(they are content-addressed).

**One digest is signed against all registries.** An index is content-addressed,
so the merge must produce the same digest in every registry. The job asserts that
before signing, rather than discovering a per-registry digest inside the signing
code.

**The platform set must match exactly.** A platform in `platforms` with no digest
in the workspace fails the job, rather than publishing an index that is quietly
missing an architecture — that index would be perfectly valid, and consumers on
the missing architecture would fail at pull time, long after the release looked
green. A digest with no matching entry in `platforms` fails it too: that
architecture was built and pushed but would be left out.

**Signing is the same code as before.** `image-sign-and-attest` works purely from
`/tmp/.index_digest` and `/tmp/.eligible_registries`, so it neither knows nor
cares that the index was assembled rather than pushed directly.

## Building on Arm

`resource_class` accepts CircleCI's Arm classes (`arm.medium`, `arm.large`,
`arm.xlarge`, `arm.2xlarge`) as well as the x86 ones, but this job does no
building — it assembles manifests, signs and fetches SBOM blobs — so the default
`small` is almost always right.

The Arm classes that matter are the ones on the build jobs, where the class
must match the platform or the job fails. See
[build-image → Why one job per architecture](build-image.md#why-one-job-per-architecture).

## Selecting target registries

`registries-data` is space-separated, one registry per line:

```yaml
registries-data: |-
  private gsociprivate.azurecr.io ACR_GSOCIPRIVATE_USERNAME ACR_GSOCIPRIVATE_PASSWORD false
  public gsoci.azurecr.io ACR_GSOCI_USERNAME ACR_GSOCI_PASSWORD false
```

Fields:

1. Visibility — `public`, `private`, or `public/private`
2. Registry URL
3. Username env var name
4. Password env var name
5. Push dev images — `true` pushes branch builds, `false` skips them (release builds only)

Branch builds are "dev"; tag builds are "release". By default dev images go to `gsoci` only, not to Aliyun.

The `build-image` jobs resolve this same set with the same command, to decide where to push their digests. The visibility check and the `push_dev` gate are deterministic for a given commit and tag, so both resolutions agree.

## Private vs public images

The job calls the GitHub API to detect whether the source repository is private. Private source → push only to registries with `private` visibility. Public source → push to `public` or `public/private` registries.

`force-public: true` skips the check and treats the image as public regardless. Set it identically on the `build-image` jobs.

## OCI index annotations

Emitted by default and configurable via `oci-labels: true|false`:

- `org.opencontainers.image.source` — `https://github.com/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}`
- `org.opencontainers.image.revision` — `${CIRCLE_SHA1}`
- `org.opencontainers.image.version` — the tag from `gitsemver get`
- `org.opencontainers.image.created` — commit timestamp (RFC 3339, deterministic per commit)

They have to be re-applied here, because the merge builds a new index and each
`build-image` job's own index is discarded with it. The matching image *labels*
are set per architecture by [`build-image`](build-image.md#oci-image-labels) and
survive the merge untouched.

## Cosign signing

`sign: true` (default) signs the merged index with cosign keyless
OIDC. On public images it **also signs the SBOM attestations** (SPDX, and
CycloneDX when `sbom-cyclonedx: true`) so consumers can cryptographically
verify their origin. Public images only — private images are skipped at
runtime.

See [Cosign signing](../cosign-signing.md) for the verification commands
(including `cosign verify-attestation` for SBOMs), the identity model
(CircleCI's UUID-based SAN URI + the friendly source-repo OID), and
verify-after-sign behavior.

## SBOMs (SPDX + CycloneDX) and signing

`build-image` attaches an **SPDX** SBOM per platform inline in that
platform's index, and `imagetools create` carries it into the merged one. On
**public** images with `sign: true`, this job extracts the exact SPDX predicate
buildx produced and signs it as a cosign keyless attestation (`--type spdxjson`)
— verifiable independently of the registry. `sbom: false` skips that signing.

BuildKit's SBOM attestation only emits SPDX. For a **CycloneDX** SBOM too,
set `sbom-cyclonedx: true`:

```yaml
      - architect/push-to-registries:
          image: giantswarm/myapp
          sbom-cyclonedx: true
```

When enabled, the job generates a CycloneDX SBOM **per architecture** with
[syft](https://github.com/anchore/syft). Where it lands depends on visibility:

- **Public images with `sign: true`** — signed as a cosign keyless
  attestation (`--type cyclonedx`), a verifiable OCI referrer. This is the
  trustable, tamper-evident proof of image contents.
- **Private images, or `sign: false`** — attached **unsigned** as an OCI 1.1
  referrer (artifactType `application/vnd.cyclonedx+json`) using
  [oras](https://oras.land), since signing private artifacts would leak their
  digests/timestamps into the public Rekor transparency log.

Both require `syft` and `oras` in the architect image. `sbom-cyclonedx`
defaults to off, so existing consumers are unaffected.

### Verifying / inspecting SBOMs as a consumer

Signed attestations are verified **per platform** with cosign — see
[Cosign signing → SBOM attestations](../cosign-signing.md#sbom-attestations-spdx--cyclonedx).

Unsigned CycloneDX referrers (private images) are listed/pulled via the
referrers API:

```sh
# Resolve a platform digest, then list its referrers
oras discover --artifact-type application/vnd.cyclonedx+json \
  <registry>/giantswarm/myapp@<platform-digest>

# Pull the SBOM blob
oras pull <registry>/giantswarm/myapp@<sbom-referrer-digest>
```

## Things that bite

**`split-china-push` must match** the value on the `build-image` jobs, or they
disagree about which registries hold the per-architecture digests.

**`platforms` must match the set of `build-image` jobs.** Both directions are a
hard failure; see [How the merge works](#how-the-merge-works).

**This job writes `.build_version`.** It is the only job on the release path that
is not concurrent with another, so it is the one that publishes the version to the
workspace for `package-helm-with-abs`. A branch path with no `push-to-registries`
job needs `persist-build-version: true` on exactly one `build-image` job instead.

**Untagged manifests accumulate.** Push-by-digest leaves them behind when a
pipeline fails between the build and the merge. Enable untagged-manifest
retention on the target registries — the same setting the
[build cache](build-image.md#prerequisite-untagged-manifest-retention) needs.

## Migrating

- From v9: [docs/migration-v9-to-v10.md](../migration-v9-to-v10.md)
- From v8.x: [docs/migration-v8-to-v9.md](../migration-v8-to-v9.md)
