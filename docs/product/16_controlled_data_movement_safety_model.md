# PR16 Controlled Data Movement Safety Model

Date: 5 June 2026

## Executive Summary

PR16 must not open a blind import apply path. The first controlled data movement must treat every write as a change-set decision: what will be created, what would be overwritten, which source owns the field, what the current canonical value is, and how the change can be safely reviewed or compensated.

The first production-safe execution path is create-only master-data import. Guarded updates, destructive-equivalent changes, rollback execution, provider API runtime, ERP/source writeback, and AI autonomous actions stay closed until their own safety gates are implemented.

## Business Scenarios

| Scenario | Product response |
| --- | --- |
| New customer onboarding with clean org master data | Allow create-only controlled import after preview, review, approval, change-set, and worker execution. |
| ERP connector not ready, HR uploads monthly Excel | Allow controlled import as a fallback, not as a replacement for connector runtime. |
| Existing data would be overwritten | Block by default; require guarded update policy and before snapshot. |
| Wrong Excel file uploaded | Preview/change-set shows risk before write; apply remains blocked if stale, destructive, or unapproved. |
| Wrong data was already applied | Generate rollback or compensating preview; execution requires approval and current-state guard. |
| Manual source conflicts with ERP-owned data | Block or skip according to source ownership and priority rules. |

## Non-Negotiable Rules

- No browser direct canonical write.
- No authenticated direct `apply_import_batch` execution from app code.
- No worker `import_apply` claim until PR16 enablement gates are proven.
- No blind overwrite.
- No missing-field clear. Missing field means preserve existing value.
- Explicit clear-field requires its own risk class and approval.
- No delete/tombstone sync in PR16 MVP.
- No ERP/source writeback.
- No raw payload, credential value, or provider response in UI, AI context, Sentry, or notification payloads.
- No AI-triggered import/apply/rollback.
- No canonical insert, update, soft-delete, restore, rollback, or compensating update without an audit decision.

## CRUD Audit And Retention Model

PR16 should not use a full physical row-trigger audit for every table as the first implementation. That is noisy, expensive, and likely to retain more personal data than the product needs. The primary audit boundary should be the business object mutation: one append-only object event for each canonical object that a worker creates, updates, soft-deletes, restores, rolls back, or compensates.

Detailed update evidence is still required. For guarded updates, PR16 must store field-level before/after diffs for the changed fields only. Those diffs support admin transparency, AI-safe summaries, and rollback planning without turning the hot database into an unlimited row-version archive.

| Audit tier | Granularity | Purpose | Access | Default hot retention |
| --- | --- | --- | --- | --- |
| Object event ledger | One row per business object mutation | Tenant/company transparency, activity timeline, AI-safe summaries, approval proof | Admin-visible safe summary; service-role write | 12-24 months or tenant policy |
| Field diff ledger | One row per changed field for guarded updates and rollback-relevant changes | Show exactly what changed and detect overwrite risk | Safe/redacted UI summary; sensitive values service-role-only | 90 days default |
| Rollback snapshot | Before image or compact before-hash metadata per object | Generate rollback or compensating preview | Service-role-only; no UI/AI raw readback | 90 days default |
| Archive summary | Cold, optional object-level export | Longer contractual audit without hot DB growth | Restricted operational access | Contract-specific |

### Audit Storage Rules

- Object-level audit is mandatory for every canonical mutation opened by PR16.
- Field-level diff is mandatory for updates and destructive-equivalent attempts; creates may store a safe object summary instead of every field.
- Sensitive personal data should be redacted in UI/AI summaries. If rollback requires exact values, store them only in a service-role-only/encrypted rollback snapshot with retention.
- Missing fields must not create audit noise or clear values. Only explicit changed fields enter the field diff ledger.
- Delete/tombstone remains closed in PR16 MVP. If a future PR opens soft-delete, restore, or tombstone sync, it must emit object event, field/status diff, approval evidence, and rollback/compensation metadata.
- Retention is a product policy, not an afterthought: hot field diffs and rollback snapshots default to 90 days; object events can live longer because they contain safe summaries.
- A purge/archive job must be part of the implementation plan before any high-volume update path opens.
- KVKK-oriented transparency and minimization both matter: PULS should show who/what changed what and why, while avoiding unnecessary raw personal data retention.

## Risk Classes

| Risk class | Meaning | MVP behavior |
| --- | --- | --- |
| `create_only` | Canonical target does not exist; row creates a new safe master-data record. | Allowed first. |
| `safe_additive_update` | Existing target receives low-risk additive update. | Block until guarded update PR. |
| `guarded_overwrite` | Existing value would change. | Requires before snapshot, source ownership, approval, and stale guard. |
| `destructive_equivalent` | Status, active flag, assignment close, manager/reporting line, or explicit clear. | Block by default. |
| `source_conflict` | Lower-priority/manual source tries to overwrite higher-priority owned field. | Block or skip. |
| `stale_preview` | Canonical current hash changed after preview/change-set. | Re-preview required. |
| `rollback_required` | Applied change may need reversal or compensation. | Generate rollback preview only. |

## PR16 Delivery Order

### PR16.1 - Apply Safety Contract And Permission Hardening

Define apply policies, close direct/browser apply surfaces, define CRUD audit tiers and retention defaults, and keep canonical writes closed. Existing DB apply helpers may be reused only behind a worker-safe wrapper after permission and policy hardening.

### PR16.2 - Change Set And Before Snapshot

Generate immutable apply change-sets from previewed batches. Store safe UI summaries, field diff intent, object audit intent, retention bucket, and service-role-only before snapshot metadata. No canonical write yet.

### PR16.3 - Create-Only Worker Apply

Open the first real write path for create-only reference master data. Existing targets are blocked or skipped; no update, no status change, no assignment close. Every created object emits an object event ledger entry and row-level apply result.

### PR16.4 - Guarded Update Apply

Open limited allowlisted updates with source ownership, before snapshot, expected current hash, approval, object event audit, and field-level diff ledger evidence.

### PR16.5 - Rollback / Compensating Preview And Execution

Generate rollback or compensating previews from applied change-sets and rollback snapshots. Execute only through approval and worker boundary. Emit rollback/compensation audit events and block rollback if current state drifted.

### PR16.6 - Notification Center Foundation

Notify admins about completed imports, blocked overwrites, stale previews, rollback-required states, and dead-letter jobs without raw payloads.

### PR16.7 - Canias Runtime Spike

Canias creates import batches and previews through the same generic safety model. It cannot bypass change-set, approval, worker execution, or rollback rules.

### PR16.8 - AI Operational Recommendations

AI reads safe evidence from change-sets, job events, import results, and canonical summaries. It recommends review and next steps; it does not execute actions.

## Implementation Guardrails

- The first enabled production worker job type should remain `noop_health,connector_runtime_preflight` until PR16.3 is ready.
- When PR16.3 is ready, add `import_apply` only with create-only policy checks.
- Keep one Railway worker replica until duplicate execution and idempotency are proven under apply load.
- Prefer service-role RPC wrappers that accept batch/job ids and derive tenant/source context server-side.
- Every apply execution must produce connector job events, safe activity events, row-level results, and recovery metadata.
- Every canonical mutation must produce an object audit event; every guarded update must produce field diff evidence and retention metadata.
- Purge/archive behavior for field diffs and rollback snapshots must be implemented before high-volume update paths open.

## Acceptance Criteria

- A previewed batch cannot apply without a change-set.
- A change-set cannot execute without review and admin approval.
- A canonical current hash mismatch blocks execution.
- Existing records are not overwritten in create-only mode.
- Missing fields never clear existing values.
- Rollback execution is impossible without rollback preview and approval.
- AI and UI never receive raw payloads, secret values, or provider responses.
- Insert, update, soft-delete, restore, rollback, and compensating update operations have an explicit audit policy before they are enabled.
- Field diffs and rollback snapshots have a default 90-day hot retention policy, plus purge/archive ownership.
