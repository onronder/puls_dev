# PULS API Contract Consumer Guide (PR12.5)

How to read and use the PR12 contract pack without assuming live public REST or generated HTTP clients.

## What this pack is

The PR12 **API contract pack** is a contract-path reference for **current in-app mutations** transported via **supabase-js** (Postgres RPC + table writes).

It is **not live public REST**, not a generated HTTP client source, and not a deployment spec for public endpoints.

It is:

- A boundary inventory → OpenAPI draft → validation → examples → error catalog pipeline
- Honest about transport (`x-puls-public-http: false`)

It is **not**:

- Source for an auto-generated HTTP client against real endpoints
- A promise that internal backend RPCs are app-exposed

Start at [`README.md`](./README.md) for the full artifact index. Release validation commands live in [`pr12-release-checklist.md`](./pr12-release-checklist.md).

## How to read the OpenAPI draft

[`openapi.yaml`](./openapi.yaml) is derived from [`../data/12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md).

| Section | Meaning |
|---------|---------|
| `paths:` | **17 app-exposed mutation contracts only** — these are the write boundaries the app calls today |
| `x-puls-read-models` | Read-model route appendix — **not** mutation endpoints under `paths:` |
| `x-puls-internal-backend-surfaces` | Internal backend RPC/trigger surfaces — **do not** treat as public API |
| `x-puls-not-exposed` | Future or intentionally non-exposed surfaces |

Read models (20 routes, including `/menu` with `shellException: true`) document how the app loads data; they are not POST/PATCH mutation paths.

## Transport model

| Extension / field | Value |
|-------------------|-------|
| Current transport | `supabase-js` (`x-puls-current-transport`) |
| Public HTTP | **false** (`x-puls-public-http: false`) |
| Server URL | `supabase-js://local` — illustrative, not a fetchable HTTP base URL |

Mutations execute through the in-app Supabase client (RPC calls and scoped table writes), not through a standalone REST gateway.

## Auth model

Every mutation operation declares:

- `security: SupabaseJwt` — bearer JWT from Supabase Auth
- `x-puls-auth` — structured auth expectations

Common patterns:

| Requirement | Applies to |
|-------------|------------|
| Tenant context | Most mutations (`requiresTenantContext: true`) |
| Employee context | Workflow RPCs (leave, expense, decide) |
| Admin/setup role | Setup mutations (`requiresAdminOrSetupRole: true`) on expense categories, leave types, org CRUD |

Tenant and employee resolution happen in adapters before or inside backend calls — they are **not** client-writable request fields.

## Request schema policy

OpenAPI `*Request` schemas list **client-writable fields only**.

Adapter-set fields must never appear in request examples or client payloads:

- `tenant_id` / `tenantId`
- `is_active` / `isActive`
- `external_source` / `externalSource`
- `created_at`, `updated_at`, and camelCase variants

The authoritative field list per schema is in [`openapi-contract-allowlist.json`](./openapi-contract-allowlist.json) → `requestSchemaAllowlist`. The validator enforces exact property sets in [`openapi-validation.md`](./openapi-validation.md).

## Examples and errors

| Artifact | Use |
|----------|-----|
| [`openapi-examples.yaml`](./openapi-examples.yaml) | Illustrative request / response-or-accepted / error codes per operation |
| [`puls-error-catalog.md`](./puls-error-catalog.md) | PULS and adapter error codes, mapper inventory, i18n posture |

Examples use placeholder UUIDs (e.g. `00000000-0000-0000-0000-000000000101`) — **not** production fixture IDs.

Error examples expose **codes** only; localized user strings live in route/domain i18n files, not in OpenAPI.

## Coverage status

OpenAPI operations may declare `x-puls-coverage`:

| Value | Meaning |
|-------|---------|
| `contract_smoke` | Behavioral success path claimed in linked smoke SQL (`x-puls-coverage-doc`) |
| `partial` | Residual gap documented in `x-puls-follow-up` |

Current posture (PR12.3):

| Operation | Coverage |
|-----------|----------|
| `createPerformanceCycle`, `updatePerformanceCycle` | `contract_smoke` |
| `decideApprovalRequest` | `partial` — JWT + error-path smoke; success path may SKIP without pending approver fixture |

See [`12_mutation_contract_smoke_hardening.md`](./12_mutation_contract_smoke_hardening.md) for smoke details.

## Validation commands

See [`pr12-release-checklist.md`](./pr12-release-checklist.md) for the authoritative validation command map and release signoff checklist.

## What not to do

- **Do not** generate a public HTTP client from this spec as if fetchable REST endpoints exist at a public API base URL.
- **Do not** expose internal RPCs listed under `x-puls-internal-backend-surfaces` as app mutations.
- **Do not** add request fields outside [`openapi-contract-allowlist.json`](./openapi-contract-allowlist.json) without updating the allowlist and validator.
- **Do not** publish `openapi.json` / `swagger.json` generated artifacts as the contract source of truth — the repo YAML + allowlist are authoritative.

## PR13 handoff

Candidate next work (not in scope for PR12):

| Theme | Description |
|-------|-------------|
| PR13.0 | Public transport / API productization decision |
| PR13.1 | CI OpenAPI lint and optional YAML parser dependency |
| PR13.2 | Generated docs site (if desired) |
| PR13.3 | Response parser parity tests (adapter ↔ OpenAPI response schemas) |
| PR13.4 | Auth integration examples and external consumer guide |

See [`pr12-release-checklist.md`](./pr12-release-checklist.md) for the full PR13 handoff map.
