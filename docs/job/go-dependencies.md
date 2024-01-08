# go-dependencies

Check the Go project's dependencies for known security vulnerabilities, using [nancy](https://github.com/sonatype-nexus-community/nancy).

Depending on your project's needs, you may or may not make this job a required check. There are no configuration parameters.

Example configuration snippet:

```yaml
    jobs:
      - architect/go-dependencies:
          name: go-dependencies
```
