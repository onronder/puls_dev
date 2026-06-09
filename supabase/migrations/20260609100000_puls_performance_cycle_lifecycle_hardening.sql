-- PR16.10.17: performance cycle lifecycle truth.
-- Keep the product surface honest by enforcing cycle status transitions server-side.

CREATE OR REPLACE FUNCTION puls_performance.enforce_performance_cycle_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_performance
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status::TEXT = 'closed' THEN
      RAISE EXCEPTION 'PULS_PERFORMANCE_CYCLE_TRANSITION_INVALID: new cycles cannot start closed.';
    END IF;
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT (
      (OLD.status::TEXT = 'draft' AND NEW.status::TEXT = 'active') OR
      (OLD.status::TEXT = 'active' AND NEW.status::TEXT = 'closed')
    ) THEN
      RAISE EXCEPTION
        'PULS_PERFORMANCE_CYCLE_TRANSITION_INVALID: performance cycle status transition is not allowed.';
    END IF;
  END IF;

  IF NEW.status::TEXT = 'active' THEN
    IF EXISTS (
      SELECT 1
      FROM puls_performance.performance_cycles existing
      WHERE existing.tenant_id = NEW.tenant_id
        AND existing.status::TEXT = 'active'
        AND existing.id <> NEW.id
    ) THEN
      RAISE EXCEPTION
        'PULS_PERFORMANCE_ACTIVE_CYCLE_EXISTS: tenant already has an active performance cycle.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION puls_performance.enforce_performance_cycle_lifecycle() FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_performance.enforce_performance_cycle_lifecycle() FROM authenticated;

DROP TRIGGER IF EXISTS performance_cycles_lifecycle_guard
  ON puls_performance.performance_cycles;

CREATE TRIGGER performance_cycles_lifecycle_guard
  BEFORE INSERT OR UPDATE ON puls_performance.performance_cycles
  FOR EACH ROW
  EXECUTE FUNCTION puls_performance.enforce_performance_cycle_lifecycle();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM puls_performance.performance_cycles
    WHERE status::TEXT = 'active'
    GROUP BY tenant_id
    HAVING COUNT(*) > 1
  ) THEN
    RAISE NOTICE
      'Skipping unique active performance cycle index because existing tenant data has multiple active cycles.';
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS performance_cycles_one_active_per_tenant_idx
      ON puls_performance.performance_cycles (tenant_id)
      WHERE status = 'active'::puls_performance.performance_cycle_status;
  END IF;
END;
$$;

COMMENT ON FUNCTION puls_performance.enforce_performance_cycle_lifecycle()
  IS 'PR16.10.17: enforces draft->active->closed performance cycle lifecycle and one active cycle per tenant.';
