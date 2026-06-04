# PR14.8-PR14.19 Connector Implementation Roadmap

PR14.8 through PR14.19 turns the connector setup surface from a proven empty-state and preflight UI into a persisted, observable, source-independent setup flow with safe preview, human review, controlled apply design, and explicit admin approval policy boundaries. The goal is not to build a Canias-only product. The goal is to make PULS a canonical HR operations layer that can connect to many external data sources through stable mapping, namespace, identity, preflight, credential-boundary, preview, review-readiness, approval-policy, and apply-gate contracts.

## Product Claim

PULS is data-source independent. Canias is the first native ERP connector, not the product abstraction.

Canonical data model, unified source namespaces, and domain-level source ownership are the stable product boundary.

Connector setup persistence comes before connector runtime.

Runtime sync, credential capture, ERP writes, and destructive operations remain closed until the setup, observability, mapping, and preflight contracts are proven.

## Decisions Locked Before PR14.8

| Decision           | Product direction                                                                                                                                                                                               |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Connector scope    | A tenant may use more than one data source when different domains live in different systems.                                                                                                                    |
| Provider posture   | Canias and CSV / Excel are MVP setup candidates; Logo and Custom API can remain future-ready provider cards.                                                                                                    |
| Data ownership     | Source priority must be domain-based, not a single global tenant switch.                                                                                                                                        |
| Persistence target | Use `puls_integration.erp_connections` lifecycle state instead of a separate setup-draft table.                                                                                                                 |
| Write access       | Admin can create and edit connector setup. Manager can inspect read-only. Employee cannot access setup routes.                                                                                                  |
| Credentials        | PR14.8 does not collect or store API keys, passwords, FTP secrets, OAuth tokens, or connector credentials. Future credential capture must use a secret boundary and store only a reference in product metadata. |
| Runtime boundary   | No live connector calls, no import execution, no sync button, no ERP writes.                                                                                                                                    |
| Testing posture    | Live authenticated e2e must prove seeded Puls Teknik and empty PULS Connector Lab behavior by role.                                                                                                             |

## Implementation Sequence

| PR       | Name                                 | Outcome                                                                                                                                  |
| -------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| PR14.8   | Connector setup persistence          | Provider selection creates a tenant-scoped setup record, survives refresh, and changes dashboard / ERP posture.                          |
| PR14.9   | Error observability and Sentry       | Frontend and backend-visible setup failures are captured, scrubbed, and shown with user-friendly recovery paths.                         |
| PR14.10  | Mapping discovery                    | Source fields can be discovered or declared, then mapped to PULS canonical data classes without running a connector import.              |
| PR14.11  | Connector preflight execution        | Setup, mapping, namespace, identity, and credential-boundary readiness can be validated as a dry run with no runtime sync or ERP writes. |
| PR14.12  | Source credential boundary           | Credential readiness is represented with source-independent auth mode and state metadata without capturing secrets or enabling runtime.  |
| PR14.12B | Connector state consistency findings | Dashboard, `/erp`, duplicate setup, and persisted preflight truth are aligned.                                                           |
| PR14.13  | Connector lifecycle capabilities     | Source lifecycle, capability, and domain ownership posture are visible without runtime execution.                                        |
| PR14.14  | Connector credential handoff         | Admins can request secure reference preparation without collecting or configuring secrets.                                               |
| PR14.15  | Connector activity timeline          | Setup actions leave safe, durable activity history.                                                                                      |
| PR14.16  | Connector import preview dry-run     | Prepared dry-run batches can be validated and classified without apply/import execution.                                                 |
| PR14.17  | Connector apply readiness boundary   | Preview results can be marked ready for human review while canonical apply remains closed.                                               |
| PR14.18  | Controlled apply design              | Future apply execution gates are visible before any canonical write path is exposed.                                                     |
| PR14.19  | Connector apply approval policy      | MVP admin-only approval is explicit and auditable while canonical apply remains closed.                                                  |

## PR14.8 - Connector Setup Persistence

### Business Value

PR14.8 makes the first real setup action durable. A customer admin can start with an empty tenant, choose a supported source, leave the page, return later, and see the same setup state. This turns `/erp` from a guided preview into the beginning of a real onboarding workflow while keeping runtime integration closed.

### Scope

| Area             | PR14.8 behavior                                                                                                                                                |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Data model       | Extend `puls_integration.erp_connections` with lifecycle fields needed for draft/setup state.                                                                  |
| Provider choices | Canias and CSV / Excel can create setup records. Logo and Custom API remain visible future-ready choices unless implementation cost is low and safe.           |
| Lifecycle        | Use production-grade status values such as `draft`, `setup_in_progress`, `mapping_ready`, `preflight_ready`, `connected`, `disabled`, `archived`, and `error`. |
| Enabled state    | A connection can be enabled or disabled without deleting setup history.                                                                                        |
| Domain ownership | Prepare for domain-level source ownership so employees, departments, expenses, and other domains can come from different systems later.                        |
| Admin UX         | Admin starts setup from `/erp`, sees the wizard change state immediately, and the state survives refresh.                                                      |
| Manager UX       | Manager can view connector posture read-only and sees a friendly admin-required notice for mutation actions.                                                   |
| Employee UX      | Employee remains blocked from setup routes.                                                                                                                    |
| Dashboard UX     | Empty tenant dashboard changes from no source to setup draft / setup in progress when a connector setup exists.                                                |
| Tests            | Connector-admin e2e starts a deterministic draft, refreshes, and proves persistence. Employee and manager role boundaries stay covered.                        |

### Out Of Scope

- Credentials or secret capture
- Live Canias API calls
- CSV file upload execution
- Mapping editor
- Import jobs
- ERP writes
- Notification Center
- Separate audit event table

### Acceptance Criteria

- Empty PULS Connector Lab admin can start a Canias setup draft from `/erp`.
- The setup draft is persisted in `puls_integration.erp_connections`.
- Refreshing `/erp` keeps the selected provider and setup step.
- `/dashboard` shows setup in progress instead of source missing for the same tenant.
- Manager can inspect setup state but cannot change it.
- Employee cannot access setup routes.
- Puls Teknik seeded Canias metadata is not overwritten by PULS Connector Lab e2e.
- Verify script and e2e prove no migrations outside the intended connector persistence migration and no seed CSV / manifest changes.

## PR14.9 - Error Observability And Sentry

### Business Value

Connector setup introduces real user actions and future external system boundaries. Before mapping and dry-run validation expand the surface area, PULS needs reliable error capture and user-friendly recovery. PR14.9 makes failures visible to the team without leaking secrets or technical internals to the user.

### Scope

| Area                     | PR14.9 behavior                                                                        |
| ------------------------ | -------------------------------------------------------------------------------------- |
| Frontend errors          | Route-level and action-level errors are captured with tenant, route, and safe context. |
| Backend-visible failures | Server/action failures are captured when the runtime boundary supports it.             |
| User copy                | Product UI shows clear recovery states instead of stack traces or raw provider errors. |
| Scrubbing                | Emails, tokens, passwords, API keys, and connector secrets are not sent in telemetry.  |
| Connector setup          | `/erp` setup actions report failures with retry or contact-admin recovery language.    |
| Docs                     | Observability policy documents what can and cannot be logged.                          |

### Acceptance Criteria

- Setup action failures are captured by the observability boundary.
- User-facing error states are short, actionable, and non-technical.
- Sensitive fields are scrubbed or never attached.
- Tests cover at least one setup action failure path.
- No connector credentials are collected or logged.

## PR14.10 - Mapping Discovery

### Business Value

PULS becomes useful across many data sources only when external fields can be connected to the canonical model. PR14.10 starts the mapping product without running imports. It lets the user understand what a source can provide and how it will land in PULS.

### Scope

| Area                  | PR14.10 behavior                                                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Canonical classes     | Show supported canonical data classes such as employees, departments, positions, cost centers, locations, and future domain classes. |
| Canias discovery      | Use known metadata/manual field declaration first; do not require live API discovery in this PR.                                     |
| CSV / Excel discovery | Support header/sample discovery only if file handling is safe and scoped; otherwise document as next PR.                             |
| Mapping draft         | Persist source field to canonical field mappings as draft metadata.                                                                  |
| Required fields       | Show completeness for required canonical fields.                                                                                     |
| Domain ownership      | Make clear which source owns which canonical domain.                                                                                 |
| Validation            | Validate mapping shape and required fields without executing import.                                                                 |

### Acceptance Criteria

- Admin can see canonical data classes for a selected connector setup.
- At least one source can create or display draft field mappings.
- Required-field completeness is visible.
- Mapping state persists across refresh.
- No import job runs.
- No external connector API call is required.

## PR14.11 - Connector Preflight Execution

### Business Value

Before runtime sync exists, PULS needs a trustworthy dry-run gate. PR14.11 validates whether a connector setup is ready to run later without actually moving data. This is the last safety layer before future connector runtime work.

### Scope

| Area              | PR14.11 behavior                                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Dry-run preflight | Validate provider metadata, lifecycle state, mapping completeness, namespace readiness, identity strategy, and credential-boundary posture. |
| No runtime sync   | Preflight does not import, export, sync, or write to ERP.                                                                                   |
| Result model      | Display deterministic preflight result state with clear pass, warning, and blocked outcomes.                                                |
| Recovery          | Show which setup step needs attention.                                                                                                      |
| Role boundary     | Admin can run preflight. Manager can inspect results. Employee cannot access setup.                                                         |
| Audit posture     | Preflight result metadata is safe to display and does not include secrets.                                                                  |

### Acceptance Criteria

- Admin can run a dry-run preflight for a setup draft.
- Preflight produces actionable pass/warning/blocked results.
- Results survive refresh by being recomputed from the persisted setup, mapping, namespace, and identity state.
- Manager can inspect results read-only.
- No import, export, sync, or ERP write occurs.
- Tests prove preflight does not mutate seeded Puls Teknik data unexpectedly.

## Credential Boundary

PR14.12 makes this boundary concrete. Credentials are required for real connectors eventually, but they are not product metadata. Future credential capture must follow this boundary:

| Rule                               | Meaning                                                                                                    |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| No plaintext secrets in app tables | API keys, passwords, FTP credentials, OAuth secrets, and tokens must not live in ordinary product tables.  |
| Reference-only metadata            | Product tables may store a safe reference such as a configured / missing state or future secret reference. |
| No readback                        | UI must never display the secret value after it is saved.                                                  |
| Scrub telemetry                    | Observability must remove credential-like fields before capture.                                           |
| Runtime-owned access               | Connector runtime should resolve secrets through a controlled server-side boundary, not client-side code.  |

## PR14.12 - Source Credential Boundary

### Business Value

PULS cannot become a source-independent connectivity product if credential readiness is hidden behind a Canias-specific assumption. PR14.12 introduces generic credential posture so Canias, CSV / Excel, Logo, Custom API, SFTP, and future sources can all report whether live connection is safe to consider without exposing secrets.

### Scope

| Area                | PR14.12 behavior                                                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Data model          | Add `auth_mode`, `credential_required`, `credential_state`, verification timestamps, and safe error code metadata to `puls_integration.erp_connections`. |
| Source independence | Backfill by `connection_method`, not by provider-specific logic.                                                                                         |
| Adapter             | Read safe credential posture fields and never select `credentials_ref`.                                                                                  |
| UI                  | Show credential boundary state on `/erp` without a password, API key, token, FTP, OAuth, or connection string input.                                     |
| Preflight           | Treat missing/configured-but-unverified credentials as warning/partial, not ready.                                                                       |
| CSV / Excel         | Support a no-credential path with `not_required`.                                                                                                        |

### Out Of Scope

- Secret capture form
- Secret manager integration
- Credential readback
- Live API credential verification
- Runtime sync/import/export
- ERP or source-system writes

### Acceptance Criteria

- Canias remains a source profile, not the credential architecture.
- `credentials_ref` remains an opaque server-side reference.
- REST/API-like setup with missing credentials shows partial/warning posture.
- Manual import setup can show credentials not required.
- Tests prove `credentials_ref` does not leak into adapter output.
- Verify script blocks `select('*')`, credential inputs, and runtime enablement patterns.

## PR14.12B - Connector State Consistency Findings

### Business Value

PR14.12B makes the connector setup backbone truthful across dashboard, `/erp`, and stored setup history. A setup with missing credentials must not be shown as clean. A duplicate source must not silently own the same canonical domains. A setup check must leave a durable, non-runtime record.

### Scope

| Area              | PR14.12B behavior                                                                                                               |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Dashboard         | ERP card uses credential-aware connector truth and no longer says clean when secure credential reference is missing.            |
| Current connector | Adapter picks the strongest non-archived connector row instead of whichever row was updated last.                               |
| Domain ownership  | Starting setup resumes the existing provider/domain setup or blocks a conflicting source from owning the same canonical domain. |
| Setup history     | Admin-run dry-run preflight writes a safe `setup_preflight` metadata row.                                                       |
| Seed posture      | Seeded inactive REST/API connectors with missing credentials start at `mapping_ready`, not `preflight_ready`.                   |

### Out Of Scope

- Live connector runtime
- Credential capture or secret storage
- Credential verification
- Import/export execution
- ERP writes or destructive source-system actions

### Acceptance Criteria

- `preflight_ready` means all dry-run setup checks are clean.
- Missing credentials keep setup in warning/partial posture.
- Dashboard and `/erp` show the same connector truth.
- Duplicate provider/domain setup is resumed or blocked instead of duplicated.
- Setup check history is persisted without moving data.

## Domain-Level Source Ownership

The product must support distributed customer systems. A single tenant-level primary connector is too narrow. PR14.8 should prepare the model for domain-level source ownership:

| Domain example   | Possible source                     |
| ---------------- | ----------------------------------- |
| Employees        | Canias                              |
| Departments      | Canias                              |
| Positions        | Canias                              |
| Cost centers     | Canias or CSV                       |
| Expense records  | Future accounting connector         |
| Training records | CSV / Excel or future LMS connector |

This keeps existing data flows from being overwritten when a new connector is added.

## PR14.13 - Connector Lifecycle Capabilities

### Business Value

PR14.13 turns connector setup from a provider-specific readiness surface into a source-independent lifecycle workbench. A tenant can see where a source stands, which capabilities are open or closed, and which canonical data domains are owned before any runtime connector exists.

### Scope

| Area                 | PR14.13 behavior                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Lifecycle            | Adapter derives the current lifecycle stage from setup status, mapping, namespace, credential, and preflight state.            |
| Capabilities         | UI exposes source capabilities without enabling live API calls, import/export execution, credential capture, or ERP writeback. |
| Domain ownership     | Canonical classes show whether they are owned by the current source, another source, or still available.                       |
| Responsive workbench | `/erp` setup steps and metric blocks wrap cleanly across narrow, tablet, and desktop viewports.                                |

### Out Of Scope

- Database migration
- Credential capture or secret storage
- Runtime connector execution
- Import/export execution
- Domain ownership transfer
- ERP writes

### Acceptance Criteria

- `ErpOverview` includes `lifecycle`, `capabilities`, and `domainOwnership`.
- Canias is treated as one source profile, not the architecture.
- CSV / Excel can express a different capability posture without secret requirements.
- `/erp` does not render raw lifecycle enum values.
- `/erp` avoids accidental page-level horizontal overflow while preserving dense connector context.

## PR14.14 - Connector Credential Handoff

### Business Value

PR14.14 gives the connector setup backbone a truthful next step when a source requires credentials. The product can say "a secure reference is needed" and let an admin request that handoff without pretending to collect API secrets or enabling runtime connector execution.

### Scope

| Area                | PR14.14 behavior                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| Safe state          | Adds `credential_handoff_status` and safe timestamps to connector setup rows.                          |
| Admin action        | Admin can request secure reference handoff after mapping, namespace, and identity readiness are clear. |
| UX                  | `/erp` explains the write-only secure capture boundary and shows the request state.                    |
| History             | A safe `credential_handoff` setup history record is written.                                           |
| Source independence | Canias remains one source profile; the model works for API, SFTP, file, and future providers.          |

### Out Of Scope

- Secret capture form
- Secret manager integration
- Credential readback
- Live credential verification
- Runtime connector execution
- Import/export execution
- ERP writes

### Acceptance Criteria

- PR14.14 models credential handoff, not credential capture.
- Secure credential capture is write-only and server-side in future runtime.
- `credentials_ref` remains an opaque server-side reference.
- No API keys, passwords, tokens, connection strings, or FTP credentials are collected in the product UI.
- Handoff cannot be requested before mapping and identity readiness are clear.
- The admin handoff action never sets `credential_state` to `configured` or `verified`.

## PR14.15 - Connector Activity Timeline

### Business Value

PR14.15 gives the connector setup backbone a durable, human-readable activity timeline before runtime connectors exist. A product admin can understand which setup action happened, whether it produced a safe warning/error, and what should happen next without reading raw database rows or provider errors.

### Scope

| Area                | PR14.15 behavior                                                                                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Setup history       | Extends existing `erp_sync_batches` records with event keys, actor, safe error code, safe context, and next-action key. |
| UI                  | `/erp` shows activity timeline rows for setup start, mapping contract, preflight, and credential handoff.               |
| Safe details        | Error context is sanitized into counters, product status codes, and check ids.                                          |
| Source independence | Canias is treated as one source profile; activity timeline is connector-agnostic.                                       |
| Runtime boundary    | No live API calls, import/export execution, credential capture, sync execution, or ERP writeback is enabled.            |

### Out Of Scope

- Runtime connector execution
- Provider-specific API error parsing
- Credential capture or secret storage
- Notification Center delivery
- Import/export execution
- ERP writes

### Acceptance Criteria

- `ErpOverview` includes `activityTimeline`.
- Setup start writes a `setup_lifecycle` history row.
- Preflight writes safe warning/blocker detail without raw provider payloads.
- Credential handoff writes safe history without configuring credentials.
- `/erp` renders safe detail and next action for each activity row.

## PR14.16 - Connector Import Preview Dry Run

### Business Value

PR14.16 lets PULS show what a prepared connector batch would do before any import execution exists. This is the bridge between setup readiness and future canonical apply: admins can review create, update, and skip outcomes while runtime, credentials, sync, and ERP writeback remain closed.

### Scope

| Area                    | PR14.16 behavior                                                                                                                                                |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Import preview metadata | Adds safe row-level `preview_action`, `preview_skip_code`, and `previewed_at` metadata to import records.                                                       |
| Dry-run RPC             | `preview_import_diff` persists safe preview classification only for dry-run batches.                                                                            |
| Safe read boundary      | `list_connector_import_preview_records` returns row number, entity type, external id, status, warning/error codes, canonical id, preview action, and skip code. |
| Adapter                 | `ErpOverview.importPreview` exposes batch state, summary counters, and safe records.                                                                            |
| Admin action            | `runConnectorImportPreview` runs validation and preview classification, then writes a safe `import_preview` activity record.                                    |
| Proof SQL               | Creates a pending dry-run proof batch for connector preview testing without validating, previewing, or applying it automatically.                               |

### Out Of Scope

- Live connector runtime
- Credential capture or credential verification
- Provider API calls
- Import apply execution
- Canonical data writes
- ERP or source-system writeback
- Rollback/retry orchestration

### Acceptance Criteria

- PR14.16 adds connector import preview dry-run, not import apply.
- Canias is one source profile; import preview is connector-agnostic.
- Preview classifies create, update, and skip outcomes without writing canonical records.
- Payload readback is forbidden in product UI and adapter output.
- The product action never calls `apply_import_batch`.
- Successful and blocked preview attempts leave safe activity records.

## PR14.17 - Connector Apply Readiness Boundary

### Business Value

PR14.17 gives the product a truthful bridge between dry-run preview and future canonical apply. Admins can record that preview results need human review without implying import approval, connector runtime, or canonical writes are available.

### Scope

| Area                | PR14.17 behavior                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Apply readiness     | Adapter derives review posture from source setup, preview state, row findings, credential posture, and existing review events. |
| Human review        | Admin can record a safe `import_apply_review` activity event for a clean preview.                                              |
| UI                  | `/erp` shows review status, blockers, checks, and the hard execution boundary.                                                 |
| Audit history       | Review intent is stored as metadata in `erp_sync_batches`; raw payloads and credentials remain hidden.                         |
| Source independence | Canias is one source profile; review readiness works for CSV / Excel and future connectors once they produce preview batches.  |

### Out Of Scope

- Canonical import apply
- `apply_import_batch` calls from app code
- Runtime connector execution
- Credential capture or verification
- ERP or external source writeback
- Rollback/retry orchestration

### Acceptance Criteria

- PR14.17 defines apply readiness and human review boundary, not canonical import apply.
- `safeToApply` remains false in PR14.17.
- Human review records are audit signals, not ERP or canonical write approvals.
- Admin can record review intent only after preview is ready.
- Non-admin users cannot record review intent.
- No payload readback, credential readback, runtime sync, or apply execution is opened.

## PR14.18 - Controlled Apply Design

### Business Value

PR14.18 makes the future apply path understandable before it becomes executable. Admins can see which production gates are required after preview and human review: source checksum, approval policy, batch lock, rollback strategy, audit trail, notification plan, runtime credential boundary, and the hard execution boundary.

### Scope

| Area                    | PR14.18 behavior                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Controlled apply plan   | Adapter derives gate-level readiness from source setup, preview, human review, and credential posture.                   |
| UI                      | `/erp` shows the controlled apply plan as a read-only decision model with no apply CTA.                                  |
| Source independence     | Gates describe PULS connectivity behavior, not Canias-specific runtime behavior.                                         |
| Execution boundary      | `executionOpen` and `applyRpcExposed` remain false.                                                                      |
| Safety documentation    | Product docs define approval, idempotency, locking, rollback, audit, notification, and credential-runtime requirements. |

### Out Of Scope

- Canonical import apply
- Runtime connector execution
- Credential capture, credential readback, or secret storage
- ERP or external source writeback
- Rollback execution
- Background job orchestration

### Acceptance Criteria

- PR14.18 defines controlled apply execution design, not canonical import apply.
- `controlledApplyPlan.executionOpen` remains false.
- `controlledApplyPlan.applyRpcExposed` remains false.
- No product UI action calls `apply_import_batch`.
- Controlled apply gates are source-independent and visible in `/erp`.
- Tests prove clean preview and review-requested states still keep execution closed.

## PR14.19 - Connector Apply Approval Policy

### Business Value

PR14.19 makes the MVP approval authority explicit before any apply runtime exists. Admin approval is represented as a source-independent product policy and recorded as an audit event, not as canonical import apply.

### Scope

| Area                | PR14.19 behavior                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Approval policy     | Adapter exposes `applyApprovalPolicy` with admin-only MVP policy, requestable state, recorded state, and `safeToApply: false`. |
| Admin audit action  | Admin can record approval only after preview is clean and human review is recorded.                                            |
| Controlled gates    | `approval_policy` gate becomes ready when the admin-only policy is defined or approval is recorded.                            |
| Activity history    | Approval writes safe `import_apply_approval_recorded` history with counters and no payload or credential detail.               |
| UI                  | `/erp` shows the approval policy card inside controlled apply without opening apply execution.                                 |

### Out Of Scope

- Canonical import apply
- Runtime connector execution
- Credential capture or readback
- ERP or external source writeback
- Batch lock implementation
- Rollback execution
- Notification delivery

### Acceptance Criteria

- PR14.19 defines admin approval policy, not canonical import apply.
- Admin-only approval is explicit product state, not hidden copy.
- Approval can be recorded only after human review audit exists.
- Approval creates a safe activity event.
- Non-admin users cannot record approval.
- `applyApprovalPolicy.safeToApply` remains false.
- No product UI action calls `apply_import_batch`.
- `controlledApplyPlan.executionOpen` and `controlledApplyPlan.applyRpcExposed` remain false.

## Roadmap Stop Condition

After PR14.19, PULS should be able to say:

- A tenant can start connector setup from an empty product state.
- Connector setup state is persisted and role-scoped.
- Errors are observable and user-friendly.
- External fields can be mapped to canonical PULS fields.
- Preflight can validate readiness without running sync.
- Connector setup activities leave safe, durable history records.
- Prepared dry-run import batches can be previewed safely before any apply/runtime work.
- Preview results can be marked ready for human review while canonical apply remains closed.
- Controlled apply gates are visible before any canonical write path is exposed.
- MVP admin-only approval is explicit and auditable while canonical apply remains closed.
- Runtime connector execution remains a separate future phase.

## Handoff After PR14.19

Future work can then move into runtime connector design with safer foundations:

- Connector credential capture and secret storage
- CSV / Excel import execution
- Canias API connector runtime
- Background job orchestration
- Notification Center
- Controlled import apply / rollback strategy
