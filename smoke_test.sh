#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 || $# > 2 )) || [[ ! "$1" =~ ^3\.(13|14)$ ]]; then
  echo "usage: $0 3.13|3.14 [image-reference]" >&2
  exit 2
fi

minor="$1"
image="${2:-pyva-runtime:${minor}}"

if (( $# == 1 )); then
  target="pyva_runtime_${minor//./_}_load"
  bazel build "//:${target}" --output_groups=tarball
  docker load --input "bazel-bin/${target}/tarball.tar"
fi

platform="$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image")"
identity="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$image")"
if [[ "$platform" != "linux/amd64" ]] || [[ ! "$identity" =~ ^3\.(13|14)\.[0-9]+-java21-debian13$ ]] || [[ "$identity" != "$minor".* ]]; then
  echo "unexpected image identity: ${identity} (${platform}), expected Python ${minor} on linux/amd64" >&2
  exit 1
fi
version="${identity%-java21-debian13}"

cert_dir="$(mktemp -d)"
trap 'rm -rf "$cert_dir"' EXIT
chmod 755 "$cert_dir"
printf '%s\n' '-----BEGIN CERTIFICATE-----' 'AA==' '-----END CERTIFICATE-----' > "$cert_dir/test.pem"

docker run --rm --entrypoint /usr/bin/python3 \
  --volume "$cert_dir:/etc/certs:ro" \
  "$image" -c '
import os, pathlib, platform, subprocess, sys
assert sys.version_info[:2] == tuple(map(int, sys.argv[1].split(".")))
assert platform.python_version() == sys.argv[2]
assert platform.machine() == "x86_64"
import _sqlite3, _ssl, ctypes, venv
assert os.geteuid() == 65532
assert os.stat("/app").st_uid == 65532
assert os.environ["JAVA_HOME"] == "/usr/lib/jvm/java-21-openjdk-amd64"
assert pathlib.Path("/etc/certs/test.pem").read_text().startswith("-----BEGIN CERTIFICATE-----")
libjvm = "/usr/lib/jvm/java-21-openjdk-amd64/lib/server/libjvm.so"
assert pathlib.Path(libjvm).is_file()
ctypes.CDLL(libjvm)
assert not pathlib.Path("/bin/sh").exists()
assert not pathlib.Path("/usr/bin/apt-get").exists()
java = subprocess.run(["java", "-version"], check=True, capture_output=True, text=True)
assert "openjdk version \"21." in java.stderr
' "$minor" "$version"
printf 'Verified %s: CPython %s, %s\n' "$image" "$version" "$platform"
