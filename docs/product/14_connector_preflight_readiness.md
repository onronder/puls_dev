# PR14.1 — Connector Preflight Readiness

PR14.1 moves `/erp` from a Canias-specific readiness surface to a provider-agnostic connector preflight surface. Canias remains the seeded proof provider, but the product boundary is PULS canonical data plus external source mapping.

## Product Claim

Canias is the first provider, not the product abstraction.

PULS connector readiness is provider-agnostic.

Canonical data model and unified namespace are the stable product boundary.

Field mapping and identity reconciliation determine whether an external data source can feed PULS.

No runtime sync, no credentials, and no ERP writes are introduced in PR14.1.

## What This Proves

| Area | PR14.1 behavior |
|------|-----------------|
| Provider metadata | Reads `puls_integration.erp_connections` and formats the provider label without hard-coding unknown providers to Canias |
| Canonical mapping | Shows `target_schema.target_table.target_field` mapped to source provider fields |
| Sensitive fields | Filters sensitive mapping rows out of the product UI |
| Unified namespace | Reads active `source_namespaces` and linked identity-map counts |
| Preflight checks | Surfaces provider metadata, runtime boundary, field mapping, namespace, identity reconciliation, setup readiness, and write guardrail |
| Transfer posture | Shows CSV/file/staging/API modes as readiness posture only |
| Guardrails | Repeats no runtime sync, no credentials, no automatic ERP writes, and human-confirmed boundaries |

## What This Does Not Prove

| Out of scope | Reason |
|--------------|--------|
| Live Canias API calls | Connector runtime is future work |
| Logo or other provider implementation | PR14.1 removes product coupling; it does not add new connectors |
| Credential storage | No vault/secret integration is introduced |
| ERP writeback | PULS remains the workflow/canonical layer; destructive ERP writes stay forbidden |
| Import/apply runtime | The screen is preflight/readiness only |

## Inspect-First Summary

| Artifact | Finding | PR14.1 decision |
|----------|---------|-----------------|
| `src/lib/data/setup/erp.ts` | Real path used demo-owned `DemoErpOverview`; unknown providers mapped to `Canias` | Add product-owned connector overview types and safe provider labels |
| `src/routes/_app/erp.tsx` | UI copy and columns were Canias-specific | Reframe as connector preflight, canonical mapping, namespace, and guardrails |
| `puls_integration.erp_connections` | Seed has inactive Canias metadata row | Keep Canias as current provider metadata, not as product default |
| `puls_integration.erp_field_mappings` | Seed has generic source fields; sensitive flag exists | Show non-sensitive canonical mappings only |
| `puls_integration.source_namespaces` | Seed has `CANIAS` namespace | Present as unified namespace proof |
| `puls_integration.entity_identity_map` | Seed has source-to-canonical identities | Present as identity reconciliation proof |

## Acceptance

- `/erp` must work with `VITE_PULS_DEMO_MODE=false` and `source: real`.
- Unknown provider labels must not collapse to `Canias`.
- The UI must say connector/preflight/canonical/source provider rather than implying Canias-only product design.
- No `src/**` outside the ERP adapter, route, tests, and i18n scope should change.
- No migrations, seed CSV/manifest, credentials, or connector runtime code should change.
