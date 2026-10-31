"""Require a native Linux x86-64 CPU level, including OS-enabled SIMD support."""

from pathlib import Path
import os
import subprocess
import sys


def check_cpu(level, report):
    if level not in ("v2", "v3"):
        raise ValueError("CPU variant must be v2 or v3")
    # glibc checks CPUID and OS-enabled register state, including AVX/OSXSAVE.
    if f"x86-64-{level} (supported, searched)" not in report:
        raise ValueError(f"runner does not support x86-64-{level}; optimized execution is required")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: python3 cpu_check.py v2|v3")
    linker = Path("/lib64/ld-linux-x86-64.so.2")
    if not linker.is_file():
        raise SystemExit("optimized execution requires a native Linux x86-64 glibc runner")
    report = subprocess.run([str(linker), "--help"], check=True, capture_output=True, text=True,
                            env={**os.environ, "LC_ALL": "C"}).stdout
    check_cpu(sys.argv[1], report)
    flags = [line for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("flags")]
    print(f"CPU {sys.argv[1]} supported (glibc CPU/OS check); runner flags:")
    print("\n".join(sorted(set(flags))))
