# PR14.15 Connector Activity Timeline

## Executive Summary

PR14.15 adds connector activity timeline, not runtime sync.

The connector backbone now needs more than a final status. Admins must see what happened, when it happened, whether it was safe, and what the next product action is. PR14.15 turns existing connector setup records into a source-independent activity timeline for setup start, field contract preparation, dry-run preflight, and secure credential handoff.

Activity details are sanitized and source-independent. The timeline is meant to explain product state, not to expose provider payloads or secrets.

## What This Proves

- `/erp` can show a durable setup activity timeline for the selected connector.
- Setup start, field contract preparation, preflight, and credential handoff can be represented with product event keys.
- Safe error details can be displayed without raw Supabase errors, provider payloads, credentials, or secret values.
- Canias is one source profile; activity timeline is connector-agnostic.

## What This Does Not Prove

- No live connector runtime exists.
- No import, export, sync execution, credential capture, or ERP writeback is enabled.
- No connector-specific API error parser exists yet.
- No Notification Center delivery exists yet.

## Data Model

`erp_sync_batches remains metadata-only setup history.`

PR14.15 extends `puls_integration.erp_sync_batches` with product-owned activity metadata:

| Column | Purpose |
|--------|---------|
| `event_key` | Product event key for source-independent setup history |
| `actor_employee_id` | Employee who triggered an admin setup action when known |
| `safe_error_code` | Sanitized product error code for UI diagnostics |
| `safe_error_context` | Sanitized counters and product-state details only |
| `next_action_key` | Product next-action key for the activity row |

Safe error details must not include API keys, passwords, tokens, connection strings, FTP credentials, credentials_ref, or provider payloads.

## Timeline Contract

| Event | Source | Safe Detail | Next Action |
|-------|--------|-------------|-------------|
| `setup_started` | Connector setup selection | Owned domain count, mapping row count | Complete field mapping |
| `setup_mapping_contract_ready` | Default field contract creation | Owned domain count, mapping row count | Review source identity |
| `setup_preflight_completed` | Dry-run setup check | Check counters and blocked/warning check ids | Review setup findings or keep runtime closed |
| `credential_handoff_requested` | Admin secure reference handoff request | Request recorded, reference unavailable | Wait for secure reference |
| `sync_batch_recorded` | Future generic setup history row | Aggregate counters only | Review activity |

## UX Rules

- Timeline rows show title, actor, summary, safe details, next action, and timestamp.
- Raw enum values are mapped through i18n before display.
- Error rows show safe product explanations, not raw exception strings.
- Empty state remains useful for a tenant that has no setup activity yet.
- The timeline stays compact and readable on mobile, tablet, and desktop.

## Product Boundary

No import, export, sync execution, credential capture, or ERP writeback is enabled.

PR14.15 is an observability layer for setup readiness. It does not make PULS a Canias-only product, and it does not introduce a runtime connector. Canias is currently the seeded source profile, but the activity model is provider-agnostic and applies equally to CSV / Excel, Logo, Custom API, SFTP, or future connectors.

## Acceptance Criteria

- `ErpOverview` exposes `activityTimeline`.
- `/erp` renders activity timeline instead of raw sync-log copy.
- Setup start writes a `setup_lifecycle` history row.
- Preflight writes safe error details when warnings or blockers exist.
- Credential handoff writes a safe history row without configuring credentials.
- Verify bans provider payload, credential capture, runtime sync, import/export execution, and ERP writeback patterns.
