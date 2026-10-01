#!/usr/bin/env bash
set -euo pipefail

channel=false
usage() { echo "usage: $0 [--channel] 3.13|3.14 {docker.io|index.docker.io}/<namespace>/<repository>" >&2; }
if [[ "${1:-}" == --channel ]]; then channel=true; shift; fi
component='[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*'
if (( $# != 2 )) || [[ ! "$1" =~ ^3\.(13|14)$ ]] || [[ ! "$2" =~ ^(docker\.io|index\.docker\.io)/${component}/${component}$ ]]; then
  usage
  exit 2
fi
minor="$1"
repository="index.docker.io/${2#*/}"
target="pyva_runtime_${minor//./_}"

clean_source() {
  local source_state
  source_state="$(git status --porcelain --untracked-files=all)"
  if [[ -n "$source_state" ]]; then
    echo 'Release requires a clean committed source tree (including eligible untracked files)' >&2
    exit 1
  fi
}
clean_source
commit="$(git rev-parse --verify HEAD)"
[[ "$commit" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || { echo 'Invalid source commit' >&2; exit 1; }
epoch="$(git show -s --format=%ct HEAD)"
utc="$(python3 -c 'import datetime,sys; print(datetime.datetime.fromtimestamp(int(sys.argv[1]),datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))' "$epoch")"

bazel build "//:${target}"
read -r family index amd64_digest arm64_digest amd64_config arm64_config < <(python3 image_manifest.py local "bazel-bin/${target}" "$minor")
[[ -n "${arm64_config:-}" ]] || { echo 'Invalid candidate index' >&2; exit 1; }
immutable_tag="${family}-${utc}-g${commit}"
remote_image="${repository}:${immutable_tag}"
channel_image="${repository}:${minor}-java21-debian13"

for arch in amd64 arm64; do
  local_image="pyva-runtime:${minor}-${arch}"
  bash smoke_test.sh "$minor" --arch "$arch"
  expected_config="${arch}_config"
  docker image inspect --platform "linux/${arch}" --format '{{json .}}' "$local_image" | python3 image_manifest.py loaded "bazel-bin/${target}" "${!expected_config}"
  docker build --platform "linux/${arch}" --file Dockerfile.poi-smoke \
    --build-arg "PYTHON_VERSION=${minor}" --build-arg "RUNTIME_IMAGE=${local_image}" \
    --tag "pyva-poi-smoke:${minor}-${arch}" .
  docker run --rm --platform "linux/${arch}" "pyva-poi-smoke:${minor}-${arch}"
done

clean_source
[[ "$(git rev-parse --verify HEAD)" == "$commit" ]] || { echo 'Source commit changed during validation' >&2; exit 1; }
remote_dir="$(mktemp -d)"
trap 'rm -rf "$remote_dir"' EXIT
inspect_remote() {
  docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' > "$remote_dir/manifest.json" 2> "$remote_dir/error"
}
verify_remote() {
  python3 image_manifest.py remote "$index" "$amd64_digest" "$arm64_digest" < "$remote_dir/manifest.json"
}

# ponytail: serialize publishers; registry tags have no compare-and-set operation.
if inspect_remote "$remote_image"; then
  verify_remote
  echo "Identical immutable release already exists: ${remote_image}"
else
  error="$(cat "$remote_dir/error")"
  if [[ "$error" != "ERROR: ${remote_image}: not found" && "$error" != "ERROR: docker.io/${remote_image#*/}: not found" ]]; then
    printf 'Registry preflight failed: %s\n' "$error" >&2
    exit 1
  fi
  echo "Publishing ${remote_image}"
  bazel run "//:${target}_push" -- --repository "$repository" --tag "$immutable_tag"
fi

inspect_remote "$remote_image" || { cat "$remote_dir/error" >&2; exit 1; }
verify_remote
for arch in amd64 arm64; do
  docker pull --platform "linux/${arch}" "${repository}@${index}"
  expected_config="${arch}_config"
  docker image inspect --platform "linux/${arch}" --format '{{json .}}' "${repository}@${index}" | python3 image_manifest.py loaded "bazel-bin/${target}" "${!expected_config}"
  bash smoke_test.sh "$minor" --arch "$arch" "${repository}@${index}"
done

if "$channel"; then
  docker buildx imagetools create --tag "$channel_image" "${repository}@${index}"
  inspect_remote "$channel_image" || { cat "$remote_dir/error" >&2; exit 1; }
  verify_remote
fi
printf 'Published %s (%s@%s)\namd64 %s\narm64 %s\n' "$remote_image" "$repository" "$index" "$amd64_digest" "$arm64_digest"
