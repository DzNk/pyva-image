#!/usr/bin/env bash
# Offline policy check; does not stage files or modify the Git index.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

for path in bazel-bin bazel-out bazel-testlogs bazel-pyva-image \
  __pycache__/module.pyc app/__pycache__/module.pyc module.pyc module.pyo module.pyd \
  .venv/bin/python venv/bin/python .agents/skills/openspec-propose/SKILL.md \
  .codex/config.toml .aws/credentials .ssh/id_ed25519 .docker/config.json \
  .env .env.local app/.env secret.key certs/deployment.pem; do
  git -c core.excludesFile=/dev/null check-ignore --no-index -q -- "$path" || {
    printf 'Expected ignored path: %s\n' "$path" >&2
    exit 1
  }
done

for path in .bazelversion .gitignore .dockerignore .env.example \
  BUILD.bazel MODULE.bazel MODULE.bazel.lock python_runtimes.MODULE.bazel \
  runtime_image.bzl update_python_manifest.py README.md \
  Dockerfile.poi-smoke poi-smoke-pom.xml poi_smoke.py \
  release.sh smoke_test.sh test_python_manifest.py test_release.sh test_repository.sh \
  openspec/config.yaml openspec/specs/python-jvm-runtime-image/spec.md \
  openspec/changes/archive/2026-10-01-build-python-jvm-golden-image/.openspec.yaml \
  openspec/changes/prepare-git-publication/tasks.md \
  .agents/AGENTS.md fixtures/public.pem docs/bazel-notes.md; do
  status=0
  git -c core.excludesFile=/dev/null check-ignore --no-index -q -- "$path" || status=$?
  if (( status != 1 )); then
    printf 'Expected publishable path: %s (status %s)\n' "$path" "$status" >&2
    exit 1
  fi
done

echo 'Repository ignore regression passed'
