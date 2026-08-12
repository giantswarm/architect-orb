# build-image-arch / merge-image-manifests

Builds a multi-arch image with **no QEMU emulation**, by giving each architecture
its own native machine and joining the results afterwards.

These two jobs are one mechanism and are documented together: `build-image-arch`
is only useful with `merge-image-manifests` downstream, and the merge is only
useful with legs upstream.

`push-to-registries` is unchanged and remains the single-job path. Use that unless
emulation is actually costing you — see [When this is worth
it](#when-this-is-worth-it).

## The problem these solve

`push-to-registries` runs one `docker buildx build --platform linux/amd64,linux/arm64`
on one machine. A machine is native for one architecture at a time, so the other
architecture's `RUN` steps execute under QEMU. For an image whose build is mostly
`apt-get install`, that leg runs 7-15× slower than native and is the entire
critical path — the native leg finishes in minutes and then idles.

Dockerfile-level fixes exist and are cheaper when they apply; see [Multi-arch
Dockerfiles](../multi-arch-dockerfiles.md). They do not apply to an image whose
payload *is* the package installation.

## Shape

```yaml
- architect/build-image-arch:
    name: build-amd64
    platform: linux/amd64
    resource_class: medium
    context: architect

- architect/build-image-arch:
    name: build-arm64
    platform: linux/arm64
    resource_class: arm.medium
    context: architect

- architect/merge-image-manifests:
    name: push-to-registries-release
    platforms: "linux/amd64,linux/arm64"
    context: architect
    requires:
      - build-amd64
      - build-arm64
```

The two legs run concurrently, each on a machine of its own architecture, so wall
clock is the slower single leg rather than the sum. Set `resource_class` to a
class whose architecture matches `platform` — that is the whole point. A mismatch
still builds, but under QEMU, and the leg warns loudly rather than looking like a
working native build.

Naming the merge job `push-to-registries-release` keeps any existing `requires:`
edges pointing at it (`sync-china-registry`, chart tests) working unchanged.

## Branch validation

With `push: false` a leg builds and discards, exactly as `push-to-registries` does
today. There is no digest and no merge job:

```yaml
- architect/build-image-arch:
    name: build-image-amd64
    platform: linux/amd64
    resource_class: medium
    push: false
```

## How it works

**The legs push by digest.** Each leg runs
`--output type=image,"name=<reg1>/<img>,<reg2>/<img>",push-by-digest=true,...`,
which pushes the manifest without creating a tag, and records the resulting digest
in `.image-digests/<platform>` in the workspace. A single-architecture manifest is
not independently useful, so tagging one would only publish something consumers
could pull by accident.

**Attestations are produced per leg, not at the merge.** BuildKit can only attest
what it built. With `--attest` enabled, each leg's push is itself an index — the
image manifest plus its attestation manifest — and `docker buildx imagetools
create` copies whole child indexes, so those attestation manifests and the
`vnd.docker.reference.*` annotations linking them to their platform manifests
survive into the merged index. `docker manifest create` strips them, which is why
it is not used.

**The merge runs once per registry.** `imagetools create` builds a manifest by
reference and requires its sources to exist in the registry it writes to — it
relies on same-host cross-repository blob mounting and has no cross-registry
equivalent. So each leg pushes its digest to *every* eligible registry, and the
merge runs per registry against digests that are identical everywhere (they are
content-addressed).

**Signing is the same code as the single-job path.** `image-sign-and-attest` works
purely from `/tmp/.index_digest` and `/tmp/.eligible_registries`, so it neither
knows nor cares that the index was assembled rather than pushed directly.

## Things that bite

**Index annotations do not survive the merge.** Per-leg `index:`-scoped annotations
annotate that leg's own index, which is discarded. Put index annotations on
`merge-image-manifests` and per-platform ones (`manifest:`) on the legs. Image
*labels* (`oci-labels`) are image-config level and survive untouched.

**`split-china-push` must match** on the legs and the merge, or they disagree
about which registries hold the per-architecture digests.

**Layer cache refs are per architecture.** `cache: registry` appends the platform
to the cache ref, derived or explicit. Two legs exporting to one ref run
concurrently and would race, leaving whichever finished last as the only surviving
cache manifest.

**A missing leg is a hard failure, deliberately.** If a platform in `platforms`
has no digest in the workspace, the merge refuses rather than publishing an index
that is quietly missing an architecture. That is the failure mode worth being
loud about: the index would be perfectly valid and consumers on the missing
architecture would fail at pull time, long after the release looked green.

**Untagged manifests accumulate.** Push-by-digest leaves untagged manifests when a
pipeline fails between the legs and the merge. Enable untagged-manifest retention
on the target registries.

## When this is worth it

Worth it when the arm64 leg's `RUN` steps are the critical path — package
installs, native compilation, anything syscall-heavy under emulation.

Not worth it when:

- the Dockerfile already avoids emulation (prebuilt binary + `COPY`, or a
  `$BUILDPLATFORM` cross-compile), in which case the emulated leg costs seconds
  and the split only adds job spin-up
- the image is single-architecture, where `push-to-registries` with a matching
  `resource_class` is all you need
