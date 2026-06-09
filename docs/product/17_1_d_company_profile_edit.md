# PR17.1D — Company Profile Edit

> **Status:** PR17.1 fourth implementation slice.
> **Scope:** Tenant display profile and work defaults only. No tax ID edit, plan edit, connector runtime, source writeback, notification producer, or AI Coach wiring.

## Why

PR17.0 identified `/sirket-kurulum` as a read-only setup page even though connector-independent HR needs a usable tenant profile. PR17.1A-C made Core HR records auditable, lifecycle-safe, and actionable. PR17.1D opens the smallest useful company setup loop: admins can update the visible company name, sector, default language, and timezone from the existing setup screen.

## What Changed

- Adds `puls_core.update_company_profile(...)` as the single server-side write path.
- Allows changes only for current-tenant setup admins.
- Validates company display name, sector length, supported locale, and valid Postgres timezone.
- Updates `puls_core.tenants.trade_name`, `industry`, `locale`, and `timezone`.
- Writes metadata-only company profile audit evidence to `puls_audit.audit_logs`.
- Adds typed frontend adapters, error mapping, i18n, and a compact inline edit form in `/sirket-kurulum`.
- Invalidates company setup, setup readiness, and settings overview queries after save.

## Product Contract

- `/sirket-kurulum` remains an admin setup summary, not an onboarding notebook.
- The company information card has one edit entry point and one primary save action.
- Tax ID, plan, employee band, readiness, connector status, and package data remain read-only.
- Demo or unauthorized states do not show the edit action.
- No raw payload, credential, connector execution, ERP writeback, source writeback, or technical runbook is shown in the UI.

## Non-Goals

- No legal/tax identity update.
- No plan/package management.
- No organization create/update beyond the existing PR17.1B/C flows.
- No notification producer.
- No AI context wiring.
- No settings page rewrite.

## Verification

Run:

```bash
bash scripts/verify-17-1-d-company-profile-edit.sh
```

The verify script checks the migration RPC, server guardrails, adapter exports, UI wiring, i18n keys, README link, and no-writeback boundaries.
