-- PR13.9 remote development posture overlay.
-- This keeps the PR13.4 CSV/manifest baseline unchanged and labels only the
-- fixed proof tenant as the remote Puls Teknik A.S. demo tenant.

DO $$
DECLARE
  v_tenant constant uuid := 'a0000001-0001-4001-8001-000000000001';
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.tenants
    WHERE id = v_tenant
  ) THEN
    RAISE EXCEPTION 'PR13.9 remote posture fail: proof tenant % is missing', v_tenant;
  END IF;

  UPDATE puls_core.tenants
  SET
    name = 'Puls Teknik A.S.',
    legal_name = 'Puls Teknik Anonim Sirketi',
    trade_name = 'Puls Teknik',
    updated_at = now()
  WHERE id = v_tenant;

  RAISE NOTICE 'PR13.9 remote posture applied: proof tenant labeled Puls Teknik A.S.';
END $$;
