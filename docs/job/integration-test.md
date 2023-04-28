# integration-test job

- Runs an integration test by creating a [KIND] cluster and executing it as a Go test.
- Runs in a Circle VM because KIND uses Docker in Docker and this doesn't work
with the Circle Docker executor.
- Uses the [machine executor] and replaces the Go version with a version
  controlled by us. Since the preinstalled Go is very outdated.

## Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@version

workflows:
  my-workflow:
    jobs:
      - architect/integration-test:
        name: basic-integration-test
        install-app-platform: true
        test-dir: "integration/test/basic"
```

## Parameters

- [common parameters](common.md#parameters) shared in all jobs.
- [test-dir](#attach_workspace) (required string)
- [apptestctl-version](#apptestctl-version) (optional string, default="v0.15.0")
- [env-file](#env-file) (optional string, default="")
- [helm-version](#helm-version) (optional string, default="v3.6.3")
- [install-app-platform](#install-app-platform) (optional boolean, default=false)
- [kind-config](#kind-config) (optional string, default="")
- [kubernetes-version](#kubernetes-version) (optional string, default="v1.21.1")
- [setup-script](#setup-script) (optional string, default="")
- [test-dir](#test-dir) (required string)
- [test-timeout](#test-timeout) (optional string, default="20m")

### apptestctl-version

- Version of [apptestctl] to use if `install-app-platform` is true.

### env-file

- Path to a `.env` file containing env vars.
- These are passed to the integration test when it is executed.

```yaml
    jobs:
      - architect/integration-test:
        name: basic-integration-test
        env-file: "integration/config/.env"
        test-dir: "integration/test/basic"
```

e.g.

```yaml
FOO=bar
BAR=foo
```

### install-app-platform

- If true then [apptestctl] is installed and `apptestctl bootstrap` is run.
- This enables using app CRs to install components in tests. For Go tests the
[apptest] library can be used to create the app CRs.

### kind-config

- Path to a KIND config file.
- See [KIND docs] for more details.

```yaml
    jobs:
      - architect/integration-test:
        name: basic-integration-test
        kind-config: "integration/config/kind-config"
        test-dir: "integration/test/basic"
```

e.g. Create a 3 node cluster.

```yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
- role: control-plane
- role: worker
- role: worker
```

### kubernetes-version

- The default kubernetes version we test with is set in the integration-test
job.
- This can be overriden if you need to test with another version.
- The KIND node image must have been retagged with [retagger].
- It's recommended to not change this version and have it updated together with
the next orb release.

```yaml
    jobs:
      - architect/integration-test:
        name: basic-integration-test
        kubernetes-version: "v1.18.0-beta.1"
        test-dir: "integration/test/basic"
```

### setup-script

- A script that is run before the test is executed.
- This is useful for example if the KIND cluster needs to be configured.

```yaml
    jobs:
      - architect/integration-test:
        name: basic-integration-test
        setup-script: "integration/config/setup.sh"
        test-dir: "integration/test/basic"
```

```bash
#!/usr/bin/env bash

# Delete coredns resources
kubectl delete deployment coredns -n kube-system
```

### test-dir

The directory containing the integration test.

### test-timeout

If a test runs longer than this value it will panic.
If it's 0, the timeout is disabled.
The default is "20m" (20 minutes).

```yaml
    jobs:
      - architect/integration-test:
        name: basic-integration-test
        test-timeout: "35m"
        test-dir: "integration/test/basic"
```

[apptest]: https://github.com/giantswarm/apptest
[apptestctl]: https://github.com/giantswarm/apptestctl
[KIND]: https://kind.sigs.k8s.io
[KIND docs]: https://kind.sigs.k8s.io/docs/user/configuration/
[machine executor]: https://circleci.com/docs/2.0/executor-types/#using-machine
[retagger]: https://github.com/giantswarm/retagger
