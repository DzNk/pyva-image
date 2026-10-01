#!/usr/bin/env bash
# Offline regression: no real Docker, Bazel or registry operations.
set -euo pipefail

docker() {
  printf 'Operation: docker %s\n' "$*" >&2
  case "$*" in
    "image inspect --format {{index .Config.Labels \"org.opencontainers.image.version\"}} pyva-runtime:${test_minor}")
      printf '%s.99-java21-debian13\n' "$test_minor" ;;
    "image inspect --format {{index .RepoDigests 0}} ${test_repository}:${test_minor}.99-java21-debian13")
      printf '%s@sha256:%064d\n' "$test_repository" 0 ;;
    "pull ${test_repository}:${test_minor}.99-java21-debian13") test_pulled=true ;;
    'build '*|'run '*) ;;
    *) echo "Unexpected Docker command: $*" >&2; return 98 ;;
  esac
}

bazel() {
  printf 'Operation: bazel %s\n' "$*" >&2
  local expected=(run "//:pyva_runtime_${test_minor//./_}_push" -- --repository "$test_repository")
  if "$test_channel"; then
    expected+=(--tag "${test_minor}-java21-debian13")
  fi
  [[ "$*" == "${expected[*]}" ]] || return 98
}

bash() {
  printf 'Operation: bash %s\n' "$*" >&2
  [[ "$*" == "smoke_test.sh ${test_minor}" || "$*" == "smoke_test.sh ${test_minor} ${test_repository}:${test_minor}.99-java21-debian13" ]] || return 98
  printf 'Smoke: %s\n' "$*"
  if (( $# == 3 )); then
    [[ "${test_pulled:-false}" == true ]] || return 97
    if "$test_fail_remote"; then
      return 42
    fi
  fi
}

export -f docker bazel bash
export test_minor test_repository test_fail_remote test_channel
release_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/release.sh"

for test_minor in 3.13 3.14; do
  for path in example/pyva-runtime a0.b_1__c--2/r0.s_1__t---2; do
    test_repository="index.docker.io/${path}"
    for test_channel in false true; do
      args=()
      if "$test_channel"; then args+=(--channel); fi
      for test_fail_remote in false true; do
        alias_output=''
        for host in docker.io index.docker.io; do
          status=0
          output="$(command bash "$release_script" "${args[@]}" "$test_minor" "${host}/${path}" 2>&1)" || status=$?
          remote_image="${test_repository}:${test_minor}.99-java21-debian13"
          [[ "$output" == *"Smoke: smoke_test.sh ${test_minor} ${remote_image}"* ]]
          if "$test_fail_remote"; then
            [[ "$status" == 42 && "$output" != *"Published "* ]]
          else
            [[ "$status" == 0 && "$output" == *"Published ${remote_image} (${test_repository}@sha256:"* ]]
          fi
          if [[ "$host" == docker.io ]]; then alias_output="$output"; else [[ "$output" == "$alias_output" ]]; fi
        done
      done
    done
  done
done

reject() {
  local status=0 output
  output="$(command bash "$release_script" "$@" 2>&1)" || status=$?
  [[ "$status" == 2 && "$output" == *'usage:'* && "$output" != *'Operation:'* ]] || {
    printf 'Expected rejection before side effects: %s\n%s\n' "$*" "$output" >&2
    return 1
  }
}

reject
reject 3.13
reject --channel 3.13
reject 3.12 index.docker.io/example/runtime
reject 3.13 index.docker.io/example/runtime extra
for destination in '' example/runtime ghcr.io/example/runtime docker.io.evil/example/runtime \
  https://docker.io/example/runtime docker.io:443/example/runtime; do
  reject 3.13 "$destination"
done
for host in docker.io index.docker.io; do
  for path in example /runtime example/ example/runtime/ example//runtime example/runtime/extra \
    Example/runtime example/Runtime example/runtime:tag example/runtime@sha256:abcd \
    'exam ple/runtime' 'example/run time' 'example/runtime ' $'example/runtime\n' $'example/run\ttime' \
    -example/runtime example-/runtime example/.runtime example/runtime. \
    example/runtime..name example/runtime___name example/runtime_-name example/runtime+name; do
    reject 3.13 "${host}/${path}"
    reject --channel 3.14 "${host}/${path}"
  done
done

echo 'Release regression passed: alias equivalence, fail-fast validation and mandatory post-pull smoke'
