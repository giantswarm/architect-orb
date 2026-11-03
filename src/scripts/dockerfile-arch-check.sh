#!/bin/bash
# dockerfile-arch-check: fail when the Dockerfile copies a binary from the
# build context into an image built for another architecture.
#
# go-build writes `<binary>-linux-<arch>` for each architecture, and a plain
# `<binary>` that is the linux/amd64 copy. A Dockerfile copying the plain
# `<binary>` ships the amd64 binary in every platform's image, so the arm64
# image cannot run. The fix is `COPY <binary>-linux-${TARGETARCH}`.
#
# Each source is checked once per platform, with TARGETARCH, TARGETOS and
# TARGETPLATFORM substituted as buildx sets them. Stages whose FROM has
# --platform= are skipped: they run on that platform, not the target's.
# Only literal file paths are checked; directories, wildcards and other build
# arguments are not.
#
# Parameters, as environment variables:
#   PARAM_DOCKERFILE     path to the Dockerfile
#   PARAM_BUILD_CONTEXT  build context directory
#   PARAM_PLATFORMS      comma-separated platforms; empty reads `.platforms`,
#                        then defaults to linux/amd64,linux/arm64 like the build
#   PARAM_MODE           "fail" (default) fails the step on a mismatch;
#                        "warn" prints it and passes
set -euo pipefail

platforms="${PARAM_PLATFORMS:-}"
if [[ -z "$platforms" && -f .platforms ]]; then
  platforms=$(paste -sd, .platforms | tr -d '[:space:]')
fi
platforms="${platforms:-linux/amd64,linux/arm64}"

# Prints the architecture of an ELF binary, in GOARCH naming, as scanelf
# (pax-utils, in the architect image) reports it. Prints nothing for other files.
elf_arch() {
  [[ -f "$1" ]] || return 0
  case "$(scanelf -BF '%a' "$1" 2>/dev/null | cut -d' ' -f1)" in
    EM_X86_64) echo amd64 ;;
    EM_AARCH64) echo arm64 ;;
    EM_ARM) echo arm ;;
    EM_386) echo 386 ;;
    EM_RISCV) echo riscv64 ;;
    EM_PPC64) echo ppc64le ;;
    EM_S390) echo s390x ;;
  esac
}

# Drop comment lines, join continuation lines, then keep FROM, and COPY and ADD
# instructions that read from the build context (no --from).
instructions=$(grep -v '^[[:space:]]*#' "${PARAM_DOCKERFILE}" |
  sed -e ':a' -e '/\\$/{N;s/\\\n/ /;ba' -e '}' |
  grep -iE '^[[:space:]]*(FROM|COPY|ADD)[[:space:]]' | grep -viE '^[[:space:]]*(COPY|ADD)[[:space:]].*--from=' || true)

failed=0
# Check every instruction once per platform, e.g. linux/arm/v7: os=linux, arch=arm.
for platform in ${platforms//,/ }; do
  os="${platform%%/*}"
  arch="${platform#*/}"
  arch="${arch%%/*}"
  # words: the instruction split on whitespace, e.g. (COPY --chown=1000 app /app).
  skip_stage=0
  while read -r -a words; do
    (( ${#words[@]} )) || continue
    # A FROM starts a stage: skip it when pinned with --platform=.
    if [[ "${words[0],,}" == from ]]; then
      skip_stage=0
      [[ " ${words[*],,} " == *" --platform="* ]] && skip_stage=1
      continue
    fi
    (( skip_stage )) && continue
    # paths: the sources then the destination, e.g. (app /app). Skip the COPY or
    # ADD keyword (words[0]) and flags, strip the JSON form's [ ] " and , and
    # substitute the platform's build arguments.
    paths=()
    for w in "${words[@]:1}"; do
      w="${w//[\[\]\",]/}"
      [[ -z "$w" || "$w" == --* ]] && continue
      w="${w//\$\{TARGETPLATFORM\}/$platform}"
      w="${w//\$TARGETPLATFORM/$platform}"
      w="${w//\$\{TARGETARCH\}/$arch}"
      w="${w//\$TARGETARCH/$arch}"
      w="${w//\$\{TARGETOS\}/$os}"
      w="${w//\$TARGETOS/$os}"
      paths+=("$w")
    done
    # Check the sources: every path but the last.
    (( ${#paths[@]} > 1 )) || continue
    for src in "${paths[@]:0:${#paths[@]}-1}"; do
      found=$(elf_arch "${PARAM_BUILD_CONTEXT}/${src}")
      if [[ -n "$found" && "$found" != "$arch" ]]; then
        echo "ERROR: ${PARAM_DOCKERFILE} copies '${src}' into the ${platform} image, but it is built for ${found}."
        failed=1
      fi
    done
  done <<< "$instructions"
done

if (( failed )); then
  echo "Copy the binary built for the target architecture instead:"
  echo "  ARG TARGETARCH"
  echo "  COPY <binary>-linux-\${TARGETARCH} /<binary>"
  if [[ "${PARAM_MODE:-fail}" == warn ]]; then
    echo "mode=warn: continuing build."
    exit 0
  fi
  exit 1
fi
echo "Every binary copied matches its image's architecture (${platforms})."
