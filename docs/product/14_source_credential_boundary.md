# PR14.12 Source Credential Boundary

## Executive Summary

PR14.12 defines the source-independent credential boundary for PULS connectors. It does not add a credential form, does not collect secrets, and does not enable connector runtime. It adds durable setup posture so the product can honestly say whether a selected source needs a secure credential reference before live connection.

PR14.12 defines source-independent credential boundary state, not credential capture.

Canias is a source profile, not the credential architecture.

## What This PR Proves

| Area | Proof |
|------|-------|
| Data model | `puls_integration.erp_connections` can represent `auth_mode`, `credential_required`, and `credential_state` for ERP, file, and custom API sources. |
| Adapter | `/erp` reads safe credential posture fields and never selects or exposes `credentials_ref`. |
| UI | `/erp` shows credential readiness as setup state, not as a secret input form. |
| Preflight | A source that needs credentials but has no secure reference is a warning/partial result, not ready. |
| Source independence | Canias, CSV / Excel, and future API sources use the same credential state vocabulary. |
| Insert safety | DB defaults are corrected from `connection_method` when an insert omits explicit credential posture. |

## What This PR Does Not Prove

- No API key, password, FTP secret, OAuth token, bearer token, or connection string is captured.
- No live connector runtime is enabled in PR14.12.
- No import, export, sync, ERP write, or background job runs.
- No customer-specific Canias authentication model is assumed.
- No secret manager integration is implemented yet.

## Credential Boundary Rules

No plaintext connector secrets are stored in product tables.

credentials_ref is an opaque server-side reference, not a secret value.

The client adapter must not select credentials_ref.

The UI must never display a secret value after it is saved.

Telemetry must not include API keys, passwords, tokens, connection strings, FTP secrets, OAuth secrets, or `credentials_ref` values.

Runtime connector code must resolve secrets through a controlled server-side boundary in a future PR.

## Generic State Model

| Field | Purpose |
|-------|---------|
| `auth_mode` | Source-independent authentication mode: none, API key, basic auth, bearer token, OAuth2 client credentials, SFTP password, connection string, or custom secret reference. |
| `credential_required` | Whether live connector runtime needs a secret boundary for this source. |
| `credential_state` | Safe setup posture: not required, missing, configured, verified, failed, or revoked. |
| `credential_last_verified_at` | Future server-side verification timestamp. |
| `credential_last_failed_at` | Future server-side failure timestamp. |
| `credential_error_code` | Safe non-secret error class for user recovery copy. |

## State To Product Behavior

| State | Product meaning | Preflight posture |
|-------|-----------------|-------------------|
| `not_required` | The source can proceed without a credential reference, such as manual CSV / Excel. | Ready |
| `missing` | The source needs a secure reference before live connector runtime. | Partial |
| `configured` | A secure reference exists but has not been server-verified for live use. | Partial |
| `verified` | The future server boundary verified the reference. | Ready |
| `failed` | Verification failed; the secret remains hidden and must be reviewed. | Blocked |
| `revoked` | Access was revoked and must be re-enabled by an admin. | Blocked |

## Provider Examples

| Source profile | Auth posture |
|----------------|--------------|
| Canias | Uses the generic secure reference state until a customer-specific auth method is known. |
| CSV / Excel | Uses `auth_mode=none`, `credential_required=false`, `credential_state=not_required`. |
| Logo | Future source profile that can reuse the same state model. |
| Custom API | Future source profile that can use API key, bearer token, OAuth2, connection string, or another safe reference mode. |

## Acceptance Criteria

- Migration adds source-independent auth and credential state fields.
- Existing connector rows are backfilled by connection method, not by Canias-specific branching.
- `/erp` shows credential boundary state in the setup workbench.
- REST/API-like sources without a secure reference show warning/partial preflight.
- Manual import sources can show credentials not required.
- `src/lib/data/setup/erp.ts` does not select `credentials_ref`.
- No credential input field is introduced.
- No runtime connector execution is introduced.

## Handoff

PR14.12 prepares future credential capture and secret storage, but intentionally stops before that work. The next implementation can design secure server-side secret write/update flows, Sentry scrubbing coverage for credential operations, and runtime verification logs without changing the product claim that PULS is data-source independent.
