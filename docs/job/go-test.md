# go-test

This job:

- Checks if Go modules are tidy.
- Checks if imports in .go files satisfy import rules defined in fmt.
- Checks if filenames contain non-ASCII characters.
- Runs `go vet` against the codebase.
- Runs `go test` against the codebase.
- Runs `golangci-lint` against the codebase with multiple linters enabled.
- Runs `nancy` against the codebase to check for known vulnerabilities in code dependencies.

Example usage:

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/go-test:
          name: go-test-REPOSITORY
          # Needed to trigger job also on git tag.
          filters:
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```
