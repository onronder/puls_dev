# PR14.9 Error Observability And Sentry

PR14.9 makes the connector setup flow observable without opening connector runtime. The product now has durable setup state, admin-only setup actions, and live authenticated e2e coverage. Before mapping discovery, credential references, or dry-run preflight are added, failures must be visible to the team and safe for users.

## What PR14.9 Proves

- Frontend route/render failures are caught by an app-level Sentry boundary.
- Connector setup action failures are captured with safe operation context.
- User-facing errors are short, actionable, and non-technical.
- Sentry is optional and disabled unless `VITE_SENTRY_DSN` is configured.
- Emails, UUIDs, tokens, passwords, API keys, DSNs, auth headers, cookies, and query secrets are scrubbed before telemetry is sent.
- Service skeletons remain health-only; backend Sentry wiring waits for real runtime.

## What PR14.9 Does Not Prove

- No connector mapping editor.
- No connector discovery call.
- No credential capture or secret reference storage.
- No runtime import/export job.
- No ERP write, sync trigger, or destructive operation.
- No LLM gateway runtime.

## Inspect-First Table

| Artifact                                          | Finding                                                                                                      | PR14.9 decision                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `src/lib/data/errors.ts`                          | Existing `DataAdapterError` carries operation/schema/table metadata and hides raw table names from user copy | Reuse this shape for connector setup action failures                        |
| `src/lib/data/result.ts`                          | Adapter meta already distinguishes `real`, `demo`, `empty`, and `error`                                      | Do not change fallback semantics                                            |
| `src/routes/__root.tsx`                           | Root had providers and toaster but no app error fallback                                                     | Add Sentry error boundary with safe recovery copy                           |
| `src/routes/_app/erp.tsx`                         | Setup mutation showed one generic toast                                                                      | Map connector setup errors to safe i18n keys and capture the failure        |
| `src/lib/data/setup/erp.ts`                       | `startConnectorSetup` writes tenant-scoped draft state                                                       | Normalize missing tenant, role, unsupported provider, and permission errors |
| `services/erp-connector` / `services/llm-gateway` | Health-only skeleton services                                                                                | Document Sentry-ready future boundary; no runtime SDK init yet              |
| `.env.example`                                    | Supabase/app env placeholders only                                                                           | Add optional Sentry placeholders without real values                        |

## Observability Contract

Sentry is a support and engineering signal, not a product data store. It may capture operation names, route names, provider ids such as `canias` or `csv_import`, adapter source, error code, schema/table labels, release, and environment.

Sentry must not receive auth emails, raw auth UUIDs, tenant UUIDs, passwords, API keys, tokens, DSNs, service-role keys, cookies, authorization headers, connector credentials, or raw provider payloads.

## User-Facing Error Contract

Users should see what to do next, not the implementation reason. Connector setup errors follow this mapping:

| Internal condition       | User message posture                |
| ------------------------ | ----------------------------------- |
| Missing tenant context   | Complete company setup first        |
| Non-admin persona        | Admin permission required           |
| Unsupported provider     | Continue with Canias or CSV / Excel |
| RLS / permission failure | Try again with admin role           |
| Unknown save failure     | Retry later                         |

## Frontend Sentry Behavior

- `VITE_SENTRY_DSN` empty means no Sentry init.
- `sendDefaultPii` stays false.
- `tracesSampleRate` defaults to `0`.
- `beforeSend` scrubs messages, exception values, breadcrumbs, request URLs, query strings, headers, and user identity.
- Root fallback gives two recovery paths: refresh page or return to dashboard.

## Backend Boundary

PR14.9 does not start backend runtime observability because `erp-connector` and `llm-gateway` are still health-only skeletons. When runtime begins, backend Sentry must use the same principles:

- DSN comes from environment only.
- Service-role keys and connector credentials are never attached.
- Runtime payloads are summarized, not logged raw.
- Connector job ids and safe status classes are preferred over customer data values.

## Acceptance Criteria

- `@sentry/react` is installed and initialized only when configured.
- App route/render errors have a safe fallback.
- `/erp` connector setup failures call the observability boundary.
- Sentry scrubber has unit tests.
- Connector setup error mapping has unit tests.
- `.env.example` contains placeholders only.
- No migrations, seed CSV, manifest, credential storage, connector runtime, or ERP writes are added.

## Handoff To PR14.10

PR14.10 can add mapping discovery with confidence because the product now has a safe error boundary for setup actions. Discovery failures should reuse the same observability helpers and should expose user-facing statuses rather than raw provider errors.
