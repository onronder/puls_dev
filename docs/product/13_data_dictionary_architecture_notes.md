# PR13.3A — Data Dictionary Architecture Notes

Why V1 data dictionary **microservice labels** are **future service-boundary hints**, not MVP physical deployment requirements — and how the current **Supabase/Postgres + RLS/RPC/views + `src/lib/data` adapters** architecture remains canonical.

**Documentation-only.** No runtime service split in PR13.3A or PR13.4.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

Data dictionary microservice labels are future service-boundary hints, not MVP deployment requirements.

## Executive summary

[`Puls_Veri_Sozlugu_v1.0.xlsx`](../V1%20Dokümanlar/Puls_Veri_Sozlugu_v1.0.xlsx) decomposes the product into namespaces and aspirational **bounded context** service names (`identity-svc`, `kpi-svc`, `training-svc`, `career-svc`, `erp-connector`, `llm-gateway`, etc.).

**MVP implementation is intentionally modular Supabase/Postgres — not physical microservices.** Adapter modules under `src/lib/data/**` preserve domain separation without distributed deployment overhead.

PR13.4 seed artifacts must follow the data dictionary alignment crosswalk — but seed CSV columns follow **DB object truth**, not dictionary field count.

## Current MVP architecture

| Layer | Role |
|-------|------|
| Supabase/Postgres | Single transactional store, RLS, RPC, views |
| `puls_*` schemas | Domain tables + `puls_calc` derived read models |
| `src/lib/data` adapters | Route-facing data boundary (`resolveAdapterDataWithMeta`) |
| PR12 contract-path OpenAPI | In-app mutation contracts — not live public HTTP yet |

**Architecture decision (JSON crosswalk):** `physicalMicroservicesInMvp: false`; dictionary labels = **`future_service_boundary`**.

Skeleton folders [`services/erp-connector/`](../../services/erp-connector/) and [`services/llm-gateway/`](../../services/llm-gateway/) exist as **health-only placeholders** — **not physical microservices** in packaging proof.

## Why not physical microservices in MVP

| Factor | Rationale |
|--------|-----------|
| Target customer | Turkish SME / mid-market — not enterprise-first distributed HR |
| Correctness first | End-to-end leave/expense/approval flows must work before splitting boundaries |
| Tenant isolation | RLS + single Postgres simpler than cross-service auth propagation |
| Transactional workflows | Leave balance + approval + audit benefit from one DB boundary |
| Canias-first ERP | Import/metadata readiness should not force broad service decomposition |
| Team velocity | Small team; adapter modules give separation without ops overhead |
| Operational cost | Observability, retry, versioning, deployment matrix per service |

## Pros of current architecture

- **Transactional correctness** — approval decisions and balances stay ACID-local
- **RLS and tenant isolation** — packaging proof with `Puls Sanayi A.Ş.` demo tenant
- **Faster iteration** — schema + adapter changes without cross-service contracts
- **Simpler DB-backed demo** — PR13.3–13.5 seed/bootstrap on one platform
- **Adapter boundaries** — domains separated in code (`core/`, `leave/`, `expense/`, `setup/`)
- **PR12 transport openness** — future public API/SDK can wrap existing adapters

## Cons / risks

| Risk | Mitigation |
|------|------------|
| Central DB coupling | Clear schema ownership; calc views; future read replicas if needed |
| Fat SQL/RPC/adapters | PR13.1 inventory + retirement plan; extract hot paths later |
| Async workloads later | Import pipeline, OCR, LLM may need workers — not MVP blockers |
| Public API layer | PR12 contract-path exists; external HTTP is future candidate |
| Service extraction discipline | Decision rule below — no premature split |

## How the data dictionary still helps

| Dictionary artifact | MVP use |
|--------------------|---------|
| Namespaces (`identity`, `tatil`, `cuzdan`, …) | **Bounded context** labels for seed + UX vocabulary |
| Microservice names (`identity-svc`, `kpi-svc`, …) | **Future extraction candidates** — not deploy units today |
| Field vocabulary (494 technical fields) | Business/UI alignment; crosswalk status per domain |
| URL prefixes | Route alias mapping to current `_app` routes |

**Not 1:1:** dictionary fields do not map one-to-one to PR13.4 CSV columns. See [`13_data_dictionary_seed_alignment.md`](./13_data_dictionary_seed_alignment.md).

## Workbook microservice map (reference)

From **Mikroservis Haritası** sheet — labels only:

| Label | Dictionary role | MVP posture |
|-------|-----------------|-------------|
| `identity-svc` | Employee/org identity | Adapters + `puls_core` — **bounded context**, **not physical microservices** |
| `kpi-svc` | KPI targets | Partial / future — **kpi-svc** |
| `performans-svc` | Performance evaluation | `puls_performance` + adapters |
| `training-svc` | Training analysis | `training_needs` — **training-svc** |
| `career-svc` | Career ladder | `career_profiles` — **career-svc** |
| `job-eval-svc` | Job evaluation | Placeholder route — future |
| `position-svc` | Position / job docs | `puls_core.positions` partial |
| `leave-svc` | Leave workflow | RPC + `puls_workflow` |
| `expense-svc` | Expense workflow | RPC + `puls_workflow` |
| `contract-svc` | Contracts | `puls_workflow.contracts` |
| `erp-connector` | Canias integration | Metadata seed only — **Canias connector** is PR13.7 discovery |
| `llm-gateway` | AI Coach | Teaser until PR13.6 — **AI Coach** context only |

## Future service extraction candidates

Extract a **physical microservice** only when there is real operational pressure:

- Scale (throughput / data volume beyond single Postgres)
- Isolation (security/compliance boundary)
- Async workload (OCR, import batches, LLM inference)
- Integration boundary (**Canias connector** write-back / sync worker)
- Independent deployment cadence
- Compliance requirement (audit vault separation)

Candidate extractions (post-MVP):

1. **Canias connector** / import worker
2. **AI Coach** / **llm-gateway** (tenant-scoped context + human-in-the-loop)
3. Import pipeline worker
4. KPI / performance analytics worker
5. Public API gateway / SDK layer

## Decision rule

> Extract service only when there is real operational pressure: scale, isolation, async workload, integration boundary, independent deployment, or compliance requirement.

Until then: **`future_service_boundary`** labels stay in documentation; **`physicalMicroservicesInMvp`** remains **`false`**.

## References

- [`13_data_dictionary_seed_alignment.md`](./13_data_dictionary_seed_alignment.md)
- [`13_data_dictionary_seed_crosswalk.json`](./13_data_dictionary_seed_crosswalk.json)
- [`13_synthetic_company_seed_spec.md`](./13_synthetic_company_seed_spec.md)
- [`13_canias_first_integration_boundary.md`](./13_canias_first_integration_boundary.md)
