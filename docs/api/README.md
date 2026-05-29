# PULS API Contracts

PR12.1 contract-path OpenAPI draft derived from [`12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md).

- **Spec:** [`openapi.yaml`](./openapi.yaml)
- **Validation:** [`openapi-validation.md`](./openapi-validation.md) · [`openapi-contract-allowlist.json`](./openapi-contract-allowlist.json)
- **Transport:** supabase-js (Postgres RPC + table writes), not public HTTP REST
- **Mutations:** 17 contract paths under `paths:`; read models and internal surfaces are appendix-only vendor extensions
