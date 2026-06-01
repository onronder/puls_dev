# PR14.4 — Tenant Rollout Readiness

PR14.4 closes the current connector onboarding slice with a tenant-level rollout gate. It does not add runtime behavior; it records which tenants prove which product posture before remote promotion.

## Product Claim

Puls Teknik A.S. proves seeded connector metadata posture.

PULS Connector Lab proves no-connector onboarding posture.

connector-admin@puls.demo must remain public-tenant linked only.

No runtime sync, no credentials, and no ERP writes are introduced in this rollout readiness gate.

## Tenant Postures

| Tenant | Purpose | Required proof |
|--------|---------|----------------|
| Puls Teknik A.S. | Seeded PR13 proof tenant with inactive connector metadata | Canias metadata, mapping counts, namespace, identity map, scenario data, auth persona proof |
| PULS Connector Lab | New-customer empty connector tenant | No `erp_connections` row, no employee link, `/dashboard` and `/erp` still return `source: real` with honest empty state |
| Existing remote tenants | Safety control | Must remain untouched by seed/reset/proof scripts |

The two proof tenants are complementary. Puls Teknik proves the seeded customer-demo path. PULS Connector Lab proves a real new tenant can start with no provider selected and no hidden demo fallback.

## Auth Boundary

Puls Teknik persona proof remains mandatory before treating the seeded product path as ready:

- `admin_user_id`
- `hr_admin_user_id`
- `manager_user_id`
- `employee_user_id`
- optional `incomplete_setup_user_id`

PULS Connector Lab intentionally uses connector admin access without a `puls_core.employees.user_id` link. The expected bridge is `public.user_tenants` / `public.user_roles` only, so the tenant can access setup and connector onboarding without pretending there is seeded HR master data.

## Remote Rollout Order

1. Confirm local Supabase schema exposure and app smoke.
2. Confirm remote `Puls Teknik A.S.` seed, scenario, calc, connector metadata, and auth proof.
3. Create or verify remote `PULS Connector Lab` as a separate tenant with no connector metadata.
4. Link `connector-admin@puls.demo` to `PULS Connector Lab` through the public tenant bridge only.
5. Run smoke with `VITE_PULS_DEMO_MODE=false`.
6. Capture `/dashboard` and `/erp` results before enabling any future connector setup write path.

## Smoke Matrix

| User / tenant | Route | Expected visible result |
|---------------|-------|-------------------------|
| Puls Teknik linked admin | `/dashboard` | `source: real`; connector card reflects seeded inactive provider posture |
| Puls Teknik linked admin | `/erp` | `source: real`; selected connector preflight and `Taslağı incele` provider draft behavior remain available |
| connector-admin@puls.demo | `/dashboard` | `source: real`; ERP status shows `Kaynak yok`; no Canias fallback |
| connector-admin@puls.demo | `/erp` | `source: real`; no-connector onboarding appears; provider selection is local preview only |

## Manual SQL Proof Snippets

Run these only against the intended development database. Do not paste connection strings, passwords, service-role keys, or raw auth tokens into docs or PR comments.

```sql
-- Tenants and connector posture
SELECT t.id, t.name, COUNT(c.id) AS erp_connection_count
FROM puls_core.tenants t
LEFT JOIN puls_integration.erp_connections c ON c.tenant_id = t.id
WHERE t.name IN ('Puls Teknik A.S.', 'PULS Connector Lab')
GROUP BY t.id, t.name
ORDER BY t.name;
```

```sql
-- Connector Lab public bridge must not imply an employee link.
SELECT
  au.email,
  COUNT(ut.user_id) AS public_tenant_links,
  COUNT(e.user_id) AS employee_links
FROM auth.users au
LEFT JOIN public.user_tenants ut ON ut.user_id = au.id
LEFT JOIN puls_core.employees e ON e.user_id = au.id
WHERE au.email = 'connector-admin@puls.demo'
GROUP BY au.email;
```

```sql
-- No-connector tenant proof.
SELECT COUNT(*) AS connector_count
FROM puls_integration.erp_connections
WHERE tenant_id = '14000000-0000-4000-8000-000000000143';
```

## Acceptance

- The seeded tenant and no-connector tenant both render real data posture with `VITE_PULS_DEMO_MODE=false`.
- The no-connector tenant never falls back to embedded demo fixtures.
- `/dashboard` and `/erp` show the right ERP posture for each tenant.
- Puls Teknik auth persona proof stays mandatory before seed proof is considered complete.
- Connector Lab access remains setup-only and public-bridge-only until real master data exists.
- No migrations, seed CSV/manifest, runtime connector, credential storage, or ERP write path are introduced.
