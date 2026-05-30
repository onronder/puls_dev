# PULS API Contract Pack

PR12 contract-path reference for in-app **supabase-js** mutations (Postgres RPC + table writes). **Not live public HTTP REST.** Read models are appendix-only, not mutation endpoints.

## Start here

1. [`api-contract-consumer-guide.md`](./api-contract-consumer-guide.md) — how to read and use this pack
2. [`pr12-release-checklist.md`](./pr12-release-checklist.md) — artifact inventory, validation commands, signoff

## Contract artifacts

3. [`openapi.yaml`](./openapi.yaml) — OpenAPI draft (17 mutation paths)
4. [`openapi-validation.md`](./openapi-validation.md) — validator rules and known gaps
5. [`openapi-contract-allowlist.json`](./openapi-contract-allowlist.json) — per-operation wiring + request/error allowlists
6. [`openapi-examples.yaml`](./openapi-examples.yaml) — illustrative request/response/error examples
7. [`puls-error-catalog.md`](./puls-error-catalog.md) — PULS and adapter error codes
8. [`12_mutation_contract_smoke_hardening.md`](./12_mutation_contract_smoke_hardening.md) — PR12.3 contract smoke coverage

Source inventory: [`../data/12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md)

## Disclaimer

- **Transport:** supabase-js — not public HTTP REST
- **Mutations:** 17 contract paths under `paths:`; 20 read-model routes under `x-puls-read-models` appendix only
- **No generated clients:** do not treat this as `openapi.json` / HTTP client source
