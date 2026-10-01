#!/usr/bin/env bash
set -euo pipefail

channel=false

usage() {
  echo "usage: $0 [--channel] 3.13|3.14 {docker.io|index.docker.io}/<namespace>/<repository>" >&2
}

if [[ "${1:-}" == "--channel" ]]; then
  channel=true
  shift
fi

component='[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*'
if (( $# != 2 )) || [[ ! "$1" =~ ^3\.(13|14)$ ]] || [[ ! "$2" =~ ^(docker\.io|index\.docker\.io)/${component}/${component}$ ]]; then
  usage
  exit 2
fi

minor="$1"
repository="index.docker.io/${2#*/}"
target="pyva_runtime_${minor//./_}"
local_image="pyva-runtime:${minor}"

echo "Validating Python ${minor}"
bash smoke_test.sh "$minor"
immutable_tag="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$local_image")"
channel_tag="${minor}-java21-debian13"
remote_image="${repository}:${immutable_tag}"
push_args=(--repository "$repository")

if "$channel"; then
  push_args+=(--tag "$channel_tag")
fi

docker build --platform linux/amd64 --file Dockerfile.poi-smoke \
  --build-arg "PYTHON_VERSION=${minor}" --build-arg "RUNTIME_IMAGE=${local_image}" \
  --tag "pyva-poi-smoke:${minor}" .
docker run --rm "pyva-poi-smoke:${minor}"

echo "Publishing ${remote_image}"
bazel run "//:${target}_push" -- "${push_args[@]}"

docker pull "$remote_image"
bash smoke_test.sh "$minor" "$remote_image"
digest="$(docker image inspect --format '{{index .RepoDigests 0}}' "$remote_image")"
if [[ -z "$digest" ]]; then
  echo "Docker did not report a repository digest for ${remote_image}" >&2
  exit 1
fi

printf 'Published %s (%s)\n' "$remote_image" "$digest"
