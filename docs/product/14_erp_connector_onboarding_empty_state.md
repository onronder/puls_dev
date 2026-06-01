# PR14.2 — ERP Connector Onboarding Empty State

PR14.2 adds the missing first state in the ERP connector state machine: a tenant can have no connector configured yet, and that is a real product state rather than a reason to fall back to demo fixtures.

## Product Claim

New customer tenants must be able to start from a no-connector PULS empty state.

The no-connector state is real data posture, not demo fallback.

Provider selection precedes metadata-only and preflight-ready connector states.

No runtime sync, no credentials, and no ERP writes are introduced in PR14.2.

## State Machine

| State | Meaning | PR14.2 behavior |
|-------|---------|-----------------|
| `no_tenant` | Auth context has no tenant | Still treated as empty for adapter fallback rules |
| `no_connector` | Tenant exists but has no `erp_connections` row | Shows onboarding state with provider options and guardrails |
| `connector_selected` | Tenant has connector metadata | Shows PR14.1 preflight, mappings, namespace, identity reconciliation |

## Onboarding Surface

The `/erp` empty state shows provider options without enabling any runtime action:

- Canias: first customer track
- Logo: future provider candidate
- CSV / Excel: file/template-based source path
- Custom API: future customer-specific connection boundary

The page keeps selection/import controls disabled until a future implementation adds a human-confirmed setup flow.

## Acceptance

- A tenant with no connector must return `source: real`, not `source: demo`.
- `/erp` must show "Henüz connector tanımlı değil" / "No connector configured yet" in no-connector state.
- Existing Puls Teknik / Canias preflight state must remain unchanged.
- Disabled actions must stay disabled.
- No migrations, seed CSV/manifest, credentials, connector runtime, or ERP writes are added.
