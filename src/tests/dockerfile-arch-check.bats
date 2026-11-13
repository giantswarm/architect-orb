#!/usr/bin/env bats
# Tests of src/scripts/dockerfile-arch-check.sh: a Dockerfile copying a binary
# from the build context fails the step when the binary's architecture differs
# from a platform the image is built for, and passes otherwise.
# The fixtures are bare 64-byte ELF headers; scanelf reads e_machine from them.

# Prints an ELF64 header with the given e_machine bytes.
elf() {
  printf '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00'"$1"'\x01\x00\x00\x00'
  head -c 24 /dev/zero
  printf '\x00\x00\x00\x00\x40\x00\x38\x00\x00\x00\x40\x00\x00\x00\x00\x00'
}

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/dockerfile-arch-check.sh"
  cd "${BATS_TEST_TMPDIR}"
  export PARAM_DOCKERFILE=Dockerfile
  export PARAM_BUILD_CONTEXT=.
  export PARAM_PLATFORMS=""
  elf '\x3e\x00' > app
  cp app app-linux-amd64
  elf '\xb7\x00' > app-linux-arm64
  echo 'key: value' > config.yaml
}

@test "the plain amd64 binary in a multi-platform image fails" {
  printf 'FROM scratch\nCOPY config.yaml /etc/\nADD app /app\n' > Dockerfile
  run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"copies 'app' into the linux/arm64 image, but it is built for amd64."* ]]
  [[ "$output" != *"linux/amd64 image"* ]]
}

@test "the binary for the target architecture passes" {
  printf 'FROM scratch\nARG TARGETARCH\nCOPY app-${TARGETOS}-${TARGETARCH} /app\n' > Dockerfile
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
}

@test "a wrong binary behind TARGETARCH fails" {
  cp app app-linux-arm64
  printf 'FROM scratch\nARG TARGETARCH\nCOPY app-linux-$TARGETARCH /app\n' > Dockerfile
  run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"copies 'app-linux-arm64' into the linux/arm64 image, but it is built for amd64."* ]]
}

@test "an arm64 binary in an amd64 image fails" {
  printf 'FROM scratch\nCOPY app-linux-arm64 /app\n' > Dockerfile
  PARAM_PLATFORMS=linux/amd64 run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"copies 'app-linux-arm64' into the linux/amd64 image, but it is built for arm64."* ]]
}

@test "the plain amd64 binary in an amd64-only image passes" {
  printf 'FROM scratch\nCOPY app /app\n' > Dockerfile
  PARAM_PLATFORMS=linux/amd64 run "${SCRIPT}"
  [ "$status" -eq 0 ]
}

@test "the platforms come from .platforms when the parameter is empty" {
  printf 'FROM scratch\nCOPY app /app\n' > Dockerfile
  echo linux/amd64 > .platforms
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
}

@test "flags, JSON form and continuation lines are parsed" {
  printf 'FROM scratch\nCOPY --chown=1000:1000 \\\n  config.yaml \\\n  app /\nCOPY ["app", "/app"]\n' > Dockerfile
  run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ "$(grep -c "copies 'app' into" <<< "$output")" -eq 2 ]
}

@test "a copy from another stage is ignored" {
  printf 'FROM scratch\nCOPY --from=builder app /app\n' > Dockerfile
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
}

@test "a Dockerfile without COPY or ADD passes" {
  printf 'FROM scratch\n' > Dockerfile
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
}
