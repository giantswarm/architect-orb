#!/usr/bin/env bats
# Tests of src/scripts/go-build-procs.sh: the concurrency and the -p a go-build
# resolves from build_concurrency, the executor's cgroup CPU quota and nproc.
# A cgroup mount is a directory of this test's own (CGROUP_ROOT); nproc is a
# stub on the PATH that reports the host's CPUs, as a Docker executor's does.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/go-build-procs.sh"
  export BASH_ENV="${BATS_TEST_TMPDIR}/bash_env"
  : > "${BASH_ENV}"
  export CGROUP_ROOT="${BATS_TEST_TMPDIR}/cgroup"
  mkdir -p "${CGROUP_ROOT}"
  export PARAM_BUILD_CONCURRENCY="1"

  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  printf '#!/bin/sh\necho 36\n' > "${BATS_TEST_TMPDIR}/bin/nproc"
  chmod +x "${BATS_TEST_TMPDIR}/bin/nproc"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

cgroup_v2() {
  echo "$1" > "${CGROUP_ROOT}/cpu.max"
}

cgroup_v1() {
  mkdir -p "${CGROUP_ROOT}/cpu"
  echo "$1" > "${CGROUP_ROOT}/cpu/cpu.cfs_quota_us"
  echo "$2" > "${CGROUP_ROOT}/cpu/cpu.cfs_period_us"
}

exported() {
  # The variable a later step sees after sourcing BASH_ENV.
  (. "${BASH_ENV}" && printf '%s' "${!1:-}")
}

@test "a medium Docker executor (cgroup v2) compiles with -p 2, not the host's 36" {
  cgroup_v2 "200000 100000"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "Compiling 1 architecture(s) at a time, -p 2 each (2 CPU(s), from the cgroup CPU quota)." ]
  [ "$(exported GO_BUILD_CONCURRENCY)" = "1" ]
  [ "$(exported GO_BUILD_PROCS)" = "2" ]
}

@test "a cgroup v1 quota is read from cpu.cfs_quota_us and cpu.cfs_period_us" {
  cgroup_v1 400000 100000
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_PROCS)" = "4" ]
}

@test "a fractional quota rounds up to whole CPUs" {
  cgroup_v2 "150000 100000"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_PROCS)" = "2" ]
}

@test "without a cgroup v2 quota the budget is nproc" {
  cgroup_v2 "max 100000"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"-p 36 each (36 CPU(s), from nproc, no lower cgroup CPU quota)."* ]]
  [ "$(exported GO_BUILD_PROCS)" = "36" ]
}

@test "without a cgroup v1 quota the budget is nproc" {
  cgroup_v1 -1 100000
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_PROCS)" = "36" ]
}

@test "without a cgroup CPU controller the budget is nproc" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_PROCS)" = "36" ]
}

@test "a quota above nproc is capped at nproc" {
  cgroup_v2 "6400000 100000"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_PROCS)" = "36" ]
}

@test "a concurrent wave shares the quota" {
  cgroup_v2 "800000 100000"
  export PARAM_BUILD_CONCURRENCY="4"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "Compiling 4 architecture(s) at a time, -p 2 each (8 CPU(s), from the cgroup CPU quota)." ]
  [ "$(exported GO_BUILD_CONCURRENCY)" = "4" ]
  [ "$(exported GO_BUILD_PROCS)" = "2" ]
}

@test "a wave wider than the quota still gets -p 1 per build" {
  cgroup_v2 "200000 100000"
  export PARAM_BUILD_CONCURRENCY="3"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_CONCURRENCY)" = "3" ]
  [ "$(exported GO_BUILD_PROCS)" = "1" ]
}

@test "auto concurrency is the quota's CPUs, not nproc" {
  cgroup_v2 "400000 100000"
  export PARAM_BUILD_CONCURRENCY="auto"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_CONCURRENCY)" = "4" ]
  [ "$(exported GO_BUILD_PROCS)" = "1" ]
}

@test "a build_concurrency with a leading zero is decimal" {
  cgroup_v2 "800000 100000"
  export PARAM_BUILD_CONCURRENCY="08"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(exported GO_BUILD_CONCURRENCY)" = "8" ]
}

@test "a build_concurrency of 0 fails before anything is exported" {
  export PARAM_BUILD_CONCURRENCY="0"
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"'build_concurrency' must be a positive integer or \"auto\" (got: 0)"* ]]
  [ -z "$(exported GO_BUILD_PROCS)" ]
}

@test "a build_concurrency that is not a number fails" {
  export PARAM_BUILD_CONCURRENCY="many"
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"(got: many)"* ]]
}
