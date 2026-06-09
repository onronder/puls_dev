# PR16.10.20 Pre-PR17 CI Gate

## Goal

PR16.10.20 makes the PR16.10.13-19 hardening invariants part of CI before PR17 begins. It also adds a read-only audit query for tenants that may already have multiple active performance cycles from data created before lifecycle hardening.

## Scope

- Add `pnpm run verify:pre-pr17` as a single local and CI entry point.
- Run the PR16.10.13, 16.10.14, 16.10.15, 16.10.16, and 16.10.17-19 verify scripts from that entry point.
- Add a PR16.10.20 verify guard so the CI binding and audit query do not silently drift.
- Add a read-only duplicate active performance cycle audit query.

## Safety Boundary

- No product UI changes.
- No database mutation in the duplicate active cycle audit query.
- No automatic performance cycle cleanup.
- No HR closed-loop productization in this PR.

## Acceptance

- CI quality job runs `pnpm run verify:pre-pr17`.
- `scripts/verify-pre-pr17.sh` runs every PR16.10.13-20 verify script.
- `docs/data/16_10_20_performance_active_cycle_duplicate_audit.sql` only reads from `puls_performance.performance_cycles` and `puls_core.tenants`.
- Existing Supabase temp files remain out of the PR scope.
