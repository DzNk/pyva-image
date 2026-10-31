"""Offline CPU capability and smoke argument boundary checks."""

import subprocess

from cpu_check import check_cpu


report = "  x86-64-v3 (supported, searched)\n  x86-64-v2 (supported, searched)\n"
for level in ("v2", "v3"):
    check_cpu(level, report)
for level, text in (("v1", report), ("v4", report), ("v3", "x86-64-v2 (supported, searched)"),
                    ("v2", "x86-64-v2"), ("v3", "x86-64-v3 (supported)")):
    try:
        check_cpu(level, text)
    except ValueError:
        pass
    else:
        raise AssertionError("unsupported CPU accepted")
for args in (("--cpu", "v4"), ("--arch", "arm64", "--cpu", "v2"), ("--cpu",), ("--arch", "wrong")):
    result = subprocess.run(["bash", "smoke_test.sh", "3.13", *args], capture_output=True, text=True)
    assert result.returncode == 2 and "usage:" in result.stderr, result.stderr
result = subprocess.run(["bash", "-c", '''
python3() { echo 'unsupported CPU' >&2; return 42; }
bazel() { echo 'unexpected build'; return 99; }
docker() { echo 'unexpected Docker'; return 99; }
export -f python3 bazel docker
command bash smoke_test.sh 3.13 --cpu v3
'''], capture_output=True, text=True)
assert result.returncode == 42 and not result.stdout and "unsupported CPU" in result.stderr
print("CPU checks passed: required ISA/OS support and invalid CPU/architecture arguments")
