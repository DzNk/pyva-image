# Proposal

## Why

Git is initialized, but only `.bazelversion` is tracked and no repository ignore files exist. Publishing the remaining tree as-is would include Bazel output symlinks, Python caches and generated local agent tooling; the POI Docker build also uses the whole directory as its context.

## What Changes

- Add a focused `.gitignore` for build output, Python caches/virtual environments, generated local agent tooling and local credential paths, without hiding reproducibility inputs or OpenSpec history.
- Add a `.dockerignore` that admits only the current POI Dockerfile and its two source inputs.
- Leave one small offline Git ignore regression and document review/check commands before the user stages, commits and pushes.
- Inspect publishable files for obvious private keys/tokens and unexpected artifacts without printing secret values. Stop and report suspicious files instead of silently deleting them.

## Capabilities

### New Capabilities

None. Repository tooling only; `skip_specs: true`.

### Modified Capabilities

None. Runtime and image-publication contracts stay unchanged.

## Impact

Add `.gitignore`, `.dockerignore` and `test_repository.sh`; update README. Keep `.bazelversion`, `MODULE.bazel.lock`, `python_runtimes.MODULE.bazel`, build definitions, smoke examples/tests and the full `openspec/` tree publishable. Existing generated `.agents/skills/` are treated as local installed tooling, not product source. Do not change SSH keys, Git configuration/remotes/index/history, create a commit, push code or publish an image. Licensing and CI are out of scope until requested.
