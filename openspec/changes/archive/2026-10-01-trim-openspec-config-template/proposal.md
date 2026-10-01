# Proposal

## Why

`openspec/config.yaml` contains only one active setting followed by 31 lines of unused example comments. The examples obscure the actual configuration without providing project-specific guidance.

## What Changes

- Remove unused template comments and retain `schema: spec-driven` unchanged.
- Keep all existing changes, specs and skill instructions intact.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

Only `openspec/config.yaml` changes during implementation. Pure configuration cleanup with `skip_specs: true`; no behavioral delta, dependencies, schema migration or framework.
