# PR13.10 — V1 Packaging Closeout

PR13.10 closes the PR13 packaging track. It does not claim that every PULS surface is production-complete; it records the honest V1 demo posture after local proof, remote proof, auth proof, and demo-off route smoke.

## What PR13 Proves

- PR13.4 baseline seed loads deterministic tenant-scoped company data.
- PR13.5 scenario proof adds workflow, approval, performance, lifecycle narrative, and packaging validation rows.
- PR13.6 proves AI Coach DB context readiness, not live LLM chat.
- PR13.7 defines Canias connector discovery and AI action boundaries, not runtime integration.
- PR13.8 proves the full stack locally with mandatory auth/JWT smoke.
- PR13.9 proves the same stack remotely for the Puls Teknik A.S. proof tenant with mandatory auth/JWT smoke.
- PR13.10 records route-level readiness with `VITE_PULS_DEMO_MODE=false`.

## What PR13 Does Not Prove

- Every screen is production complete.
- Canias integration is implemented.
- AI Coach is live.
- ERP writes, sync jobs, connector deployment, or Railway runtime are ready.
- Real customer Canias field mappings are known.
- SDK/API/CRM productization is complete.

## Final V1 Demo Claim

PULS V1 has a DB-backed customer-demo packaging proof for the core product route set using the remote Puls Teknik A.S. proof tenant, PR13 seed/scenario scripts, mandatory auth persona proof, and demo mode off.

ERP runtime and live AI remain future work. Partial surfaces are intentionally documented in `13_v1_screen_readiness_truth_table.md`.

## Evidence Chain

| Gate | Evidence |
|------|----------|
| Local SQL/auth proof | `13_local_supabase_packaging_auth_proof_results.md` |
| Remote SQL/auth proof | `13_remote_puls_teknik_tenant_proof_results.md` |
| Route smoke | `13_v1_screen_readiness_truth_table.md` |
| Demo fallback guard | `scripts/check-13-demo-fallback-regression.sh` |
| PR13.10 verify | `scripts/verify-13-demo-off-route-smoke-closeout.sh` |

## Smoke Fixes Applied

The route smoke was not treated as paperwork. It found two app blockers and one copy drift item, all closed in PR13.10:

- Auth persona resolution is `puls_core`-first, so remote `05_link_auth_personas_template.sql` links actually unlock admin/manager UI.
- Setup route guards wait for persona resolution before redirecting direct deep links to `/ayarlar`.
- Legacy setup/settings copy that mentioned demo/Mert Teknik was changed to tenant-neutral read-only copy on the real route path.

## Final Boundaries

### Ready For Customer Demo

- Core dashboard and org views.
- Employee directory and source-aware organization setup.
- Leave and expense overview paths with scenario records.
- Performance overview and parameter surfaces.
- Contract metadata overview.
- Profile with linked auth persona.
- AI Coach context-readiness teaser with guardrails.
- ERP metadata/discovery posture.

### Partial But Honest

- Career and training are representative V1 surfaces, not full talent suite runtime.
- Settings is a hub/read-only posture, not complete enterprise admin.
- ERP is metadata/discovery only.
- AI Coach is context readiness and action boundary only.

### Future

- Job evaluation production module.
- Canias runtime connector, sync, exports, and writeback.
- Live LLM gateway and tool execution.
- SDK/API packaging, CRM integrations, real-time sync.

## PR14 Handoff

PR14 should start from customer discovery and runtime choices, not from more synthetic proof expansion:

- Canias customer data model, export samples, transport mode, and writeback expectation.
- Product decision for live AI use cases and audit boundaries.
- Route-specific production gaps from the truth table.
- Deployment/runtime decisions for Railway and connector services.
