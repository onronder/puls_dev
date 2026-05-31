-- PR13.5 — Performance scenario generation (narrative proof via direct INSERT).
--
-- Delete order (child before parent):
--   1. performance_scores (UUID prefix b0000004-)
--   2. competency_evaluations (UUID prefix b0000004-)
--   3. performance_kpis (external_source = 'pr13_scenario')

\set ON_ERROR_STOP on

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_cycle uuid := 'a0000020-0020-4020-8020-000000000002';
  v_i int;
  v_j int;
  v_emp_id uuid;
  v_tpl_id uuid;
  v_score_id uuid;
  v_eval_id uuid;
  v_kpi_id uuid;
  v_mgr_id uuid;
  v_kpi_score numeric;
  v_comp_score numeric;
  v_overall numeric;
  v_band puls_performance.score_band;
BEGIN
  DELETE FROM puls_performance.performance_scores
  WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%';

  DELETE FROM puls_performance.competency_evaluations
  WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%';

  DELETE FROM puls_performance.performance_kpis
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';

  -- 15 KPIs across employees
  FOR v_i IN 1..15 LOOP
    v_kpi_id := ('b0000004-0004-4004-8004-' || lpad(v_i::text, 12, '0'))::uuid;
    v_emp_id := ('a0000006-0006-4006-8006-' || lpad((v_i * 3)::text, 12, '0'))::uuid;

    INSERT INTO puls_performance.performance_kpis (
      id, tenant_id, employee_id, cycle_id,
      category, name, target_value, actual_value, unit, weight, source, score,
      external_source, external_kpi_id
    ) VALUES (
      v_kpi_id, v_tenant, v_emp_id, v_cycle,
      CASE WHEN v_i % 3 = 0 THEN 'FIN' WHEN v_i % 3 = 1 THEN 'OPS' ELSE 'CUS' END,
      'PR13.5 KPI ' || v_i,
      100, 70 + (v_i % 25), 'percent', 1, 'manual', 65 + (v_i % 30),
      'pr13_scenario', 'KPI-SC-' || lpad(v_i::text, 4, '0')
    );
  END LOOP;

  -- 45 competency evaluations (manager + self mix)
  FOR v_i IN 1..45 LOOP
    v_eval_id := ('b0000004-0004-4004-8004-' || lpad((100000 + v_i)::text, 12, '0'))::uuid;
    v_emp_id := ('a0000006-0006-4006-8006-' || lpad((10 + v_i)::text, 12, '0'))::uuid;
    v_tpl_id := ('a0000021-0021-4021-8021-' || lpad(((v_i - 1) % 10 + 1)::text, 12, '0'))::uuid;

    SELECT rl.manager_employee_id INTO v_mgr_id
    FROM puls_core.employee_reporting_lines rl
    WHERE rl.tenant_id = v_tenant
      AND rl.employee_id = v_emp_id
      AND rl.relationship_type = 'primary_manager'
      AND rl.is_active = TRUE
    LIMIT 1;

    INSERT INTO puls_performance.competency_evaluations (
      id, tenant_id, employee_id, cycle_id, competency_template_id,
      evaluator_employee_id, score, comment, status, submitted_at
    ) VALUES (
      v_eval_id, v_tenant, v_emp_id, v_cycle, v_tpl_id,
      CASE WHEN v_i % 3 = 0 THEN v_emp_id ELSE v_mgr_id END,
      2.5 + (v_i % 3) * 0.5,
      'PR13.5 scenario evaluation ' || v_i,
      CASE WHEN v_i % 5 = 0 THEN 'draft'::puls_performance.evaluation_status ELSE 'submitted'::puls_performance.evaluation_status END,
      CASE WHEN v_i % 5 <> 0 THEN NOW() - INTERVAL '5 days' ELSE NULL END
    );
  END LOOP;

  -- 45 performance scores (unique employee per score)
  FOR v_i IN 1..45 LOOP
    v_score_id := ('b0000004-0004-4004-8004-' || lpad((200000 + v_i)::text, 12, '0'))::uuid;
    v_emp_id := ('a0000006-0006-4006-8006-' || lpad((v_i + 10)::text, 12, '0'))::uuid;

    v_kpi_score := 55 + (v_i % 40);
    v_comp_score := 50 + ((v_i * 7) % 45);
    v_overall := ROUND(v_kpi_score * 0.7 + v_comp_score * 0.3, 2);
    v_band := CASE
      WHEN v_overall >= 90 THEN 'very_good'::puls_performance.score_band
      WHEN v_overall >= 75 THEN 'good'::puls_performance.score_band
      WHEN v_overall >= 60 THEN 'expected'::puls_performance.score_band
      WHEN v_overall >= 40 THEN 'development'::puls_performance.score_band
      ELSE 'risk'::puls_performance.score_band
    END;

    INSERT INTO puls_performance.performance_scores (
      id, tenant_id, employee_id, cycle_id,
      kpi_score, competency_score, overall_score, status_band
    ) VALUES (
      v_score_id, v_tenant, v_emp_id, v_cycle,
      v_kpi_score, v_comp_score, v_overall, v_band
    )
    ON CONFLICT (tenant_id, employee_id, cycle_id) DO UPDATE SET
      kpi_score = EXCLUDED.kpi_score,
      competency_score = EXCLUDED.competency_score,
      overall_score = EXCLUDED.overall_score,
      status_band = EXCLUDED.status_band,
      updated_at = NOW();
  END LOOP;

  RAISE NOTICE 'OK: PR13.5 performance scenarios (kpis=%, evals=%, scores=%)',
    (SELECT count(*) FROM puls_performance.performance_kpis WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario'),
    (SELECT count(*) FROM puls_performance.competency_evaluations WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%'),
    (SELECT count(*) FROM puls_performance.performance_scores WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%');
END $$;
