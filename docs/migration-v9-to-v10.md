# Migrating from architect-orb v9 to v10

v10 removes two parameters from `push-to-app-catalog` that the orb has ignored for at least a major
version. There are no behaviour changes — if your config does not pass either parameter, upgrading to v10
is a no-op.

## What to check

Search your `.circleci/config.yml` for these two keys:

```
ct_config
skip_conftest_deprek8ion
```

If neither appears, you are done — merge the version bump.

If either appears, **delete the line**. CircleCI fails config compilation on unknown job arguments, so
leaving it in place will break the `push-to-app-catalog` job on v10.

## Why they went

### `skip_conftest_deprek8ion` — ignored since v6.3.2

This controlled the `helm-conftest` step, which ran the third-party
[deprek8ion](https://github.com/swade1987/deprek8ion) rego policies to flag Kubernetes API deprecations.
The step was removed in v6.3.2 after a conftest upgrade made it incompatible with those policies.

It was not restored: the policy set has been unmaintained since 2021 and only covered deprecations up to
Kubernetes 1.22, while app-build-suite already runs kube-linter over the same manifests in the helm build
pipeline. The `conftest` binary has also been dropped from the architect, app-build-suite, and
app-test-suite images.

See [roadmap#4066](https://github.com/giantswarm/roadmap/issues/4066).

### `ct_config` — ignored since v9.0.0

This pointed at a chart-testing config file for the `helm-lint` step. That step was removed in v9.0.0
along with the whole `architect`-executor path, when packaging moved to app-build-suite.

**Your `ct-config.yaml` file does not need to change.** app-build-suite still reads chart-testing config,
via the `ct-config` key in `.abs/main.yaml` — most repos already configure it there, and that path is
unaffected. Only the orb parameter is gone.

## What is *not* changing

The `executor` parameter stays. It accepts only `app-build-suite` (also the default), so passing it is
already a no-op, but around 275 repos set it explicitly. It is now permanently retained rather than
deprecated — you can leave it in place indefinitely.
