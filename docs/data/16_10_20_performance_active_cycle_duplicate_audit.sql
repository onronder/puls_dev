-- PR16.10.20 — read-only performance active-cycle duplicate audit.
-- Purpose: find tenants that already had more than one active performance cycle
-- before the PR16.10.17-19 lifecycle hardening unique index could be created.
-- This query does not mutate data.

WITH duplicate_tenants AS (
  SELECT
    tenant_id,
    COUNT(*) AS active_cycle_count
  FROM puls_performance.performance_cycles
  WHERE status::TEXT = 'active'
  GROUP BY tenant_id
  HAVING COUNT(*) > 1
)
SELECT
  duplicate_tenants.tenant_id,
  tenant.name AS tenant_name,
  duplicate_tenants.active_cycle_count,
  ARRAY_AGG(
    JSONB_BUILD_OBJECT(
      'cycle_id', cycle.id,
      'name', cycle.name,
      'starts_at', cycle.starts_at,
      'ends_at', cycle.ends_at,
      'created_at', cycle.created_at,
      'updated_at', cycle.updated_at
    )
    ORDER BY cycle.starts_at DESC NULLS LAST, cycle.created_at DESC NULLS LAST
  ) AS active_cycles
FROM duplicate_tenants
JOIN puls_performance.performance_cycles cycle
  ON cycle.tenant_id = duplicate_tenants.tenant_id
 AND cycle.status::TEXT = 'active'
LEFT JOIN puls_core.tenants tenant
  ON tenant.id = duplicate_tenants.tenant_id
GROUP BY duplicate_tenants.tenant_id, tenant.name, duplicate_tenants.active_cycle_count
ORDER BY duplicate_tenants.active_cycle_count DESC, tenant.name NULLS LAST;
