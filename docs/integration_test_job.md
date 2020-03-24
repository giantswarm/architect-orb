# integration-test job
 
- Runs an integration test by creating a [KIND] cluster and executing it as a Go test.
- Runs in a Circle VM because KIND uses Docker in Docker and this doesn't work
with the Circle Docker executor.
- Uses the [machine executor] and replaces the Go version with a version
  controlled by us. Since the preinstalled Go is very outdated.

## Example usage

The only required parameter is the `test-dir` containing the integration test.

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@version

workflows:
  my-workflow:
    jobs:
      - architect/integration-test:
        name: basic-integration-test
        test-dir: "integration/test/basic"
```

## Parameters

These optional parameters allow configuring the test.

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

[KIND]: https://kind.sigs.k8s.io
[KIND docs]: https://kind.sigs.k8s.io/docs/user/configuration/
[machine executor]: https://circleci.com/docs/2.0/executor-types/#using-machine
[retagger]: https://github.com/giantswarm/retagger
