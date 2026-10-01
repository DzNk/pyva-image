# Design

## Context

See proposal.md. release.sh currently permits only index.docker.io with a permissive non-slash component regex. The main publication spec explicitly accepts docker.io. Both names must use one reference throughout digest checks and publication.

## Goals / Non-Goals

**Goals:** Fix the contract mismatch without expanding the destination surface.
**Non-Goals:** Implicit Docker Hub hosts, URL parsing libraries, other registries, nested namespaces, tag/digest input or credential flags.

## Decisions

- Validate the complete input before building: an explicitly allowed host and exactly two lowercase Docker repository components. Use the platform's component grammar, including its supported separator forms, rather than the current `[^/@:]+` approximation.
- Normalize only an accepted docker.io prefix to index.docker.io, once, and assign the canonical result to the existing repository variable. Do not normalize arbitrary schemes, paths or whitespace into acceptable input.
- Retain the existing CLI positional arguments and external Docker authentication. Update usage and README to show both accepted aliases and the canonical output.
- Use one offline argument regression to verify valid alias equivalence and reject missing/foreign hosts, uppercase or invalid components, schemes, tags, digests, whitespace and extra segments before any build/upload command. Coordinate this with the release-check file from `protect-release-tag-digests` instead of adding a second test framework.

## Risks / Trade-offs

- [Different spellings split credential or digest handling] → All downstream operations use the one existing canonical hostname.
- [More precise component validation rejects previously accepted bad input] → Document it as input validation, with diagnostics and no side effects.
- [Other release changes collide] → Apply normalization at the argument boundary; digest and channel code consume its result without another parser.

## Migration Plan

Update validation and normalization, document both aliases and run offline accepted/rejected cases plus shell syntax validation. Verify references with command stubs; do not publish externally to validate spelling. Rollback keeps source and documentation coherent.
