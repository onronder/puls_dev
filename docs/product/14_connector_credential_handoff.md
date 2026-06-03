# PR14.14 Connector Credential Handoff

PR14.14 models credential handoff, not credential capture.

## Executive Summary

PULS is a source-independent connectivity product. Canias is one source profile; the credential handoff model must also work for Logo, CSV / Excel, SFTP, custom API, and future connectors.

This PR turns "credentials pending" from a passive warning into a safe setup process state. Admins can request the secure reference flow once mapping, namespace, and identity readiness are clear. The product still does not collect or display secret values.

## What This Proves

| Area               | PR14.14 behavior                                                                                                        |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Credential handoff | Tenant-scoped safe handoff state is stored on `puls_integration.erp_connections`.                                       |
| Admin action       | Admins can mark that secure reference handoff has been requested.                                                       |
| Product UX         | `/erp` explains what happens next without asking for an API key, password, token, FTP credential, or connection string. |
| Setup order        | Handoff is blocked until source, mapping, namespace, and identity steps are clear.                                      |
| Audit posture      | The request creates a safe `credential_handoff` setup history record.                                                   |

## What This Does Not Prove

- Secure credential capture form
- Secret manager or Vault integration
- Credential readback
- Live API credential verification
- Runtime connector execution
- Sync, import, export, or ERP writeback

## Boundary Rules

- Secure credential capture is write-only and server-side in future runtime.
- credentials_ref remains an opaque server-side reference.
- No API keys, passwords, tokens, connection strings, or FTP credentials are collected in the product UI.
- No secret values are stored in product tables, setup metadata, logs, route state, adapter output, or Sentry payloads.
- Canias is one source profile; credential handoff is source-independent.

## State Model

| Status                   | Meaning                                                                                      |
| ------------------------ | -------------------------------------------------------------------------------------------- |
| `not_required`           | The source profile does not need a secret reference.                                         |
| `not_started`            | A secret reference will be needed, but setup is not ready or handoff has not been requested. |
| `requested`              | An admin requested the secure reference flow.                                                |
| `reference_pending`      | The product is waiting for the future secure capture boundary to produce a reference.        |
| `ready_for_verification` | A server-side reference exists, but live verification is pending.                            |
| `verified`               | The reference has been verified by a server-side boundary.                                   |
| `failed`                 | Verification failed with a safe error class.                                                 |
| `revoked`                | The reference has been revoked and must be prepared again.                                   |

## Product Flow

1. Admin selects a data source.
2. Mapping and source identity are prepared.
3. `/erp` shows the credential handoff card.
4. Admin opens the secure reference sheet.
5. Product records `credential_handoff_status = requested`.
6. Product writes a safe `credential_handoff` history row.
7. Runtime, credential capture, and verification remain closed for future PRs.

## Acceptance Criteria

- `/erp` never renders secret input fields for API keys, passwords, tokens, FTP credentials, or connection strings.
- Handoff cannot be requested before mapping, namespace, and identity readiness are present.
- The admin action never changes `credential_state` to `configured` or `verified`.
- `credentials_ref` is not selected or returned by the client adapter.
- CSV / Excel can show `not_required`.
- REST/API-like connectors can show `requested` without enabling runtime.
