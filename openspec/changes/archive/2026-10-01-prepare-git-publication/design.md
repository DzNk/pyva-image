# Design

## Context

See proposal.md. Bazel outputs are root symlinks, not ordinary directories. `Dockerfile.poi-smoke` copies only `poi-smoke-pom.xml` and `poi_smoke.py` from the local context; Maven and Python dependencies come from its builder stages. No ignore files are present and the current Git index contains only `.bazelversion`.

## Goals / Non-Goals

**Goals:** A reviewable source-only Git candidate and minimal POI Docker context, with existing build inputs intact.
**Non-Goals:** Runtime changes, automatic staging/commit/push, Git/SSH setup, history rewriting, file deletion, license selection, CI or a new secret-scanning dependency.

## Decisions

- Use native Git patterns: root `/bazel-*` without a trailing slash so symlinks are ignored, Python `__pycache__/` and `*.py[cod]`, local `.venv/`/`venv/`, generated root `.agents/skills/`, and local `.codex/`, `.aws/`, `.ssh/`, `.docker/`, `.env`/`.env.*`, private `*.key` files and root consumer `certs/`. Keep `.env.example` eligible. Avoid generic `*.json`, `*.lock`, `*.tar*`, `*.pem` or hidden-file exclusions that hide source or public fixtures. Keep the complete `openspec/` tree, including archives, and any future project-owned agent instructions outside the generated skills directory.
- Use Docker's native exclusion/exception rules to allow only `Dockerfile.poi-smoke`, `poi-smoke-pom.xml` and `poi_smoke.py`. This also keeps Git metadata, local credentials and Bazel symlinks out of the context. No Dockerfile behavior change or custom context copier is needed.
- Add one small `test_repository.sh` using `git check-ignore --no-index` for representative excluded paths and explicitly included source/lock/OpenSpec paths, including currently tracked `.bazelversion`. Do not modify the real index or generate secrets. Verify Docker context with a temporary `FROM scratch`/`COPY .` diagnostic build and inspect its exported file list locally; keep the diagnostic Dockerfile/output outside the repository, never push it.
- Review `git ls-files` and the untracked, non-ignored candidate list, then check candidate text for obvious private-key/token signatures, reporting paths only. Document manual pre-commit review and existing offline checks in README. No claim of exhaustive secret detection.

## Risks / Trade-offs

- [An ignore file cannot remove already tracked secrets] → Inspect tracked files as well; stop and request direction on a finding rather than editing Git history. This is a limitation of [Git ignore rules](https://git-scm.com/docs/gitignore).
- [An allowlisted Docker context breaks future new local COPY inputs] → Keep its three current inputs explicit and document updating the allowlist together with Dockerfile changes; use [Docker's native context rules](https://docs.docker.com/build/concepts/context/#dockerignore-files).
- [Unrecognized secrets or forced `git add -f` bypass the guard] → Require manual candidate/staged review; ignore patterns and a signature scan are safeguards, not a security guarantee.

## Migration Plan

Add the ignore files and offline check, validate the candidate list and Docker context, run existing offline regressions, then hand off to the user for staging/commit/push. Rollback removes only these added tooling files and the README paragraph; leave local outputs, keys and Git state unchanged.
