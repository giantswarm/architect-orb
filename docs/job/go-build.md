# go-build

This job:

- Does everything [go-test](go-test.md) job does.
- Builds a go binary.
- Runs `BINARY version` and checks if it returned 0 exit code.
- Persists the binary to the workspace.

Example usage:

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/go-build:
          name: go-build-REPOSITORY
          binary: REPOSITORY
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```
