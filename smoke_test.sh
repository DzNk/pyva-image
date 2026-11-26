#!/usr/bin/env bash
set -euo pipefail

usage() { echo "usage: $0 3.13|3.14 [--java 21|25] [--arch amd64|arm64] [image-reference]" >&2; exit 2; }
(( $# >= 1 )) && [[ "$1" =~ ^3\.(13|14)$ ]] || usage
minor="$1"
shift
arch=amd64
java=21
while [[ "${1:-}" == --* ]]; do
  (( $# >= 2 )) || usage
  case "$1" in
    --arch) arch="$2" ;;
    --java) [[ "$2" == 21 || "$2" == 25 ]] || usage; java="$2" ;;
    *) usage ;;
  esac
  shift 2
done
[[ "$arch" == amd64 || "$arch" == arm64 ]] && (( $# <= 1 )) || usage
if [[ "$java" == 21 ]]; then java_variant=; else java_variant="-java$java"; fi
image="${1:-pyva-runtime:${minor}${java_variant}-${arch}}"

if (( $# == 0 )); then
  target="pyva_runtime_${minor//./_}${java_variant//-/_}_${arch}_load"
  bazel build "//:${target}" --output_groups=tarball
  docker load --input "bazel-bin/${target}/tarball.tar"
fi

platform="$(docker image inspect --platform "linux/${arch}" --format '{{.Os}}/{{.Architecture}}' "$image")"
identity="$(docker image inspect --platform "linux/${arch}" --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$image")"
cpu_identity="$(docker image inspect --platform "linux/${arch}" --format '{{index .Config.Labels "io.pyva.cpu.variant"}}' "$image")"
[[ -z "$cpu_identity" || "$cpu_identity" == '<no value>' || "$cpu_identity" == v1 ]] || { echo 'Optimized image cannot substitute baseline' >&2; exit 1; }
if [[ "$platform" != "linux/${arch}" || ! "$identity" =~ ^3\.(13|14)\.[0-9]+-java${java}-debian13$ || "$identity" != "$minor".* ]]; then
  echo "unexpected image identity: ${identity} (${platform}), expected Python ${minor} and Java ${java} on linux/${arch}" >&2
  exit 1
fi
version="${identity%-java${java}-debian13}"

java_properties="$(docker run --rm --platform "linux/${arch}" --entrypoint /usr/bin/python3 "$image" -c '
import importlib.metadata, importlib.util, json, os, pathlib, platform, subprocess, sys, tempfile
import ssl, ctypes, sqlite3, bz2, lzma, uuid, readline, multiprocessing, venv
assert platform.python_version() == sys.argv[1]
arch = sys.argv[2]
major = sys.argv[3]
assert platform.machine() == {"amd64": "x86_64", "arm64": "aarch64"}[arch]
assert os.geteuid() == os.getegid() == 65532
assert os.stat("/app").st_uid == 65532
assert os.getcwd() == "/app"
java_home = f"/usr/lib/jvm/java-{major}-openjdk-{arch}"
assert os.environ["JAVA_HOME"] == java_home
assert os.environ["LD_LIBRARY_PATH"] == java_home + "/lib/server"
assert os.environ["SSL_CERT_DIR"] == "/etc/certs"
for module in ("pip", "ensurepip", "setuptools", "pkg_resources", "_distutils_hack"):
    assert importlib.util.find_spec(module) is None, module
distributions = {d.metadata["Name"].lower().replace("_", "-") for d in importlib.metadata.distributions()}
assert not distributions.intersection({"pip", "setuptools"}), distributions
stdlib = pathlib.Path("/usr/lib/python" + ".".join(platform.python_version_tuple()[:2]))
for pattern in ("ensurepip", "site-packages/pip", "site-packages/pip-*.dist-info", "site-packages/setuptools", "site-packages/setuptools-*.dist-info", "site-packages/pkg_resources", "site-packages/_distutils_hack", "site-packages/distutils-precedence.pth"):
    assert not list(stdlib.glob(pattern)), pattern
for command in ("pip", "pip3", "pip" + ".".join(platform.python_version_tuple()[:2])):
    assert not os.path.lexists("/usr/bin/" + command), command
for module in ("pip", "ensurepip"):
    result = subprocess.run([sys.executable, "-m", module], capture_output=True, text=True)
    assert result.returncode != 0 and "No module named " + module in result.stderr, result.stderr
with tempfile.TemporaryDirectory() as directory:
    venv.create(directory, with_pip=False)
    subprocess.run([directory + "/bin/python", "-c", "import sys; assert sys.prefix != sys.base_prefix"], check=True)
assert pathlib.Path("/etc/certs").is_dir()
assert not list(pathlib.Path("/etc/certs").iterdir())
ctypes.CDLL(java_home + "/lib/server/libjvm.so")
for directory in ("/bin", "/sbin", "/usr/bin", "/usr/sbin"):
    for executable in ("sh", "bash", "dash", "ash", "apt", "apt-get", "dpkg", "rpm", "apk"):
        assert not pathlib.Path(directory, executable).exists(), executable
java = subprocess.run(["java", "-XshowSettings:properties", "-version"], capture_output=True, text=True)
if java.returncode:
    raise SystemExit(java.stderr)
properties = {}
for line in java.stderr.splitlines():
    key, separator, value = line.strip().partition(" =")
    if separator:
        properties[key] = value.strip()
assert properties["java.specification.version"] == major, java.stderr
assert properties["java.home"] == java_home, java.stderr
print(json.dumps({key: properties[key] for key in ("java.runtime.version", "java.vendor")}))
' "$version" "$arch" "$java")" || {
  echo "Runtime smoke failed for Python $minor, Java $java, linux/$arch" >&2
  exit 1
}
if [[ "${PYVA_STRICT_JAVA:-0}" == 1 ]]; then
  python3 -c '
import json
import sys
from update_java_manifest import verify_runtime

try:
    verify_runtime(sys.argv[1], json.loads(sys.argv[2]))
except (KeyError, ValueError) as error:
    raise SystemExit(f"Python {sys.argv[3]} on linux/{sys.argv[4]}: {error}") from error
' "$java" "$java_properties" "$minor" "$arch"
fi

cert_dir="$(mktemp -d)"
trap 'rm -rf "$cert_dir"' EXIT
chmod 755 "$cert_dir"
printf '%s\n' '-----BEGIN CERTIFICATE-----' 'AA==' '-----END CERTIFICATE-----' > "$cert_dir/test.pem"
docker run --rm --platform "linux/${arch}" --volume "$cert_dir:/etc/certs:ro" "$image" -c '
from pathlib import Path
assert Path("/etc/certs/test.pem").read_text().startswith("-----BEGIN CERTIFICATE-----")
'
printf 'Verified %s: CPython %s, %s, %s\n' "$image" "$version" "$platform" "$java_properties"
