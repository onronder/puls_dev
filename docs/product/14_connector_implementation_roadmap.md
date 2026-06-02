# PR14.8-PR14.11 Connector Implementation Roadmap

PR14.8 through PR14.11 turns the connector setup surface from a proven empty-state and preflight UI into a persisted, observable, source-independent setup flow. The goal is not to build a Canias-only product. The goal is to make PULS a canonical HR operations layer that can connect to many external data sources through stable mapping, namespace, identity, and preflight contracts.

## Product Claim

PULS is data-source independent. Canias is the first native ERP connector, not the product abstraction.

Canonical data model, unified source namespaces, and domain-level source ownership are the stable product boundary.

Connector setup persistence comes before connector runtime.

Runtime sync, credential capture, ERP writes, and destructive operations remain closed until the setup, observability, mapping, and preflight contracts are proven.

## Decisions Locked Before PR14.8

| Decision | Product direction |
|----------|-------------------|
| Connector scope | A tenant may use more than one data source when different domains live in different systems. |
| Provider posture | Canias and CSV / Excel are MVP setup candidates; Logo and Custom API can remain future-ready provider cards. |
| Data ownership | Source priority must be domain-based, not a single global tenant switch. |
| Persistence target | Use `puls_integration.erp_connections` lifecycle state instead of a separate setup-draft table. |
| Write access | Admin can create and edit connector setup. Manager can inspect read-only. Employee cannot access setup routes. |
| Credentials | PR14.8 does not collect or store API keys, passwords, FTP secrets, OAuth tokens, or connector credentials. Future credential capture must use a secret boundary and store only a reference in product metadata. |
| Runtime boundary | No live connector calls, no import execution, no sync button, no ERP writes. |
| Testing posture | Live authenticated e2e must prove seeded Puls Teknik and empty PULS Connector Lab behavior by role. |

## Implementation Sequence

| PR | Name | Outcome |
|----|------|---------|
| PR14.8 | Connector setup persistence | Provider selection creates a tenant-scoped setup record, survives refresh, and changes dashboard / ERP posture. |
| PR14.9 | Error observability and Sentry | Frontend and backend-visible setup failures are captured, scrubbed, and shown with user-friendly recovery paths. |
| PR14.10 | Mapping discovery | Source fields can be discovered or declared, then mapped to PULS canonical data classes without running a connector import. |
| PR14.11 | Connector preflight execution | Setup, mapping, namespace, identity, and credential-boundary readiness can be validated as a dry run with no runtime sync or ERP writes. |

## PR14.8 - Connector Setup Persistence

### Business Value

PR14.8 makes the first real setup action durable. A customer admin can start with an empty tenant, choose a supported source, leave the page, return later, and see the same setup state. This turns `/erp` from a guided preview into the beginning of a real onboarding workflow while keeping runtime integration closed.

### Scope

| Area | PR14.8 behavior |
|------|-----------------|
| Data model | Extend `puls_integration.erp_connections` with lifecycle fields needed for draft/setup state. |
| Provider choices | Canias and CSV / Excel can create setup records. Logo and Custom API remain visible future-ready choices unless implementation cost is low and safe. |
| Lifecycle | Use production-grade status values such as `draft`, `setup_in_progress`, `mapping_ready`, `preflight_ready`, `connected`, `disabled`, `archived`, and `error`. |
| Enabled state | A connection can be enabled or disabled without deleting setup history. |
| Domain ownership | Prepare for domain-level source ownership so employees, departments, expenses, and other domains can come from different systems later. |
| Admin UX | Admin starts setup from `/erp`, sees the wizard change state immediately, and the state survives refresh. |
| Manager UX | Manager can view connector posture read-only and sees a friendly admin-required notice for mutation actions. |
| Employee UX | Employee remains blocked from setup routes. |
| Dashboard UX | Empty tenant dashboard changes from no source to setup draft / setup in progress when a connector setup exists. |
| Tests | Connector-admin e2e starts a deterministic draft, refreshes, and proves persistence. Employee and manager role boundaries stay covered. |

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

| Area | PR14.9 behavior |
|------|-----------------|
| Frontend errors | Route-level and action-level errors are captured with tenant, route, and safe context. |
| Backend-visible failures | Server/action failures are captured when the runtime boundary supports it. |
| User copy | Product UI shows clear recovery states instead of stack traces or raw provider errors. |
| Scrubbing | Emails, tokens, passwords, API keys, and connector secrets are not sent in telemetry. |
| Connector setup | `/erp` setup actions report failures with retry or contact-admin recovery language. |
| Docs | Observability policy documents what can and cannot be logged. |

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

| Area | PR14.10 behavior |
|------|------------------|
| Canonical classes | Show supported canonical data classes such as employees, departments, positions, cost centers, locations, and future domain classes. |
| Canias discovery | Use known metadata/manual field declaration first; do not require live API discovery in this PR. |
| CSV / Excel discovery | Support header/sample discovery only if file handling is safe and scoped; otherwise document as next PR. |
| Mapping draft | Persist source field to canonical field mappings as draft metadata. |
| Required fields | Show completeness for required canonical fields. |
| Domain ownership | Make clear which source owns which canonical domain. |
| Validation | Validate mapping shape and required fields without executing import. |

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

| Area | PR14.11 behavior |
|------|------------------|
| Dry-run preflight | Validate provider metadata, lifecycle state, mapping completeness, namespace readiness, identity strategy, and credential-boundary posture. |
| No runtime sync | Preflight does not import, export, sync, or write to ERP. |
| Result model | Persist or display preflight result state with clear pass, warning, and blocked outcomes. |
| Recovery | Show which setup step needs attention. |
| Role boundary | Admin can run preflight. Manager can inspect results. Employee cannot access setup. |
| Audit posture | Preflight result metadata is safe to display and does not include secrets. |

### Acceptance Criteria

- Admin can run a dry-run preflight for a setup draft.
- Preflight produces actionable pass/warning/blocked results.
- Results survive refresh if persistence is in scope for the PR.
- Manager can inspect results read-only.
- No import, export, sync, or ERP write occurs.
- Tests prove preflight does not mutate seeded Puls Teknik data unexpectedly.

## Credential Boundary

Credentials are required for real connectors eventually, but they are not product metadata. Future credential capture must follow this boundary:

| Rule | Meaning |
|------|---------|
| No plaintext secrets in app tables | API keys, passwords, FTP credentials, OAuth secrets, and tokens must not live in ordinary product tables. |
| Reference-only metadata | Product tables may store a safe reference such as a configured / missing state or future secret reference. |
| No readback | UI must never display the secret value after it is saved. |
| Scrub telemetry | Observability must remove credential-like fields before capture. |
| Runtime-owned access | Connector runtime should resolve secrets through a controlled server-side boundary, not client-side code. |

## Domain-Level Source Ownership

The product must support distributed customer systems. A single tenant-level primary connector is too narrow. PR14.8 should prepare the model for domain-level source ownership:

| Domain example | Possible source |
|----------------|-----------------|
| Employees | Canias |
| Departments | Canias |
| Positions | Canias |
| Cost centers | Canias or CSV |
| Expense records | Future accounting connector |
| Training records | CSV / Excel or future LMS connector |

This keeps existing data flows from being overwritten when a new connector is added.

## Roadmap Stop Condition

After PR14.11, PULS should be able to say:

- A tenant can start connector setup from an empty product state.
- Connector setup state is persisted and role-scoped.
- Errors are observable and user-friendly.
- External fields can be mapped to canonical PULS fields.
- Preflight can validate readiness without running sync.
- Runtime connector execution remains a separate future phase.

## Handoff After PR14.11

Future work can then move into runtime connector design with safer foundations:

- Connector credential capture and secret storage
- CSV / Excel import execution
- Canias API connector runtime
- Background job orchestration
- Notification Center
- Connector activity timeline
- Controlled import apply / rollback strategy
