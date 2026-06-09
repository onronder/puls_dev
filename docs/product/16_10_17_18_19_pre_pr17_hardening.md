# PR16.10.17-19 Pre-PR17 Hardening Closure

## Goal

Close the final pre-PR17 trust-surface debts found in the Claude Code audits without adding new product promises or visible development notes.

## Scope

- PR16.10.17: new leave and expense requests must only use active setup targets, and performance cycles must follow a server-enforced lifecycle.
- PR16.10.18: persona switch audit must write to one deterministic audit target instead of cascading across legacy schemas.
- PR16.10.19: CSV / Excel import must surface formula-like text values and provide a safe export sanitizer without mutating canonical HR payloads.

## Safety Boundary

This closure does not:

- enable document upload;
- change workflow approval routing;
- execute connector jobs or canonical import apply jobs;
- add new AI Coach behavior;
- rename routes or alter DataSource Manager IA.

## Acceptance

- Request creation readiness blocks selected leave/expense targets that are no longer active.
- `/izin` and `/masraf` clear stale selected targets instead of submitting hidden stale IDs.
- Performance cycles can move only `draft -> active -> closed`, and only one active cycle is allowed per tenant.
- `logPersonaSwitch` writes only to `puls_audit.audit_logs` and never falls back to legacy audit schemas.
- File import parsing warns on formula-like text values; CSV export sanitization prefixes formula-like values.
- Typecheck, tests, i18n, build, and the PR16.10.17-19 verify gate pass.
