---
description: Verify and update default values and version numbers in docs/ to match the source YAML files in src/
---

When initiated by the user, follow the procedure in this skill.

The goal is to ensure that the documentation in `docs/` accurately reflects the actual parameter defaults, version numbers, and descriptions defined in the source YAML files under `src/jobs/` and `src/commands/`.

## Procedure

1. **Read all job source files** in `src/jobs/*.yaml` and extract every parameter with its `default:` value.

2. **Read all doc files** in `docs/job/*.md` and find every place where a default value is mentioned (look for patterns like `default=`, `default:`, `Default:`, `Defaults to`).

3. **Compare** each documented default against the actual source default. Flag any mismatches. The source YAML is authoritative — never change source defaults to match docs.

4. **Fix mismatches** by updating the docs to match the source.

5. **Check for typos and broken links** in the docs while you're at it (misspelled words, broken markdown links, garbled sentences).

6. **Verify the index**: check that `docs/README.md` lists all jobs that have doc files in `docs/job/`.

## Tips

- Match doc files to source files by job name. Each doc in `docs/job/` documents a job defined in `src/jobs/`. The filenames usually correspond, but not always — match by content, not filename.
- Version defaults (for tools, Kubernetes, Helm, test suites, etc.) drift frequently as the source is updated but docs are forgotten. Pay extra attention to these.
- Some parameters have defaults documented in multiple places within the same doc file (e.g. a parameter list at the top and a detailed section below) — make sure all occurrences are consistent.
