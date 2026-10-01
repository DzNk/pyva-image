# Tasks

## 1. Remove inactive configuration examples

- [x] 1.1 Remove only template comments and empty trailing boilerplate from `openspec/config.yaml`, preserving `schema: spec-driven` and any real settings present at implementation time; verify `openspec context --json`, change status and `openspec validate --specs --strict` behave unchanged. No specs or design document are required for this comment-only change.
