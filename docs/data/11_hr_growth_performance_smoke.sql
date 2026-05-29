-- 11 PR11.5 HR Growth & Performance — executable smoke (single transaction; rolls back)
-- Asserts tenant-scoped reads on performance HR tables and rollback performance cycle insert/update.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_cycle_id UUID;
  v_cycle_name TEXT;
  v_cycle_status TEXT;
  v_cycles_count INTEGER;
  v_templates_count INTEGER;
  v_evaluations_count INTEGER;
  v_career_profiles_count INTEGER;
  v_training_needs_count INTEGER;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'
     OR name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo/staging tenant not found';
    RETURN;
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_cycles_count
  FROM puls_performance.performance_cycles
  WHERE tenant_id = v_tenant_id;

  IF v_cycles_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL performance_cycles: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_templates_count
  FROM puls_performance.competency_templates
  WHERE tenant_id = v_tenant_id;

  IF v_templates_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL competency_templates: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_evaluations_count
  FROM puls_performance.competency_evaluations
  WHERE tenant_id = v_tenant_id;

  IF v_evaluations_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL competency_evaluations: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_career_profiles_count
  FROM puls_performance.career_profiles
  WHERE tenant_id = v_tenant_id;

  IF v_career_profiles_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL career_profiles: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_training_needs_count
  FROM puls_performance.training_needs
  WHERE tenant_id = v_tenant_id;

  IF v_training_needs_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL training_needs: tenant-scoped SELECT failed';
  END IF;

  INSERT INTO puls_performance.performance_cycles (
    tenant_id,
    name,
    starts_at,
    ends_at,
    status
  ) VALUES (
    v_tenant_id,
    'demo_hr_growth_performance_ smoke cycle',
    CURRENT_DATE + 30,
    CURRENT_DATE + 120,
    'draft'
  )
  RETURNING id INTO v_cycle_id;

  UPDATE puls_performance.performance_cycles
  SET
    name = 'demo_hr_growth_performance_ updated cycle',
    status = 'active'
  WHERE tenant_id = v_tenant_id
    AND id = v_cycle_id;

  SELECT name, status
  INTO v_cycle_name, v_cycle_status
  FROM puls_performance.performance_cycles
  WHERE tenant_id = v_tenant_id
    AND id = v_cycle_id;

  IF v_cycle_name IS DISTINCT FROM 'demo_hr_growth_performance_ updated cycle' THEN
    RAISE EXCEPTION 'SMOKE_FAIL performance_cycles update: unexpected name %', v_cycle_name;
  END IF;

  IF v_cycle_status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'SMOKE_FAIL performance_cycles update: expected status active, got %', v_cycle_status;
  END IF;

  RAISE NOTICE 'OK: demo_hr_growth_performance_ smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
