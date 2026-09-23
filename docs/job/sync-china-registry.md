# sync-china-registry

Mirrors the image a `push-to-registries` job just published from `gsoci.azurecr.io`
to the Aliyun registry (`giantswarm-registry.cn-shanghai.cr.aliyuncs.com`), from a
CircleCI runner inside China.

It is the second half of `split-china-push`: the `push-to-registries` job with
`split-china-push: true` leaves Aliyun out of its push set and stashes the registry
and tag it pushed in a pipeline-scoped cache; this job restores that cache and copies
the image with `regctl image copy`. The bytes travel registry replica → runner →
Aliyun within the region, instead of crossing the Pacific from a buildx push, which
is what used to hang tag pipelines for 10–20 minutes and time out.

```
push-to-registries (split-china-push: true) ──▶ gsoci.azurecr.io
        │  cache: registry + tag
        ▼
sync-china-registry (giantswarm/galaxy-runner, in China)
        │  wait until the image is visible from here
        ▼
regctl image copy  gsoci ──▶ Aliyun
```

Nothing else in a pipeline needs to depend on this job. Keep the chart publish and
any downstream `requires:` on `push-to-registries`, so a slow or failed mirror never
blocks a release.

## Example usage

```yaml
- architect/push-to-registries:
    context: architect
    name: push-to-registries-release
    split-china-push: true
    filters: &release-filters
      tags:
        only: /^v.*/
      branches:
        ignore: /.*/

- architect/sync-china-registry:
    context: architect
    name: sync-china-registry
    requires: [push-to-registries-release]
    filters: *release-filters
```

`image` defaults to `giantswarm/${CIRCLE_PROJECT_REPONAME}`; set it to the same
value as on the push job when the published image name differs from the repo name.

## What the job does

1. `image-login-to-registries` (regctl client) logs in to every registry in the
   registries data — the source and the Aliyun target.
2. `restore_cache` brings back `/tmp/.docker_image_registry` and
   `/tmp/.docker_image_tag` from the push job.
3. `image-wait-for-replica` polls until the image is visible **from this runner**,
   child manifests included (see below).
4. `image-copy-to-china` runs `regctl image copy`, up to ten attempts five seconds
   apart, for transient errors on the Aliyun side.

## Why the job waits before copying

`gsoci.azurecr.io` is a geo-replicated Azure Container Registry behind Traffic
Manager. A client is routed to the nearest replica: CircleCI's hosted runners and
the push job write to the home region, a runner in China reads the **Southeast Asia**
replica. Replication to that replica is asynchronous and per manifest, and the
manifest of a platform image only appears once all of its layers are across.

Right after a push the replica therefore already serves the tiny index and the
attestation manifests while the platform manifest — the one with the layers — is
still in flight. A copy started then fails with `MANIFEST_UNKNOWN` for a digest the
home region has been serving for minutes:

```
copy failed, error getting source: failed to get manifest
  gsoci.azurecr.io/giantswarm/vllm@sha256:fb21…: request failed: not found [http 404]
```

How long the gap lasts scales with the image. A Go service image (tens of MB) is
usually across within a minute or two, so a short retry mostly hid the race and a
rerun caught the rest. The 20 GiB arm64 `vllm` image never made it inside the
previous 10 × 5 s retry window — every tag from v0.4.7 to v0.4.17 failed at this
point, with the copy succeeding on a rerun hours later once the replica had caught up.

`image-wait-for-replica` therefore resolves the source tag to its index and fetches
every child manifest (recursively, so a nested index is covered too) from the runner,
polling every 30 s until all of them answer. It waits on the children, not on the
tag: the tag is the first thing to arrive. The copy only starts once the whole tree
is visible.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `image` | `giantswarm/${CIRCLE_PROJECT_REPONAME}` | Repository and image name without the registry host. Must match the push job's `image`. |
| `registries-data` | `""` | Inline registries table; empty uses `REGISTRIES_DATA_BASE64` from the context. Same format as on `push-to-registries`. |
| `replica-wait-minutes` | `60` | Upper bound for the wait in step 3. On timeout the job fails with a message saying so. Nothing downstream depends on the job, so a generous bound only costs runner time while an image is still replicating. Raise it for repos whose image is repeatedly reported as not yet visible after an hour. |

## When it fails

- **`Gave up after N minutes: … has not fully replicated`** — the image was still
  replicating when the bound ran out. Rerun the workflow *from failed*
  (`POST /api/v2/workflow/<id>/rerun {"from_failed": true}`, or the UI); the copy
  picks up once the replica has the image. If this repeats for one repo, raise
  `replica-wait-minutes` on its job.
- **`Failed to sync the image`** after ten copy attempts — the Aliyun side refused
  or timed out repeatedly. The step prints regctl's error for each attempt.
- **`Login to registries` fails** — credentials for a registry in the registries
  data are missing from the `architect` context on the runner.

## Dev builds

The job mirrors whatever the push job published, without a dev/release gate of its
own. The `push_dev: false` entry for Aliyun in the registries data only governs the
buildx push; on the generated pipelines this job runs on tags only, so nothing dev
reaches Aliyun through it. A hand-written workflow that runs it on branches mirrors
dev images too.
