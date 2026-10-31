#!/usr/bin/env bash
set -euo pipefail

usage() { echo "usage: $0 3.13|3.14 [--arch amd64|arm64] [--cpu v2|v3] [image-reference]" >&2; exit 2; }
(( $# >= 1 )) && [[ "$1" =~ ^3\.(13|14)$ ]] || usage
minor="$1"
shift
arch=amd64
cpu=
while [[ "${1:-}" == --* ]]; do
  (( $# >= 2 )) || usage
  case "$1" in
    --arch) arch="$2" ;;
    --cpu) [[ "$2" == v2 || "$2" == v3 ]] || usage; cpu="$2" ;;
    *) usage ;;
  esac
  shift 2
done
[[ "$arch" == amd64 || "$arch" == arm64 ]] && (( $# <= 1 )) || usage
[[ -z "$cpu" || "$arch" == amd64 ]] || usage
selection="$arch${cpu:+-$cpu}"
image="${1:-pyva-runtime:${minor}-${selection}}"
if [[ -n "$cpu" ]]; then python3 cpu_check.py "$cpu"; fi

if (( $# == 0 )); then
  target="pyva_runtime_${minor//./_}_${selection//-/_}_load"
  bazel build "//:${target}" --output_groups=tarball
  docker load --input "bazel-bin/${target}/tarball.tar"
fi

platform="$(docker image inspect --platform "linux/${arch}" --format '{{.Os}}/{{.Architecture}}' "$image")"
identity="$(docker image inspect --platform "linux/${arch}" --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$image")"
cpu_identity="$(docker image inspect --platform "linux/${arch}" --format '{{index .Config.Labels "io.pyva.cpu.variant"}}' "$image")"
if [[ -n "$cpu" ]]; then
  [[ "$cpu_identity" == "$cpu" ]] || { echo 'CPU variant differs from selected image' >&2; exit 1; }
else
  [[ -z "$cpu_identity" || "$cpu_identity" == '<no value>' || "$cpu_identity" == v1 ]] || { echo 'Optimized image cannot substitute baseline' >&2; exit 1; }
fi
if [[ "$platform" != "linux/${arch}" || ! "$identity" =~ ^3\.(13|14)\.[0-9]+-java21-debian13$ || "$identity" != "$minor".* ]]; then
  echo "unexpected image identity: ${identity} (${platform}), expected Python ${minor} on linux/${arch}" >&2
  exit 1
fi
version="${identity%-java21-debian13}"

docker run --rm --platform "linux/${arch}" --entrypoint /usr/bin/python3 "$image" -c '
import importlib.metadata, importlib.util, os, pathlib, platform, subprocess, sys, tempfile
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
