# erp-connector (Canias) — Service Boundary

Health-only skeleton for future Canias ERP connector. **Not used by app runtime in PR13.7.**

## Posture

| Property | Value |
|----------|-------|
| Version | `0.1.0-skeleton` |
| Provider | Canias |
| Runtime | Health endpoint only (`GET` → JSON `{ status: "ok" }`) |
| App integration | None — PULS app reads `puls_integration.*` via Supabase adapters |
| Production deployment | Not expected in PR13.7 |

## What this service is

**erp-connector is a future connector boundary**, not a PR13.7 runtime connector.

Future runtime PR will implement import/export per [`docs/product/13_canias_field_mapping_matrix.json`](../../docs/product/13_canias_field_mapping_matrix.json) with human confirmation gates.

## What this service is not

- Not a live Canias API client
- Not a sync trigger for `/erp`
- Not a credential store
- No secrets, API keys, or tokens in this repo

## Security

- No credentials in repo
- Future: `credentials_ref` in vault/env only
- **No automatic destructive ERP writes**

## Local dev (skeleton only)

```bash
cd services/erp-connector
node --import tsx src/index.ts
# curl http://localhost:8081 → { "service": "erp-connector-canias", "status": "ok", ... }
```

## References

- [`docs/product/13_canias_connector_discovery.md`](../../docs/product/13_canias_connector_discovery.md)
- [`docs/product/13_canias_first_integration_boundary.md`](../../docs/product/13_canias_first_integration_boundary.md)
