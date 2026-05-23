-- PULS performance, contracts metadata, calculation views (03-db-performance-contracts-summary)
-- puls_performance + puls_workflow contracts + puls_calc security-invoker views + demo seed

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS puls_performance;
CREATE SCHEMA IF NOT EXISTS puls_calc;

-- ---------------------------------------------------------------------------
-- puls_performance enums (duplicate-safe)
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE puls_performance.performance_cycle_status AS ENUM (
    'draft', 'active', 'closed'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_performance.kpi_source AS ENUM (
    'manual', 'erp', 'api', 'calculated'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_performance.evaluation_status AS ENUM (
    'draft', 'pending', 'submitted', 'approved'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_performance.score_band AS ENUM (
    'very_good', 'good', 'expected', 'development', 'risk'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_performance.training_need_status AS ENUM (
    'open', 'recommended', 'planned', 'completed', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- puls_workflow contract enums (duplicate-safe)
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE puls_workflow.contract_status AS ENUM (
    'active', 'expiring', 'ended', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.contract_signature_status AS ENUM (
    'signed', 'awaiting', 'missing', 'not_required'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.contract_risk_band AS ENUM (
    'low', 'medium', 'high'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- puls_performance tables (FK-safe create order)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_performance.performance_cycles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  legacy_public_cycle_id UUID NULL,
  name TEXT NOT NULL,
  status puls_performance.performance_cycle_status NOT NULL DEFAULT 'draft',
  starts_at DATE NOT NULL,
  ends_at DATE NOT NULL,
  scope TEXT NOT NULL DEFAULT 'tenant',
  kpi_frequency TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at >= starts_at),
  UNIQUE (tenant_id, name)
);

CREATE TABLE IF NOT EXISTS puls_performance.competency_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  legacy_public_template_id UUID NULL,
  name TEXT NOT NULL,
  description TEXT NULL,
  weight NUMERIC(8, 2) NOT NULL DEFAULT 1,
  scale_min INTEGER NOT NULL DEFAULT 1,
  scale_max INTEGER NOT NULL DEFAULT 5,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (scale_max >= scale_min),
  CHECK (weight >= 0),
  UNIQUE (tenant_id, name)
);

CREATE TABLE IF NOT EXISTS puls_performance.performance_kpis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  cycle_id UUID NOT NULL REFERENCES puls_performance.performance_cycles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  name TEXT NOT NULL,
  target_value NUMERIC(14, 2) NULL,
  actual_value NUMERIC(14, 2) NULL,
  unit TEXT NOT NULL DEFAULT 'percent',
  weight NUMERIC(8, 2) NOT NULL DEFAULT 1,
  source puls_performance.kpi_source NOT NULL DEFAULT 'manual',
  score NUMERIC(8, 2) NULL,
  external_source TEXT NULL,
  external_kpi_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (weight >= 0),
  CHECK (score IS NULL OR (score >= 0 AND score <= 100))
);

CREATE TABLE IF NOT EXISTS puls_performance.competency_evaluations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  cycle_id UUID NOT NULL REFERENCES puls_performance.performance_cycles(id) ON DELETE CASCADE,
  competency_template_id UUID NOT NULL REFERENCES puls_performance.competency_templates(id) ON DELETE RESTRICT,
  evaluator_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  score NUMERIC(8, 2) NULL,
  comment TEXT NULL,
  status puls_performance.evaluation_status NOT NULL DEFAULT 'draft',
  submitted_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (score IS NULL OR (score >= 0 AND score <= 5))
);

-- performance_overall_v1 = kpi_score * 0.7 + competency_score * 0.3
CREATE TABLE IF NOT EXISTS puls_performance.performance_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  cycle_id UUID NOT NULL REFERENCES puls_performance.performance_cycles(id) ON DELETE CASCADE,
  kpi_score NUMERIC(8, 2) NOT NULL DEFAULT 0,
  competency_score NUMERIC(8, 2) NOT NULL DEFAULT 0,
  overall_score NUMERIC(8, 2) NOT NULL DEFAULT 0,
  status_band puls_performance.score_band NOT NULL DEFAULT 'expected',
  calculation_version TEXT NOT NULL DEFAULT 'performance_overall_v1',
  input_snapshot_at TIMESTAMPTZ NULL,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, employee_id, cycle_id),
  CHECK (kpi_score >= 0 AND kpi_score <= 100),
  CHECK (competency_score >= 0 AND competency_score <= 100),
  CHECK (overall_score >= 0 AND overall_score <= 100)
);

CREATE TABLE IF NOT EXISTS puls_performance.career_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  current_step TEXT NULL,
  target_step TEXT NULL,
  readiness_score NUMERIC(8, 2) NULL,
  missing_competencies JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, employee_id),
  CHECK (readiness_score IS NULL OR (readiness_score >= 0 AND readiness_score <= 100))
);

CREATE TABLE IF NOT EXISTS puls_performance.training_needs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  source_module TEXT NOT NULL DEFAULT 'performance',
  skill_topic TEXT NOT NULL,
  need_level TEXT NOT NULL DEFAULT 'recommended',
  priority INTEGER NOT NULL DEFAULT 3,
  status puls_performance.training_need_status NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (priority >= 1 AND priority <= 5)
);

-- ---------------------------------------------------------------------------
-- puls_workflow contract metadata tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_workflow.contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  contract_type TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NULL,
  status puls_workflow.contract_status NOT NULL DEFAULT 'active',
  signature_status puls_workflow.contract_signature_status NOT NULL DEFAULT 'not_required',
  risk_band puls_workflow.contract_risk_band NOT NULL DEFAULT 'low',
  file_ref TEXT NULL,
  metadata_only BOOLEAN NOT NULL DEFAULT TRUE,
  external_source TEXT NULL,
  external_contract_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (end_date IS NULL OR end_date >= start_date),
  CHECK (metadata_only = TRUE)
);

CREATE TABLE IF NOT EXISTS puls_workflow.contract_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  contract_id UUID NOT NULL REFERENCES puls_workflow.contracts(id) ON DELETE CASCADE,
  file_ref TEXT NOT NULL,
  file_name TEXT NULL,
  mime_type TEXT NULL,
  file_size_bytes BIGINT NULL,
  metadata_only BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (metadata_only = TRUE)
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_puls_performance_cycles_tenant_status
  ON puls_performance.performance_cycles (tenant_id, status);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_performance_cycles_legacy_public
  ON puls_performance.performance_cycles (legacy_public_cycle_id)
  WHERE legacy_public_cycle_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_puls_performance_competency_templates_tenant_active
  ON puls_performance.competency_templates (tenant_id, is_active);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_performance_competency_templates_legacy_public
  ON puls_performance.competency_templates (legacy_public_template_id)
  WHERE legacy_public_template_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_puls_performance_kpis_employee_cycle
  ON puls_performance.performance_kpis (tenant_id, employee_id, cycle_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_performance_kpis_external
  ON puls_performance.performance_kpis (tenant_id, external_source, external_kpi_id)
  WHERE external_source IS NOT NULL AND external_kpi_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_performance_comp_eval_unique
  ON puls_performance.competency_evaluations
  NULLS NOT DISTINCT
  (tenant_id, employee_id, cycle_id, competency_template_id, evaluator_employee_id);

CREATE INDEX IF NOT EXISTS idx_puls_performance_scores_employee_cycle
  ON puls_performance.performance_scores (tenant_id, employee_id, cycle_id);

CREATE INDEX IF NOT EXISTS idx_puls_performance_career_profiles_tenant
  ON puls_performance.career_profiles (tenant_id, employee_id);

CREATE INDEX IF NOT EXISTS idx_puls_performance_training_needs_tenant
  ON puls_performance.training_needs (tenant_id, employee_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_contracts_tenant_employee
  ON puls_workflow.contracts (tenant_id, employee_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_workflow_contracts_external
  ON puls_workflow.contracts (tenant_id, external_source, external_contract_id)
  WHERE external_source IS NOT NULL AND external_contract_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_puls_workflow_contract_files_contract
  ON puls_workflow.contract_files (contract_id);

-- ---------------------------------------------------------------------------
-- Legacy bootstrap: public.performans_* → puls_performance (guarded dynamic SQL)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('public.performans_cycles') IS NOT NULL THEN
    EXECUTE $sql$
      INSERT INTO puls_performance.performance_cycles (
        tenant_id,
        legacy_public_cycle_id,
        name,
        status,
        starts_at,
        ends_at,
        scope,
        created_at
      )
      SELECT
        t.id,
        pc.id,
        pc.name,
        pc.status::text::puls_performance.performance_cycle_status,
        pc.starts_at,
        pc.ends_at,
        'tenant',
        pc.created_at
      FROM public.performans_cycles pc
      JOIN puls_core.tenants t ON t.legacy_public_tenant_id = pc.tenant_id
      ON CONFLICT (legacy_public_cycle_id) WHERE legacy_public_cycle_id IS NOT NULL
      DO UPDATE SET
        name = EXCLUDED.name,
        status = EXCLUDED.status,
        starts_at = EXCLUDED.starts_at,
        ends_at = EXCLUDED.ends_at,
        updated_at = NOW()
    $sql$;
  END IF;

  IF to_regclass('public.performans_competency_templates') IS NOT NULL THEN
    EXECUTE $sql$
      INSERT INTO puls_performance.competency_templates (
        tenant_id,
        legacy_public_template_id,
        name,
        description,
        weight,
        scale_min,
        scale_max,
        sort_order,
        is_active,
        created_at
      )
      SELECT
        t.id,
        ct.id,
        ct.name,
        ct.description,
        COALESCE(ct.weight, 1),
        COALESCE(ct.scale_min, 1),
        COALESCE(ct.scale_max, 5),
        COALESCE(ct.sort_order, 0),
        COALESCE(ct.is_active, TRUE),
        ct.created_at
      FROM public.performans_competency_templates ct
      JOIN puls_core.tenants t ON t.legacy_public_tenant_id = ct.tenant_id
      ON CONFLICT (legacy_public_template_id) WHERE legacy_public_template_id IS NOT NULL
      DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        weight = EXCLUDED.weight,
        scale_min = EXCLUDED.scale_min,
        scale_max = EXCLUDED.scale_max,
        sort_order = EXCLUDED.sort_order,
        is_active = EXCLUDED.is_active,
        updated_at = NOW()
    $sql$;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS puls_performance_cycles_set_updated_at ON puls_performance.performance_cycles;
CREATE TRIGGER puls_performance_cycles_set_updated_at
  BEFORE UPDATE ON puls_performance.performance_cycles
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_performance_competency_templates_set_updated_at ON puls_performance.competency_templates;
CREATE TRIGGER puls_performance_competency_templates_set_updated_at
  BEFORE UPDATE ON puls_performance.competency_templates
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_performance_kpis_set_updated_at ON puls_performance.performance_kpis;
CREATE TRIGGER puls_performance_kpis_set_updated_at
  BEFORE UPDATE ON puls_performance.performance_kpis
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_performance_competency_evaluations_set_updated_at ON puls_performance.competency_evaluations;
CREATE TRIGGER puls_performance_competency_evaluations_set_updated_at
  BEFORE UPDATE ON puls_performance.competency_evaluations
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_performance_scores_set_updated_at ON puls_performance.performance_scores;
CREATE TRIGGER puls_performance_scores_set_updated_at
  BEFORE UPDATE ON puls_performance.performance_scores
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_performance_career_profiles_set_updated_at ON puls_performance.career_profiles;
CREATE TRIGGER puls_performance_career_profiles_set_updated_at
  BEFORE UPDATE ON puls_performance.career_profiles
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_performance_training_needs_set_updated_at ON puls_performance.training_needs;
CREATE TRIGGER puls_performance_training_needs_set_updated_at
  BEFORE UPDATE ON puls_performance.training_needs
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_contracts_set_updated_at ON puls_workflow.contracts;
CREATE TRIGGER puls_workflow_contracts_set_updated_at
  BEFORE UPDATE ON puls_workflow.contracts
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_contract_files_set_updated_at ON puls_workflow.contract_files;
CREATE TRIGGER puls_workflow_contract_files_set_updated_at
  BEFORE UPDATE ON puls_workflow.contract_files
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security (no DELETE policies)
-- ---------------------------------------------------------------------------

ALTER TABLE puls_performance.performance_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_performance.competency_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_performance.performance_kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_performance.competency_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_performance.performance_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_performance.career_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_performance.training_needs ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.contract_files ENABLE ROW LEVEL SECURITY;

-- Performance config: performance_cycles
DROP POLICY IF EXISTS puls_performance_cycles_select ON puls_performance.performance_cycles;
CREATE POLICY puls_performance_cycles_select ON puls_performance.performance_cycles
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_cycles_insert ON puls_performance.performance_cycles;
CREATE POLICY puls_performance_cycles_insert ON puls_performance.performance_cycles
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_cycles_update ON puls_performance.performance_cycles;
CREATE POLICY puls_performance_cycles_update ON puls_performance.performance_cycles
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Performance config: competency_templates
DROP POLICY IF EXISTS puls_performance_competency_templates_select ON puls_performance.competency_templates;
CREATE POLICY puls_performance_competency_templates_select ON puls_performance.competency_templates
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_competency_templates_insert ON puls_performance.competency_templates;
CREATE POLICY puls_performance_competency_templates_insert ON puls_performance.competency_templates
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_competency_templates_update ON puls_performance.competency_templates;
CREATE POLICY puls_performance_competency_templates_update ON puls_performance.competency_templates
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Performance data: shared SELECT pattern macro via per-table policies
DROP POLICY IF EXISTS puls_performance_kpis_select ON puls_performance.performance_kpis;
CREATE POLICY puls_performance_kpis_select ON puls_performance.performance_kpis
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = performance_kpis.employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_performance_kpis_insert ON puls_performance.performance_kpis;
CREATE POLICY puls_performance_kpis_insert ON puls_performance.performance_kpis
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_kpis_update ON puls_performance.performance_kpis;
CREATE POLICY puls_performance_kpis_update ON puls_performance.performance_kpis
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_competency_evaluations_select ON puls_performance.competency_evaluations;
CREATE POLICY puls_performance_competency_evaluations_select ON puls_performance.competency_evaluations
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = competency_evaluations.employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_performance_competency_evaluations_insert ON puls_performance.competency_evaluations;
CREATE POLICY puls_performance_competency_evaluations_insert ON puls_performance.competency_evaluations
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_competency_evaluations_update ON puls_performance.competency_evaluations;
CREATE POLICY puls_performance_competency_evaluations_update ON puls_performance.competency_evaluations
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_scores_select ON puls_performance.performance_scores;
CREATE POLICY puls_performance_scores_select ON puls_performance.performance_scores
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = performance_scores.employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_performance_scores_insert ON puls_performance.performance_scores;
CREATE POLICY puls_performance_scores_insert ON puls_performance.performance_scores
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_scores_update ON puls_performance.performance_scores;
CREATE POLICY puls_performance_scores_update ON puls_performance.performance_scores
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_career_profiles_select ON puls_performance.career_profiles;
CREATE POLICY puls_performance_career_profiles_select ON puls_performance.career_profiles
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = career_profiles.employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_performance_career_profiles_insert ON puls_performance.career_profiles;
CREATE POLICY puls_performance_career_profiles_insert ON puls_performance.career_profiles
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_career_profiles_update ON puls_performance.career_profiles;
CREATE POLICY puls_performance_career_profiles_update ON puls_performance.career_profiles
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_training_needs_select ON puls_performance.training_needs;
CREATE POLICY puls_performance_training_needs_select ON puls_performance.training_needs
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = training_needs.employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_performance_training_needs_insert ON puls_performance.training_needs;
CREATE POLICY puls_performance_training_needs_insert ON puls_performance.training_needs
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_performance_training_needs_update ON puls_performance.training_needs;
CREATE POLICY puls_performance_training_needs_update ON puls_performance.training_needs
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Contracts V1: self + admin only (no manager broad visibility)
DROP POLICY IF EXISTS puls_workflow_contracts_select ON puls_workflow.contracts;
CREATE POLICY puls_workflow_contracts_select ON puls_workflow.contracts
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
    )
  );

DROP POLICY IF EXISTS puls_workflow_contracts_insert ON puls_workflow.contracts;
CREATE POLICY puls_workflow_contracts_insert ON puls_workflow.contracts
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_contracts_update ON puls_workflow.contracts;
CREATE POLICY puls_workflow_contracts_update ON puls_workflow.contracts
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_contract_files_select ON puls_workflow.contract_files;
CREATE POLICY puls_workflow_contract_files_select ON puls_workflow.contract_files
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.contracts c
      WHERE c.id = contract_files.contract_id
        AND c.tenant_id = contract_files.tenant_id
        AND (
          puls_core.is_admin()
          OR c.employee_id = puls_core.current_employee_id()
        )
    )
  );

DROP POLICY IF EXISTS puls_workflow_contract_files_insert ON puls_workflow.contract_files;
CREATE POLICY puls_workflow_contract_files_insert ON puls_workflow.contract_files
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_contract_files_update ON puls_workflow.contract_files;
CREATE POLICY puls_workflow_contract_files_update ON puls_workflow.contract_files
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- ---------------------------------------------------------------------------
-- puls_calc views (security_invoker = true; aggregates role-scoped by RLS)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW puls_calc.dashboard_overview
WITH (security_invoker = true) AS
SELECT
  t.id AS tenant_id,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.employees e
    WHERE e.tenant_id = t.id
      AND e.employment_status = 'active'::puls_core.employment_status
  ) AS employee_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.departments d
    WHERE d.tenant_id = t.id AND d.is_active = TRUE
  ) AS department_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.positions p
    WHERE p.tenant_id = t.id AND p.is_active = TRUE
  ) AS position_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_performance.competency_templates ct
    WHERE ct.tenant_id = t.id AND ct.is_active = TRUE
  ) AS competency_template_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.leave_requests lr
    WHERE lr.tenant_id = t.id
      AND lr.status = 'pending'::puls_workflow.leave_request_status
  ) AS pending_leave_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = t.id
      AND ec.status = 'pending'::puls_workflow.expense_claim_status
  ) AS pending_expense_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.approval_requests ar
    WHERE ar.tenant_id = t.id
      AND ar.status = 'pending'::puls_workflow.approval_status
  ) AS pending_approval_count,
  (
    SELECT pc.name
    FROM puls_performance.performance_cycles pc
    WHERE pc.tenant_id = t.id
      AND pc.status = 'active'::puls_performance.performance_cycle_status
    ORDER BY pc.starts_at DESC
    LIMIT 1
  ) AS active_cycle_name,
  (
    SELECT ROUND(AVG(ps.overall_score), 1)
    FROM puls_performance.performance_scores ps
    JOIN puls_performance.performance_cycles pc ON pc.id = ps.cycle_id
    WHERE ps.tenant_id = t.id
      AND pc.status = 'active'::puls_performance.performance_cycle_status
  ) AS avg_performance_score,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.contracts c
    WHERE c.tenant_id = t.id
      AND c.status = 'active'::puls_workflow.contract_status
  ) AS active_contract_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.contracts c
    WHERE c.tenant_id = t.id
      AND c.status = 'active'::puls_workflow.contract_status
      AND c.end_date IS NOT NULL
      AND c.end_date <= CURRENT_DATE + 60
  ) AS expiring_contract_count,
  LEAST(
    100,
    (
      CASE WHEN EXISTS (
        SELECT 1 FROM puls_core.employees e
        WHERE e.tenant_id = t.id AND e.employment_status = 'active'::puls_core.employment_status
      ) THEN 40 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_core.departments d WHERE d.tenant_id = t.id AND d.is_active = TRUE
      ) AND EXISTS (
        SELECT 1 FROM puls_core.positions p WHERE p.tenant_id = t.id AND p.is_active = TRUE
      ) THEN 20 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_integration.erp_connections ic WHERE ic.tenant_id = t.id
      ) OR EXISTS (
        SELECT 1 FROM puls_integration.erp_field_mappings fm WHERE fm.tenant_id = t.id
      ) THEN 20 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_workflow.leave_types lt WHERE lt.tenant_id = t.id AND lt.is_active = TRUE
      ) AND EXISTS (
        SELECT 1 FROM puls_workflow.expense_categories ec WHERE ec.tenant_id = t.id AND ec.is_active = TRUE
      ) THEN 20 ELSE 0 END
    )
  )::numeric(5, 2) AS data_readiness_pct,
  'dashboard_overview_v1'::text AS calculation_version
FROM puls_core.tenants t;

CREATE OR REPLACE VIEW puls_calc.employee_list_overview
WITH (security_invoker = true) AS
SELECT
  t.id AS tenant_id,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.employees e
    WHERE e.tenant_id = t.id
      AND e.employment_status = 'active'::puls_core.employment_status
  ) AS active_employee_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.employees e
    WHERE e.tenant_id = t.id
      AND e.employment_status = 'active'::puls_core.employment_status
      AND e.hire_date >= CURRENT_DATE - 30
  ) AS new_employee_30d_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.employees e
    WHERE e.tenant_id = t.id
      AND e.employment_status = 'active'::puls_core.employment_status
      AND e.hire_date IS NOT NULL
      AND e.hire_date >= CURRENT_DATE - 90
  ) AS probation_employee_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.departments d
    WHERE d.tenant_id = t.id AND d.is_active = TRUE
  ) AS department_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.positions p
    WHERE p.tenant_id = t.id AND p.is_active = TRUE
  ) AS position_count
FROM puls_core.tenants t;

CREATE OR REPLACE VIEW puls_calc.organization_overview
WITH (security_invoker = true) AS
SELECT
  t.id AS tenant_id,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.departments d
    WHERE d.tenant_id = t.id AND d.is_active = TRUE
  ) AS department_total_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.departments d
    WHERE d.tenant_id = t.id AND d.is_active = TRUE AND d.manager_employee_id IS NOT NULL
  ) AS department_with_manager_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.employees e
    WHERE e.tenant_id = t.id
      AND e.employment_status = 'active'::puls_core.employment_status
  ) AS active_employee_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.positions p
    WHERE p.tenant_id = t.id AND p.is_active = TRUE
  ) AS position_total_count,
  (
    SELECT COUNT(DISTINCT e.position_id)::integer
    FROM puls_core.employees e
    WHERE e.tenant_id = t.id
      AND e.employment_status = 'active'::puls_core.employment_status
      AND e.position_id IS NOT NULL
  ) AS filled_position_count,
  GREATEST(
    0,
    COALESCE((
      SELECT SUM(p.norm_headcount)::integer
      FROM puls_core.positions p
      WHERE p.tenant_id = t.id AND p.is_active = TRUE
    ), 0)
    - COALESCE((
      SELECT COUNT(DISTINCT e.position_id)::integer
      FROM puls_core.employees e
      WHERE e.tenant_id = t.id
        AND e.employment_status = 'active'::puls_core.employment_status
        AND e.position_id IS NOT NULL
    ), 0)
  ) AS open_position_count
FROM puls_core.tenants t;

CREATE OR REPLACE VIEW puls_calc.leave_overview
WITH (security_invoker = true) AS
SELECT
  e.tenant_id,
  e.id AS employee_id,
  COALESCE(annual.remaining_days, 0) AS annual_leave_remaining,
  COALESCE(annual.used_days, 0) AS annual_leave_used,
  COALESCE(annual.entitlement_days + annual.carried_over_days + annual.adjustment_days, 0) AS annual_leave_total,
  COALESCE(excuse.remaining_days, 0) AS excuse_leave_remaining,
  COALESCE(sick.remaining_days, 0) AS sick_leave_remaining,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.leave_requests lr
    WHERE lr.tenant_id = e.tenant_id
      AND lr.employee_id = e.id
      AND lr.status = 'pending'::puls_workflow.leave_request_status
  ) AS pending_leave_count
FROM puls_core.employees e
LEFT JOIN LATERAL (
  SELECT lb.remaining_days, lb.used_days, lb.entitlement_days, lb.carried_over_days, lb.adjustment_days
  FROM puls_workflow.leave_balances lb
  JOIN puls_workflow.leave_types lt ON lt.id = lb.leave_type_id
  WHERE lb.tenant_id = e.tenant_id
    AND lb.employee_id = e.id
    AND lt.code = 'annual'
    AND lb.period_year = EXTRACT(YEAR FROM CURRENT_DATE)::integer
  LIMIT 1
) annual ON TRUE
LEFT JOIN LATERAL (
  SELECT lb.remaining_days
  FROM puls_workflow.leave_balances lb
  JOIN puls_workflow.leave_types lt ON lt.id = lb.leave_type_id
  WHERE lb.tenant_id = e.tenant_id
    AND lb.employee_id = e.id
    AND lt.code = 'excuse'
    AND lb.period_year = EXTRACT(YEAR FROM CURRENT_DATE)::integer
  LIMIT 1
) excuse ON TRUE
LEFT JOIN LATERAL (
  SELECT lb.remaining_days
  FROM puls_workflow.leave_balances lb
  JOIN puls_workflow.leave_types lt ON lt.id = lb.leave_type_id
  WHERE lb.tenant_id = e.tenant_id
    AND lb.employee_id = e.id
    AND lt.code = 'sick'
    AND lb.period_year = EXTRACT(YEAR FROM CURRENT_DATE)::integer
  LIMIT 1
) sick ON TRUE;

CREATE OR REPLACE VIEW puls_calc.expense_overview
WITH (security_invoker = true) AS
SELECT
  e.tenant_id,
  e.id AS employee_id,
  COALESCE((
    SELECT SUM(ec.amount)
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = e.tenant_id
      AND ec.employee_id = e.id
      AND ec.status = 'approved'::puls_workflow.expense_claim_status
      AND DATE_TRUNC('month', ec.expense_date) = DATE_TRUNC('month', CURRENT_DATE)
  ), 0)::numeric(18, 2) AS approved_this_month_amount,
  COALESCE((
    SELECT SUM(ec.amount)
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = e.tenant_id
      AND ec.employee_id = e.id
      AND ec.status = 'pending'::puls_workflow.expense_claim_status
  ), 0)::numeric(18, 2) AS pending_expense_amount,
  COALESCE((
    SELECT SUM(ec.amount)
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = e.tenant_id
      AND ec.employee_id = e.id
      AND EXTRACT(YEAR FROM ec.expense_date) = EXTRACT(YEAR FROM CURRENT_DATE)
      AND ec.status IN (
        'approved'::puls_workflow.expense_claim_status,
        'exported'::puls_workflow.expense_claim_status
      )
  ), 0)::numeric(18, 2) AS expense_year_total,
  COALESCE((
    SELECT ROUND(
      SUM(ec.amount) / GREATEST(EXTRACT(MONTH FROM CURRENT_DATE)::numeric, 1),
      2
    )
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = e.tenant_id
      AND ec.employee_id = e.id
      AND EXTRACT(YEAR FROM ec.expense_date) = EXTRACT(YEAR FROM CURRENT_DATE)
      AND ec.status IN (
        'approved'::puls_workflow.expense_claim_status,
        'exported'::puls_workflow.expense_claim_status
      )
  ), 0)::numeric(18, 2) AS expense_monthly_average,
  (
    SELECT cat.name
    FROM puls_workflow.expense_claims ec
    JOIN puls_workflow.expense_categories cat ON cat.id = ec.category_id
    WHERE ec.tenant_id = e.tenant_id
      AND ec.employee_id = e.id
      AND EXTRACT(YEAR FROM ec.expense_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    GROUP BY cat.id, cat.name
    ORDER BY SUM(ec.amount) DESC
    LIMIT 1
  ) AS top_expense_category,
  COALESCE((
    SELECT MAX(cat.monthly_limit)
    FROM puls_workflow.expense_categories cat
    WHERE cat.tenant_id = e.tenant_id AND cat.is_active = TRUE
  ), 0)::numeric(18, 2) AS monthly_limit,
  CASE
    WHEN COALESCE((
      SELECT MAX(cat.monthly_limit)
      FROM puls_workflow.expense_categories cat
      WHERE cat.tenant_id = e.tenant_id AND cat.is_active = TRUE
    ), 0) > 0 THEN ROUND(
      COALESCE((
        SELECT SUM(ec.amount)
        FROM puls_workflow.expense_claims ec
        WHERE ec.tenant_id = e.tenant_id
          AND ec.employee_id = e.id
          AND ec.status = 'approved'::puls_workflow.expense_claim_status
          AND DATE_TRUNC('month', ec.expense_date) = DATE_TRUNC('month', CURRENT_DATE)
      ), 0)
      / (
        SELECT MAX(cat.monthly_limit)
        FROM puls_workflow.expense_categories cat
        WHERE cat.tenant_id = e.tenant_id AND cat.is_active = TRUE
      ) * 100,
      1
    )
    ELSE 0
  END::numeric(5, 2) AS limit_usage_pct
FROM puls_core.employees e;

CREATE OR REPLACE VIEW puls_calc.performance_overview
WITH (security_invoker = true) AS
SELECT
  e.tenant_id,
  e.id AS employee_id,
  pc.id AS active_cycle_id,
  pc.name AS active_cycle_name,
  ps.kpi_score,
  ps.competency_score,
  ps.overall_score,
  ps.status_band,
  (
    SELECT ROUND(AVG(ps2.overall_score), 1)
    FROM puls_performance.performance_scores ps2
    WHERE ps2.tenant_id = e.tenant_id
      AND ps2.cycle_id = pc.id
  ) AS tenant_average_score,
  (
    SELECT COUNT(*)::integer
    FROM puls_performance.competency_evaluations ce
    WHERE ce.tenant_id = e.tenant_id
      AND ce.employee_id = e.id
      AND ce.cycle_id = pc.id
      AND ce.status IN (
        'draft'::puls_performance.evaluation_status,
        'pending'::puls_performance.evaluation_status
      )
  ) AS pending_review_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_performance.competency_templates ct
    WHERE ct.tenant_id = e.tenant_id AND ct.is_active = TRUE
  ) AS competency_template_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.employees emp
    LEFT JOIN puls_performance.performance_scores psc ON psc.employee_id = emp.id AND psc.cycle_id = pc.id
    LEFT JOIN puls_performance.career_profiles cp ON cp.employee_id = emp.id AND cp.tenant_id = emp.tenant_id
    WHERE emp.tenant_id = e.tenant_id
      AND (
        COALESCE(cp.readiness_score, 0) >= 80
        OR COALESCE(psc.overall_score, 0) >= 85
      )
  ) AS promotion_candidate_count
FROM puls_core.employees e
LEFT JOIN LATERAL (
  SELECT c.id, c.name
  FROM puls_performance.performance_cycles c
  WHERE c.tenant_id = e.tenant_id
    AND c.status = 'active'::puls_performance.performance_cycle_status
  ORDER BY c.starts_at DESC
  LIMIT 1
) pc ON TRUE
LEFT JOIN puls_performance.performance_scores ps
  ON ps.employee_id = e.id
  AND ps.cycle_id = pc.id
  AND ps.tenant_id = e.tenant_id;

CREATE OR REPLACE VIEW puls_calc.contracts_overview
WITH (security_invoker = true) AS
SELECT
  e.tenant_id,
  e.id AS employee_id,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.contracts c
    WHERE c.tenant_id = e.tenant_id
      AND c.employee_id = e.id
      AND c.status = 'active'::puls_workflow.contract_status
  ) AS active_contract_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.contracts c
    WHERE c.tenant_id = e.tenant_id
      AND c.employee_id = e.id
      AND c.status = 'active'::puls_workflow.contract_status
      AND c.end_date IS NOT NULL
      AND c.end_date <= CURRENT_DATE + 60
  ) AS expiring_contract_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_workflow.contracts c
    WHERE c.tenant_id = e.tenant_id
      AND c.employee_id = e.id
      AND c.signature_status = 'awaiting'::puls_workflow.contract_signature_status
  ) AS awaiting_signature_count,
  0::integer AS missing_kvkk_count,
  (
    SELECT c.risk_band
    FROM puls_workflow.contracts c
    WHERE c.tenant_id = e.tenant_id
      AND c.employee_id = e.id
    ORDER BY
      CASE c.risk_band
        WHEN 'high'::puls_workflow.contract_risk_band THEN 3
        WHEN 'medium'::puls_workflow.contract_risk_band THEN 2
        ELSE 1
      END DESC
    LIMIT 1
  ) AS highest_risk_band
FROM puls_core.employees e;

CREATE OR REPLACE VIEW puls_calc.setup_readiness_summary
WITH (security_invoker = true) AS
SELECT
  t.id AS tenant_id,
  (
    CASE WHEN EXISTS (
      SELECT 1 FROM puls_core.employees e
      WHERE e.tenant_id = t.id AND e.employment_status = 'active'::puls_core.employment_status
    ) THEN 50 ELSE 0 END
    + CASE WHEN EXISTS (
      SELECT 1 FROM puls_core.departments d WHERE d.tenant_id = t.id AND d.is_active = TRUE
    ) THEN 25 ELSE 0 END
    + CASE WHEN EXISTS (
      SELECT 1 FROM puls_core.positions p WHERE p.tenant_id = t.id AND p.is_active = TRUE
    ) THEN 25 ELSE 0 END
  )::numeric(5, 2) AS core_setup_pct,
  (
    CASE WHEN EXISTS (
      SELECT 1 FROM puls_workflow.leave_types lt WHERE lt.tenant_id = t.id AND lt.is_active = TRUE
    ) THEN 50 ELSE 0 END
    + CASE WHEN EXISTS (
      SELECT 1 FROM puls_workflow.expense_categories ec WHERE ec.tenant_id = t.id AND ec.is_active = TRUE
    ) THEN 50 ELSE 0 END
  )::numeric(5, 2) AS workflow_setup_pct,
  (
    CASE WHEN EXISTS (
      SELECT 1 FROM puls_integration.erp_connections ic WHERE ic.tenant_id = t.id
    ) THEN 50 ELSE 0 END
    + CASE WHEN EXISTS (
      SELECT 1 FROM puls_integration.erp_field_mappings fm WHERE fm.tenant_id = t.id
    ) THEN 50 ELSE 0 END
  )::numeric(5, 2) AS integration_setup_pct,
  (
    CASE WHEN EXISTS (
      SELECT 1 FROM puls_performance.performance_cycles pc WHERE pc.tenant_id = t.id
    ) THEN 34 ELSE 0 END
    + CASE WHEN EXISTS (
      SELECT 1 FROM puls_performance.competency_templates ct WHERE ct.tenant_id = t.id AND ct.is_active = TRUE
    ) THEN 33 ELSE 0 END
    + CASE WHEN EXISTS (
      SELECT 1 FROM puls_performance.performance_scores ps WHERE ps.tenant_id = t.id
    ) THEN 33 ELSE 0 END
  )::numeric(5, 2) AS performance_setup_pct,
  ROUND((
    (
      CASE WHEN EXISTS (
        SELECT 1 FROM puls_core.employees e
        WHERE e.tenant_id = t.id AND e.employment_status = 'active'::puls_core.employment_status
      ) THEN 25 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_core.departments d WHERE d.tenant_id = t.id AND d.is_active = TRUE
      ) THEN 12.5 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_core.positions p WHERE p.tenant_id = t.id AND p.is_active = TRUE
      ) THEN 12.5 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_workflow.leave_types lt WHERE lt.tenant_id = t.id AND lt.is_active = TRUE
      ) THEN 12.5 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_workflow.expense_categories ec WHERE ec.tenant_id = t.id AND ec.is_active = TRUE
      ) THEN 12.5 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_integration.erp_connections ic WHERE ic.tenant_id = t.id
      ) THEN 12.5 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1 FROM puls_performance.performance_cycles pc WHERE pc.tenant_id = t.id
      ) THEN 12.5 ELSE 0 END
    )
  ), 2)::numeric(5, 2) AS overall_readiness_pct,
  'setup_readiness_summary_v1'::text AS calculation_version
FROM puls_core.tenants t;

CREATE OR REPLACE VIEW puls_calc.menu_overview
WITH (security_invoker = true) AS
SELECT
  e.tenant_id,
  e.id AS employee_id,
  e.full_name AS display_name,
  e.job_title,
  t.name AS tenant_name,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.employees emp
    WHERE emp.tenant_id = e.tenant_id
      AND emp.employment_status = 'active'::puls_core.employment_status
  ) AS employee_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.departments d
    WHERE d.tenant_id = e.tenant_id AND d.is_active = TRUE
  ) AS department_count,
  (
    SELECT COUNT(*)::integer
    FROM puls_core.positions p
    WHERE p.tenant_id = e.tenant_id AND p.is_active = TRUE
  ) AS position_count
FROM puls_core.employees e
JOIN puls_core.tenants t ON t.id = e.tenant_id;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT USAGE ON SCHEMA puls_performance, puls_calc TO authenticated, service_role;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA puls_performance TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA puls_calc TO authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA puls_performance, puls_calc TO service_role;

GRANT SELECT, INSERT, UPDATE ON puls_workflow.contracts, puls_workflow.contract_files TO authenticated;
GRANT ALL ON puls_workflow.contracts, puls_workflow.contract_files TO service_role;

-- ---------------------------------------------------------------------------
-- Mert Teknik demo seed (idempotent; runs after bootstrap)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_tenant_id UUID;
  v_demo_ik UUID;
  v_demo_manager UUID;
  v_emp_4403 UUID;
  v_emp_4404 UUID;
  v_emp_4405 UUID;
  v_cycle_id UUID;
  v_tpl_liderlik UUID;
  v_tpl_stratejik UUID;
  v_tpl_iletisim UUID;
  v_evaluator UUID;
BEGIN
  SELECT t.id INTO v_tenant_id
  FROM puls_core.tenants t
  LEFT JOIN public.tenants pt ON pt.id = t.legacy_public_tenant_id
  WHERE t.legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'::uuid
     OR t.name ILIKE '%Mert Teknik%'
     OR pt.name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RETURN;
  END IF;

  SELECT e.id INTO v_demo_ik
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.user_id IS NOT NULL
    AND e.persona_role IN ('hr_admin'::puls_core.persona_role, 'superadmin'::puls_core.persona_role)
  ORDER BY e.persona_role
  LIMIT 1;

  IF v_demo_ik IS NULL THEN
    SELECT e.id INTO v_demo_ik
    FROM puls_core.employees e
    WHERE e.tenant_id = v_tenant_id AND e.email = 'demo@mertteknik.local'
    LIMIT 1;
  END IF;

  IF v_demo_ik IS NULL THEN
    SELECT e.id INTO v_demo_ik
    FROM puls_core.employees e
    WHERE e.tenant_id = v_tenant_id
      AND e.legacy_public_employee_id = '44444444-4444-4444-4444-444444444401'::uuid
    LIMIT 1;
  END IF;

  SELECT e.id INTO v_demo_manager
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND (e.email = 'yonetici@mertteknik.demo' OR e.persona_role = 'manager'::puls_core.persona_role)
  ORDER BY CASE WHEN e.email = 'yonetici@mertteknik.demo' THEN 0 ELSE 1 END
  LIMIT 1;

  SELECT e.id INTO v_emp_4403
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.legacy_public_employee_id = '44444444-4444-4444-4444-444444444403'::uuid
  LIMIT 1;

  SELECT e.id INTO v_emp_4404
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.legacy_public_employee_id = '44444444-4444-4444-4444-444444444404'::uuid
  LIMIT 1;

  SELECT e.id INTO v_emp_4405
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.legacy_public_employee_id = '44444444-4444-4444-4444-444444444405'::uuid
  LIMIT 1;

  IF v_demo_ik IS NULL THEN
    RETURN;
  END IF;

  v_evaluator := COALESCE(v_demo_manager, v_demo_ik);

  INSERT INTO puls_performance.performance_cycles (
    tenant_id, name, status, starts_at, ends_at, scope
  )
  VALUES (
    v_tenant_id,
    '2026 Yıllık Değerlendirme',
    'active',
    '2026-01-01',
    '2026-12-31',
    'tenant'
  )
  ON CONFLICT (tenant_id, name) DO UPDATE SET
    status = EXCLUDED.status,
    starts_at = EXCLUDED.starts_at,
    ends_at = EXCLUDED.ends_at,
    updated_at = NOW();

  SELECT id INTO v_cycle_id
  FROM puls_performance.performance_cycles
  WHERE tenant_id = v_tenant_id AND name = '2026 Yıllık Değerlendirme';

  INSERT INTO puls_performance.competency_templates (
    tenant_id, name, description, weight, sort_order
  )
  VALUES
    (v_tenant_id, 'Liderlik', 'Ekip yönetimi ve yönlendirme', 1, 1),
    (v_tenant_id, 'Stratejik Düşünme', 'Uzun vadeli planlama', 1, 2),
    (v_tenant_id, 'İletişim', 'Sözlü ve yazılı iletişim', 1, 3)
  ON CONFLICT (tenant_id, name) DO UPDATE SET
    description = EXCLUDED.description,
    weight = EXCLUDED.weight,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

  SELECT id INTO v_tpl_liderlik FROM puls_performance.competency_templates
  WHERE tenant_id = v_tenant_id AND name = 'Liderlik';
  SELECT id INTO v_tpl_stratejik FROM puls_performance.competency_templates
  WHERE tenant_id = v_tenant_id AND name = 'Stratejik Düşünme';
  SELECT id INTO v_tpl_iletisim FROM puls_performance.competency_templates
  WHERE tenant_id = v_tenant_id AND name = 'İletişim';

  IF v_cycle_id IS NOT NULL THEN
    INSERT INTO puls_performance.performance_scores (
      tenant_id, employee_id, cycle_id,
      kpi_score, competency_score, overall_score, status_band,
      calculation_version, calculated_at
    )
    VALUES
      (v_tenant_id, v_demo_ik, v_cycle_id, 92, 88, 90.8, 'very_good', 'performance_overall_v1', NOW())
    ON CONFLICT (tenant_id, employee_id, cycle_id) DO UPDATE SET
      kpi_score = EXCLUDED.kpi_score,
      competency_score = EXCLUDED.competency_score,
      overall_score = EXCLUDED.overall_score,
      status_band = EXCLUDED.status_band,
      calculated_at = EXCLUDED.calculated_at,
      updated_at = NOW();

    IF v_emp_4404 IS NOT NULL THEN
      INSERT INTO puls_performance.performance_scores (
        tenant_id, employee_id, cycle_id,
        kpi_score, competency_score, overall_score, status_band,
        calculation_version, calculated_at
      )
      VALUES (v_tenant_id, v_emp_4404, v_cycle_id, 84, 82, 83.4, 'good', 'performance_overall_v1', NOW())
      ON CONFLICT (tenant_id, employee_id, cycle_id) DO UPDATE SET
        kpi_score = EXCLUDED.kpi_score,
        competency_score = EXCLUDED.competency_score,
        overall_score = EXCLUDED.overall_score,
        status_band = EXCLUDED.status_band,
        calculated_at = EXCLUDED.calculated_at,
        updated_at = NOW();
    END IF;

    IF v_emp_4403 IS NOT NULL THEN
      INSERT INTO puls_performance.performance_scores (
        tenant_id, employee_id, cycle_id,
        kpi_score, competency_score, overall_score, status_band,
        calculation_version, calculated_at
      )
      VALUES (v_tenant_id, v_emp_4403, v_cycle_id, 76, 72, 74.8, 'expected', 'performance_overall_v1', NOW())
      ON CONFLICT (tenant_id, employee_id, cycle_id) DO UPDATE SET
        kpi_score = EXCLUDED.kpi_score,
        competency_score = EXCLUDED.competency_score,
        overall_score = EXCLUDED.overall_score,
        status_band = EXCLUDED.status_band,
        calculated_at = EXCLUDED.calculated_at,
        updated_at = NOW();
    END IF;

    IF v_emp_4405 IS NOT NULL THEN
      INSERT INTO puls_performance.performance_scores (
        tenant_id, employee_id, cycle_id,
        kpi_score, competency_score, overall_score, status_band,
        calculation_version, calculated_at
      )
      VALUES (v_tenant_id, v_emp_4405, v_cycle_id, 80, 78, 79.4, 'good', 'performance_overall_v1', NOW())
      ON CONFLICT (tenant_id, employee_id, cycle_id) DO UPDATE SET
        kpi_score = EXCLUDED.kpi_score,
        competency_score = EXCLUDED.competency_score,
        overall_score = EXCLUDED.overall_score,
        status_band = EXCLUDED.status_band,
        calculated_at = EXCLUDED.calculated_at,
        updated_at = NOW();
    END IF;

    INSERT INTO puls_performance.performance_kpis (
      tenant_id, employee_id, cycle_id, category, name,
      target_value, actual_value, unit, weight, score,
      external_source, external_kpi_id
    )
    VALUES
      (v_tenant_id, v_demo_ik, v_cycle_id, 'Stratejik IK', 'KPI stratejisi tamamlanma', 100, 94, 'percent', 20, 94, 'puls_demo_seed', 'kpi-ik-1'),
      (v_tenant_id, v_demo_ik, v_cycle_id, 'Stratejik IK', 'Yetkinlik matrisi güncelliği', 100, 92, 'percent', 15, 92, 'puls_demo_seed', 'kpi-ik-2'),
      (v_tenant_id, v_demo_ik, v_cycle_id, 'Operasyon', 'İşe alım süresi hedefi', 45, 38, 'count', 15, 84, 'puls_demo_seed', 'kpi-ik-3'),
      (v_tenant_id, v_demo_ik, v_cycle_id, 'Operasyon', 'Oryantasyon tamamlama', 100, 96, 'percent', 15, 96, 'puls_demo_seed', 'kpi-ik-4'),
      (v_tenant_id, v_demo_ik, v_cycle_id, 'Eğitim', 'Zorunlu eğitim katılım', 100, 98, 'percent', 20, 98, 'puls_demo_seed', 'kpi-ik-5'),
      (v_tenant_id, v_demo_ik, v_cycle_id, 'Memnuniyet', 'Çalışan memnuniyet anketi', 85, 88, 'percent', 15, 88, 'puls_demo_seed', 'kpi-ik-6')
    ON CONFLICT (tenant_id, external_source, external_kpi_id)
      WHERE external_source IS NOT NULL AND external_kpi_id IS NOT NULL
    DO UPDATE SET
      actual_value = EXCLUDED.actual_value,
      score = EXCLUDED.score,
      updated_at = NOW();

    IF v_tpl_liderlik IS NOT NULL THEN
      INSERT INTO puls_performance.competency_evaluations (
        tenant_id, employee_id, cycle_id, competency_template_id,
        evaluator_employee_id, score, status, submitted_at
      )
      VALUES (
        v_tenant_id, v_demo_ik, v_cycle_id, v_tpl_liderlik,
        v_evaluator, 4.5, 'submitted', NOW()
      )
      ON CONFLICT (tenant_id, employee_id, cycle_id, competency_template_id, evaluator_employee_id)
      DO UPDATE SET score = EXCLUDED.score, status = EXCLUDED.status, submitted_at = EXCLUDED.submitted_at, updated_at = NOW();
    END IF;

    IF v_tpl_stratejik IS NOT NULL THEN
      INSERT INTO puls_performance.competency_evaluations (
        tenant_id, employee_id, cycle_id, competency_template_id,
        evaluator_employee_id, score, status, submitted_at
      )
      VALUES (
        v_tenant_id, v_demo_ik, v_cycle_id, v_tpl_stratejik,
        v_evaluator, 4.2, 'submitted', NOW()
      )
      ON CONFLICT (tenant_id, employee_id, cycle_id, competency_template_id, evaluator_employee_id)
      DO UPDATE SET score = EXCLUDED.score, status = EXCLUDED.status, submitted_at = EXCLUDED.submitted_at, updated_at = NOW();
    END IF;

    IF v_tpl_iletisim IS NOT NULL THEN
      INSERT INTO puls_performance.competency_evaluations (
        tenant_id, employee_id, cycle_id, competency_template_id,
        evaluator_employee_id, score, status, submitted_at
      )
      VALUES (
        v_tenant_id, v_demo_ik, v_cycle_id, v_tpl_iletisim,
        v_evaluator, 4.8, 'submitted', NOW()
      )
      ON CONFLICT (tenant_id, employee_id, cycle_id, competency_template_id, evaluator_employee_id)
      DO UPDATE SET score = EXCLUDED.score, status = EXCLUDED.status, submitted_at = EXCLUDED.submitted_at, updated_at = NOW();
    END IF;
  END IF;

  INSERT INTO puls_performance.career_profiles (
    tenant_id, employee_id, current_step, target_step, readiness_score, missing_competencies
  )
  VALUES (
    v_tenant_id,
    v_demo_ik,
    'İK Müdürü',
    'İK Lideri',
    87,
    '["Veri odaklı karar alma", "Organizasyonel tasarım", "Değişim yönetimi"]'::jsonb
  )
  ON CONFLICT (tenant_id, employee_id) DO UPDATE SET
    current_step = EXCLUDED.current_step,
    target_step = EXCLUDED.target_step,
    readiness_score = EXCLUDED.readiness_score,
    missing_competencies = EXCLUDED.missing_competencies,
    updated_at = NOW();

  IF NOT EXISTS (
    SELECT 1 FROM puls_performance.training_needs
    WHERE tenant_id = v_tenant_id AND employee_id = v_demo_ik AND skill_topic = 'Liderlik'
  ) THEN
    INSERT INTO puls_performance.training_needs (tenant_id, employee_id, skill_topic, need_level, priority, status)
    VALUES (v_tenant_id, v_demo_ik, 'Liderlik', 'recommended', 1, 'open');
  END IF;

  IF v_emp_4403 IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM puls_performance.training_needs
    WHERE tenant_id = v_tenant_id AND employee_id = v_emp_4403 AND skill_topic = 'Raporlama'
  ) THEN
    INSERT INTO puls_performance.training_needs (tenant_id, employee_id, skill_topic, need_level, priority, status)
    VALUES (v_tenant_id, v_emp_4403, 'Raporlama', 'recommended', 2, 'open');
  END IF;

  IF v_emp_4404 IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM puls_performance.training_needs
    WHERE tenant_id = v_tenant_id AND employee_id = v_emp_4404 AND skill_topic = 'Ekip koordinasyonu'
  ) THEN
    INSERT INTO puls_performance.training_needs (tenant_id, employee_id, skill_topic, need_level, priority, status)
    VALUES (v_tenant_id, v_emp_4404, 'Ekip koordinasyonu', 'recommended', 2, 'open');
  END IF;

  IF v_emp_4405 IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM puls_performance.training_needs
    WHERE tenant_id = v_tenant_id AND employee_id = v_emp_4405 AND skill_topic = 'İletişim'
  ) THEN
    INSERT INTO puls_performance.training_needs (tenant_id, employee_id, skill_topic, need_level, priority, status)
    VALUES (v_tenant_id, v_emp_4405, 'İletişim', 'recommended', 3, 'open');
  END IF;

  INSERT INTO puls_workflow.contracts (
    tenant_id, employee_id, contract_type, start_date, end_date,
    status, signature_status, risk_band, metadata_only,
    external_source, external_contract_id
  )
  VALUES (
    v_tenant_id, v_demo_ik, 'Belirsiz Süreli', '2020-01-01', NULL,
    'active', 'signed', 'low', TRUE, 'puls_demo_seed', 'contract-ik'
  )
  ON CONFLICT (tenant_id, external_source, external_contract_id)
    WHERE external_source IS NOT NULL AND external_contract_id IS NOT NULL
  DO UPDATE SET updated_at = NOW();

  IF v_emp_4404 IS NOT NULL THEN
    INSERT INTO puls_workflow.contracts (
      tenant_id, employee_id, contract_type, start_date, end_date,
      status, signature_status, risk_band, metadata_only,
      external_source, external_contract_id
    )
    VALUES (
      v_tenant_id, v_emp_4404, 'Belirsiz Süreli', '2015-09-10', NULL,
      'active', 'signed', 'low', TRUE, 'puls_demo_seed', 'contract-4404'
    )
    ON CONFLICT (tenant_id, external_source, external_contract_id)
      WHERE external_source IS NOT NULL AND external_contract_id IS NOT NULL
    DO UPDATE SET updated_at = NOW();
  END IF;

  IF v_emp_4403 IS NOT NULL THEN
    INSERT INTO puls_workflow.contracts (
      tenant_id, employee_id, contract_type, start_date, end_date,
      status, signature_status, risk_band, metadata_only,
      external_source, external_contract_id
    )
    VALUES (
      v_tenant_id, v_emp_4403, 'Belirli Süreli', '2020-06-01', CURRENT_DATE + 45,
      'active', 'awaiting', 'medium', TRUE, 'puls_demo_seed', 'contract-4403'
    )
    ON CONFLICT (tenant_id, external_source, external_contract_id)
      WHERE external_source IS NOT NULL AND external_contract_id IS NOT NULL
    DO UPDATE SET
      end_date = EXCLUDED.end_date,
      signature_status = EXCLUDED.signature_status,
      risk_band = EXCLUDED.risk_band,
      updated_at = NOW();
  END IF;

  IF v_emp_4405 IS NOT NULL THEN
    INSERT INTO puls_workflow.contracts (
      tenant_id, employee_id, contract_type, start_date, end_date,
      status, signature_status, risk_band, metadata_only,
      external_source, external_contract_id
    )
    VALUES (
      v_tenant_id, v_emp_4405, 'Belirsiz Süreli', '2018-11-20', NULL,
      'active', 'signed', 'low', TRUE, 'puls_demo_seed', 'contract-4405'
    )
    ON CONFLICT (tenant_id, external_source, external_contract_id)
      WHERE external_source IS NOT NULL AND external_contract_id IS NOT NULL
    DO UPDATE SET updated_at = NOW();
  END IF;
END $$;


