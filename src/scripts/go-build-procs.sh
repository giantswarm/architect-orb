#!/bin/bash
# go-build: resolve how many architectures compile at once and the -p of each.
#
# Inputs, set by the command from its parameters:
#   PARAM_BUILD_CONCURRENCY  "auto" or a positive integer
# CircleCI's own:
#   BASH_ENV                 the file every later step sources
# For the tests:
#   CGROUP_ROOT              the cgroup mount, /sys/fs/cgroup by default
#
# Exports GO_BUILD_CONCURRENCY and GO_BUILD_PROCS through BASH_ENV.
#
# The CPU budget is the executor's cgroup CPU quota, rounded up to whole CPUs.
# In a CircleCI Docker executor nproc counts the host's CPUs, not the resource
# class's: 36 on a `medium` executor of 2 vCPUs, and 36 compile processes kill
# the container part way through the build. nproc is the budget only when no
# quota is lower, on a machine executor whose CPUs are its own.
#
# Each build of a wave gets an equal share of the budget, at least 1: `go build`
# defaults -p to GOMAXPROCS, so a wave of N builds would otherwise start N times
# that many compile processes, and the memory that costs exceeds the executor
# whenever the build cache does not answer.
set -euo pipefail

cgroup_root="${CGROUP_ROOT:-/sys/fs/cgroup}"

# The quota in whole CPUs, rounded up; nothing when there is none.
cgroup_cpus() {
  local quota period
  if [[ -r "${cgroup_root}/cpu.max" ]]; then
    # cgroup v2: "<quota> <period>", "max <period>" without a quota.
    read -r quota period < "${cgroup_root}/cpu.max"
  elif [[ -r "${cgroup_root}/cpu/cpu.cfs_quota_us" && -r "${cgroup_root}/cpu/cpu.cfs_period_us" ]]; then
    # cgroup v1: a quota of -1 is none.
    quota="$(cat "${cgroup_root}/cpu/cpu.cfs_quota_us")"
    period="$(cat "${cgroup_root}/cpu/cpu.cfs_period_us")"
  else
    return 0
  fi
  if [[ "${quota}" =~ ^[1-9][0-9]*$ && "${period}" =~ ^[1-9][0-9]*$ ]]; then
    echo $(( (quota + period - 1) / period ))
  fi
}

cpus="$(nproc)"
budget_from="nproc, no lower cgroup CPU quota"
quota_cpus="$(cgroup_cpus)"
if [[ -n "${quota_cpus}" ]] && (( quota_cpus < cpus )); then
  cpus="${quota_cpus}"
  budget_from="the cgroup CPU quota"
fi

concurrency="${PARAM_BUILD_CONCURRENCY}"
if [[ "${concurrency}" == "auto" ]]; then
  concurrency="${cpus}"
fi
if [[ ! "${concurrency}" =~ ^[0-9]+$ ]] || (( 10#${concurrency} < 1 )); then
  echo "ERROR: 'build_concurrency' must be a positive integer or \"auto\" (got: ${PARAM_BUILD_CONCURRENCY})." >&2
  exit 1
fi
concurrency=$(( 10#${concurrency} ))

procs=$(( cpus / concurrency ))
if (( procs < 1 )); then
  procs=1
fi

echo "export GO_BUILD_CONCURRENCY=${concurrency}" >> "${BASH_ENV}"
echo "export GO_BUILD_PROCS=${procs}" >> "${BASH_ENV}"
echo "Compiling ${concurrency} architecture(s) at a time, -p ${procs} each (${cpus} CPU(s), from ${budget_from})."
