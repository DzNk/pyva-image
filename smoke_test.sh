#!/usr/bin/env bash
set -euo pipefail

usage() { echo "usage: $0 3.13|3.14 [--arch amd64|arm64] [image-reference]" >&2; exit 2; }
(( $# >= 1 )) && [[ "$1" =~ ^3\.(13|14)$ ]] || usage
minor="$1"
shift
arch=amd64
if [[ "${1:-}" == --arch ]]; then
  (( $# >= 2 )) || usage
  arch="$2"
  shift 2
fi
[[ "$arch" == amd64 || "$arch" == arm64 ]] && (( $# <= 1 )) || usage
image="${1:-pyva-runtime:${minor}-${arch}}"

if (( $# == 0 )); then
  target="pyva_runtime_${minor//./_}_${arch}_load"
  bazel build "//:${target}" --output_groups=tarball
  docker load --input "bazel-bin/${target}/tarball.tar"
fi

platform="$(docker image inspect --platform "linux/${arch}" --format '{{.Os}}/{{.Architecture}}' "$image")"
identity="$(docker image inspect --platform "linux/${arch}" --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$image")"
if [[ "$platform" != "linux/${arch}" || ! "$identity" =~ ^3\.(13|14)\.[0-9]+-java21-debian13$ || "$identity" != "$minor".* ]]; then
  echo "unexpected image identity: ${identity} (${platform}), expected Python ${minor} on linux/${arch}" >&2
  exit 1
fi
version="${identity%-java21-debian13}"

docker run --rm --platform "linux/${arch}" --entrypoint /usr/bin/python3 "$image" -c '
import os, pathlib, platform, subprocess, sys
import ssl, ctypes, sqlite3, bz2, lzma, uuid, readline, multiprocessing, venv
assert platform.python_version() == sys.argv[1]
arch = sys.argv[2]
assert platform.machine() == {"amd64": "x86_64", "arm64": "aarch64"}[arch]
assert os.geteuid() == os.getegid() == 65532
assert os.stat("/app").st_uid == 65532
assert os.getcwd() == "/app"
java_home = "/usr/lib/jvm/java-21-openjdk-" + arch
assert os.environ["JAVA_HOME"] == java_home
assert os.environ["LD_LIBRARY_PATH"] == java_home + "/lib/server"
assert os.environ["SSL_CERT_DIR"] == "/etc/certs"
assert pathlib.Path("/etc/certs").is_dir()
assert not list(pathlib.Path("/etc/certs").iterdir())
ctypes.CDLL(java_home + "/lib/server/libjvm.so")
for directory in ("/bin", "/sbin", "/usr/bin", "/usr/sbin"):
    for executable in ("sh", "bash", "dash", "ash", "apt", "apt-get", "dpkg", "rpm", "apk"):
        assert not pathlib.Path(directory, executable).exists(), executable
java = subprocess.run(["java", "-version"], check=True, capture_output=True, text=True)
assert "openjdk version \"21." in java.stderr
' "$version" "$arch"

cert_dir="$(mktemp -d)"
trap 'rm -rf "$cert_dir"' EXIT
chmod 755 "$cert_dir"
printf '%s\n' '-----BEGIN CERTIFICATE-----' 'AA==' '-----END CERTIFICATE-----' > "$cert_dir/test.pem"
docker run --rm --platform "linux/${arch}" --volume "$cert_dir:/etc/certs:ro" "$image" -c '
from pathlib import Path
assert Path("/etc/certs/test.pem").read_text().startswith("-----BEGIN CERTIFICATE-----")
'
printf 'Verified %s: CPython %s, %s\n' "$image" "$version" "$platform"
