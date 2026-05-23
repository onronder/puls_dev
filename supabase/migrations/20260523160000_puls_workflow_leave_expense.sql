-- PULS workflow: leave, expense, approval (02-db-workflow-leave-expense)
-- puls_workflow schema + public→puls_core bootstrap + Mert Teknik demo seed

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS puls_workflow;

-- ---------------------------------------------------------------------------
-- puls_workflow enums (duplicate-safe)
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE puls_workflow.leave_request_status AS ENUM (
    'draft', 'pending', 'approved', 'rejected', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.expense_claim_status AS ENUM (
    'draft', 'pending', 'approved', 'rejected', 'cancelled', 'exported'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.approval_status AS ENUM (
    'pending', 'approved', 'rejected', 'skipped', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.approval_module AS ENUM ('leave', 'expense');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.approver_type AS ENUM (
    'manager', 'hr_admin', 'specific_employee'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.balance_source AS ENUM (
    'puls', 'erp', 'manual_import'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.policy_status AS ENUM (
    'unchecked', 'compliant', 'warning', 'blocked'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_workflow.document_status AS ENUM (
    'pending', 'verified', 'rejected'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- puls_workflow tables (FK-safe create order)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_workflow.approval_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  module puls_workflow.approval_module NOT NULL,
  description TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE TABLE IF NOT EXISTS puls_workflow.approval_policy_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  policy_id UUID NOT NULL REFERENCES puls_workflow.approval_policies(id) ON DELETE CASCADE,
  step_order INTEGER NOT NULL,
  approver_type puls_workflow.approver_type NOT NULL,
  specific_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (step_order > 0),
  CHECK (
    approver_type <> 'specific_employee'::puls_workflow.approver_type
    OR specific_employee_id IS NOT NULL
  ),
  UNIQUE (policy_id, step_order)
);

CREATE TABLE IF NOT EXISTS puls_workflow.leave_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  is_paid BOOLEAN NOT NULL DEFAULT TRUE,
  default_entitlement_days NUMERIC(8, 2) NULL,
  requires_document BOOLEAN NOT NULL DEFAULT FALSE,
  requires_approval BOOLEAN NOT NULL DEFAULT TRUE,
  show_in_calendar BOOLEAN NOT NULL DEFAULT TRUE,
  carry_over_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  max_carry_over_days NUMERIC(8, 2) NULL,
  approval_policy_id UUID NULL REFERENCES puls_workflow.approval_policies(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE TABLE IF NOT EXISTS puls_workflow.expense_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  monthly_limit NUMERIC(18, 2) NULL,
  receipt_required_over NUMERIC(18, 2) NULL DEFAULT 0,
  default_vat_rate NUMERIC(5, 2) NULL DEFAULT 20,
  approval_policy_id UUID NULL REFERENCES puls_workflow.approval_policies(id) ON DELETE SET NULL,
  erp_account_code TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE TABLE IF NOT EXISTS puls_workflow.leave_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  leave_type_id UUID NOT NULL REFERENCES puls_workflow.leave_types(id) ON DELETE CASCADE,
  period_year INTEGER NOT NULL,
  source puls_workflow.balance_source NOT NULL DEFAULT 'puls',
  entitlement_days NUMERIC(8, 2) NOT NULL DEFAULT 0,
  carried_over_days NUMERIC(8, 2) NOT NULL DEFAULT 0,
  adjustment_days NUMERIC(8, 2) NOT NULL DEFAULT 0,
  used_days NUMERIC(8, 2) NOT NULL DEFAULT 0,
  pending_days NUMERIC(8, 2) NOT NULL DEFAULT 0,
  remaining_days NUMERIC(8, 2) GENERATED ALWAYS AS (
    entitlement_days + carried_over_days + adjustment_days - used_days - pending_days
  ) STORED,
  as_of_date DATE NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, employee_id, leave_type_id, period_year)
);

CREATE TABLE IF NOT EXISTS puls_workflow.leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  leave_type_id UUID NOT NULL REFERENCES puls_workflow.leave_types(id) ON DELETE RESTRICT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  business_days NUMERIC(8, 2) NOT NULL,
  half_day BOOLEAN NOT NULL DEFAULT FALSE,
  delegate_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  description TEXT NULL,
  status puls_workflow.leave_request_status NOT NULL DEFAULT 'draft',
  submitted_at TIMESTAMPTZ NULL,
  approved_at TIMESTAMPTZ NULL,
  rejected_at TIMESTAMPTZ NULL,
  cancelled_at TIMESTAMPTZ NULL,
  current_approval_step INTEGER NULL,
  external_source TEXT NULL,
  external_request_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (end_date >= start_date),
  CHECK (business_days > 0)
);

CREATE TABLE IF NOT EXISTS puls_workflow.expense_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES puls_workflow.expense_categories(id) ON DELETE RESTRICT,
  amount NUMERIC(18, 2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'TRY',
  vat_rate NUMERIC(5, 2) NULL,
  vat_included BOOLEAN NOT NULL DEFAULT TRUE,
  expense_date DATE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NULL,
  policy_status puls_workflow.policy_status NOT NULL DEFAULT 'unchecked',
  status puls_workflow.expense_claim_status NOT NULL DEFAULT 'draft',
  submitted_at TIMESTAMPTZ NULL,
  approved_at TIMESTAMPTZ NULL,
  rejected_at TIMESTAMPTZ NULL,
  cancelled_at TIMESTAMPTZ NULL,
  exported_at TIMESTAMPTZ NULL,
  external_source TEXT NULL,
  external_claim_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (amount > 0)
);

CREATE TABLE IF NOT EXISTS puls_workflow.leave_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  leave_request_id UUID NOT NULL REFERENCES puls_workflow.leave_requests(id) ON DELETE CASCADE,
  uploaded_by_employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE RESTRICT,
  file_ref TEXT NOT NULL,
  file_name TEXT NULL,
  mime_type TEXT NULL,
  file_size_bytes BIGINT NULL,
  status puls_workflow.document_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  expense_claim_id UUID NOT NULL REFERENCES puls_workflow.expense_claims(id) ON DELETE CASCADE,
  uploaded_by_employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE RESTRICT,
  file_ref TEXT NOT NULL,
  file_name TEXT NULL,
  mime_type TEXT NULL,
  file_size_bytes BIGINT NULL,
  ocr_status TEXT NOT NULL DEFAULT 'not_requested',
  status puls_workflow.document_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_workflow.approval_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  module puls_workflow.approval_module NOT NULL,
  leave_request_id UUID NULL REFERENCES puls_workflow.leave_requests(id) ON DELETE CASCADE,
  expense_claim_id UUID NULL REFERENCES puls_workflow.expense_claims(id) ON DELETE CASCADE,
  requester_employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  approver_employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE RESTRICT,
  step_order INTEGER NOT NULL DEFAULT 1,
  status puls_workflow.approval_status NOT NULL DEFAULT 'pending',
  decision_note TEXT NULL,
  decided_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (step_order > 0),
  CHECK (
    (module = 'leave'::puls_workflow.approval_module AND leave_request_id IS NOT NULL AND expense_claim_id IS NULL)
    OR (module = 'expense'::puls_workflow.approval_module AND expense_claim_id IS NOT NULL AND leave_request_id IS NULL)
  )
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_puls_workflow_approval_policies_tenant
  ON puls_workflow.approval_policies (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_approval_policy_steps_policy
  ON puls_workflow.approval_policy_steps (policy_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_approval_policy_steps_tenant
  ON puls_workflow.approval_policy_steps (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_leave_types_tenant
  ON puls_workflow.leave_types (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_expense_categories_tenant
  ON puls_workflow.expense_categories (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_leave_balances_lookup
  ON puls_workflow.leave_balances (tenant_id, employee_id, period_year);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_leave_requests_employee_status
  ON puls_workflow.leave_requests (tenant_id, employee_id, status);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_leave_requests_dates
  ON puls_workflow.leave_requests (tenant_id, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_expense_claims_employee_status
  ON puls_workflow.expense_claims (tenant_id, employee_id, status);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_expense_claims_expense_date
  ON puls_workflow.expense_claims (tenant_id, expense_date DESC);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_leave_documents_request
  ON puls_workflow.leave_documents (leave_request_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_expense_receipts_claim
  ON puls_workflow.expense_receipts (expense_claim_id);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_approval_requests_approver
  ON puls_workflow.approval_requests (tenant_id, approver_employee_id, status);

CREATE INDEX IF NOT EXISTS idx_puls_workflow_approval_requests_requester
  ON puls_workflow.approval_requests (tenant_id, requester_employee_id, status);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_workflow_leave_requests_external
  ON puls_workflow.leave_requests (tenant_id, external_source, external_request_id)
  WHERE external_source IS NOT NULL AND external_request_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_workflow_expense_claims_external
  ON puls_workflow.expense_claims (tenant_id, external_source, external_claim_id)
  WHERE external_source IS NOT NULL AND external_claim_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Legacy partial unique indexes (bootstrap ON CONFLICT targets)
-- ---------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_departments_legacy_public
  ON puls_core.departments (legacy_public_department_id)
  WHERE legacy_public_department_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_positions_legacy_public
  ON puls_core.positions (legacy_public_position_id)
  WHERE legacy_public_position_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_employees_legacy_public
  ON puls_core.employees (legacy_public_employee_id)
  WHERE legacy_public_employee_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Public → puls_core bootstrap (idempotent bridge; no source-of-record claim)
-- ---------------------------------------------------------------------------

INSERT INTO puls_core.tenants (
  legacy_public_tenant_id,
  name,
  legal_name,
  trade_name,
  tax_no,
  industry,
  timezone,
  locale,
  plan_name,
  kvkk_active
)
SELECT
  pt.id,
  COALESCE(pt.trade_name, pt.name),
  pt.legal_name,
  pt.trade_name,
  COALESCE(pt.tax_no, pt.vkn),
  pt.sector,
  COALESCE(pt.timezone, 'Europe/Istanbul'),
  'tr-TR',
  COALESCE(pt.plan_name, pt.plan),
  COALESCE(pt.kvkk_active, TRUE)
FROM public.tenants pt
WHERE EXISTS (SELECT 1 FROM public.tenants LIMIT 1)
ON CONFLICT (legacy_public_tenant_id) WHERE legacy_public_tenant_id IS NOT NULL
DO UPDATE SET
  name = EXCLUDED.name,
  legal_name = EXCLUDED.legal_name,
  trade_name = EXCLUDED.trade_name,
  tax_no = EXCLUDED.tax_no,
  industry = EXCLUDED.industry,
  timezone = EXCLUDED.timezone,
  plan_name = EXCLUDED.plan_name,
  kvkk_active = EXCLUDED.kvkk_active,
  updated_at = NOW();

-- Pass 1: departments without manager FK
INSERT INTO puls_core.departments (
  tenant_id,
  legacy_public_department_id,
  name,
  code,
  is_active
)
SELECT
  t.id,
  pd.id,
  pd.name,
  pd.code,
  COALESCE(pd.is_active, TRUE)
FROM public.departments pd
JOIN puls_core.tenants t ON t.legacy_public_tenant_id = pd.tenant_id
WHERE EXISTS (SELECT 1 FROM public.tenants LIMIT 1)
ON CONFLICT (legacy_public_department_id) WHERE legacy_public_department_id IS NOT NULL
DO UPDATE SET
  name = EXCLUDED.name,
  code = EXCLUDED.code,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- Pass 1: positions without department FK
INSERT INTO puls_core.positions (
  tenant_id,
  legacy_public_position_id,
  name,
  code,
  level,
  employment_type,
  norm_headcount,
  is_active
)
SELECT
  t.id,
  pp.id,
  pp.name,
  pp.code,
  pp.level,
  pp.employment_type,
  COALESCE(pp.norm_headcount, 1),
  TRUE
FROM public.positions pp
JOIN puls_core.tenants t ON t.legacy_public_tenant_id = pp.tenant_id
WHERE EXISTS (SELECT 1 FROM public.tenants LIMIT 1)
ON CONFLICT (legacy_public_position_id) WHERE legacy_public_position_id IS NOT NULL
DO UPDATE SET
  name = EXCLUDED.name,
  code = EXCLUDED.code,
  level = EXCLUDED.level,
  employment_type = EXCLUDED.employment_type,
  norm_headcount = EXCLUDED.norm_headcount,
  updated_at = NOW();

-- Pass 1: employees without org FKs
INSERT INTO puls_core.employees (
  tenant_id,
  legacy_public_employee_id,
  user_id,
  email,
  full_name,
  job_title,
  persona_role,
  hire_date
)
SELECT
  t.id,
  pe.anonymous_id,
  pe.user_id,
  pe.email,
  pe.full_name,
  pe.job_title,
  pe.persona_role::text::puls_core.persona_role,
  pe.hire_date
FROM public.employees pe
JOIN puls_core.tenants t ON t.legacy_public_tenant_id = pe.tenant_id
WHERE EXISTS (SELECT 1 FROM public.tenants LIMIT 1)
ON CONFLICT (legacy_public_employee_id) WHERE legacy_public_employee_id IS NOT NULL
DO UPDATE SET
  user_id = EXCLUDED.user_id,
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name,
  job_title = EXCLUDED.job_title,
  persona_role = EXCLUDED.persona_role,
  hire_date = EXCLUDED.hire_date,
  updated_at = NOW();

-- Pass 2: wire department managers
UPDATE puls_core.departments pd
SET manager_employee_id = me.id
FROM public.departments pub
JOIN puls_core.employees me ON me.legacy_public_employee_id = pub.manager_employee_id
WHERE pd.legacy_public_department_id = pub.id
  AND pub.manager_employee_id IS NOT NULL;

-- Pass 2: wire position departments
UPDATE puls_core.positions pp
SET department_id = pd.id
FROM public.positions pub
JOIN puls_core.departments pd ON pd.legacy_public_department_id = pub.department_id
WHERE pp.legacy_public_position_id = pub.id
  AND pub.department_id IS NOT NULL;

-- Pass 2: wire employee org FKs
UPDATE puls_core.employees pe
SET
  department_id = pd.id,
  position_id = pp.id
FROM public.employees pub
LEFT JOIN puls_core.departments pd ON pd.legacy_public_department_id = pub.department_id
LEFT JOIN puls_core.positions pp ON pp.legacy_public_position_id = pub.position_id
WHERE pe.legacy_public_employee_id = pub.anonymous_id;

UPDATE puls_core.employees pe
SET manager_employee_id = me.id
FROM public.employees pub
JOIN public.departments pd ON pd.id = pub.department_id
JOIN puls_core.employees me ON me.legacy_public_employee_id = pd.manager_employee_id
WHERE pe.legacy_public_employee_id = pub.anonymous_id
  AND pd.manager_employee_id IS NOT NULL
  AND pe.manager_employee_id IS NULL;

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS puls_workflow_approval_policies_set_updated_at ON puls_workflow.approval_policies;
CREATE TRIGGER puls_workflow_approval_policies_set_updated_at
  BEFORE UPDATE ON puls_workflow.approval_policies
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_approval_policy_steps_set_updated_at ON puls_workflow.approval_policy_steps;
CREATE TRIGGER puls_workflow_approval_policy_steps_set_updated_at
  BEFORE UPDATE ON puls_workflow.approval_policy_steps
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_leave_types_set_updated_at ON puls_workflow.leave_types;
CREATE TRIGGER puls_workflow_leave_types_set_updated_at
  BEFORE UPDATE ON puls_workflow.leave_types
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_expense_categories_set_updated_at ON puls_workflow.expense_categories;
CREATE TRIGGER puls_workflow_expense_categories_set_updated_at
  BEFORE UPDATE ON puls_workflow.expense_categories
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_leave_balances_set_updated_at ON puls_workflow.leave_balances;
CREATE TRIGGER puls_workflow_leave_balances_set_updated_at
  BEFORE UPDATE ON puls_workflow.leave_balances
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_leave_requests_set_updated_at ON puls_workflow.leave_requests;
CREATE TRIGGER puls_workflow_leave_requests_set_updated_at
  BEFORE UPDATE ON puls_workflow.leave_requests
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_expense_claims_set_updated_at ON puls_workflow.expense_claims;
CREATE TRIGGER puls_workflow_expense_claims_set_updated_at
  BEFORE UPDATE ON puls_workflow.expense_claims
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_leave_documents_set_updated_at ON puls_workflow.leave_documents;
CREATE TRIGGER puls_workflow_leave_documents_set_updated_at
  BEFORE UPDATE ON puls_workflow.leave_documents
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_expense_receipts_set_updated_at ON puls_workflow.expense_receipts;
CREATE TRIGGER puls_workflow_expense_receipts_set_updated_at
  BEFORE UPDATE ON puls_workflow.expense_receipts
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_workflow_approval_requests_set_updated_at ON puls_workflow.approval_requests;
CREATE TRIGGER puls_workflow_approval_requests_set_updated_at
  BEFORE UPDATE ON puls_workflow.approval_requests
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security (no DELETE policies)
-- ---------------------------------------------------------------------------

ALTER TABLE puls_workflow.approval_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.approval_policy_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.leave_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.leave_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.expense_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.leave_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.expense_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.approval_requests ENABLE ROW LEVEL SECURITY;

-- Setup: approval_policies
DROP POLICY IF EXISTS puls_workflow_approval_policies_select ON puls_workflow.approval_policies;
CREATE POLICY puls_workflow_approval_policies_select ON puls_workflow.approval_policies
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_approval_policies_insert ON puls_workflow.approval_policies;
CREATE POLICY puls_workflow_approval_policies_insert ON puls_workflow.approval_policies
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_approval_policies_update ON puls_workflow.approval_policies;
CREATE POLICY puls_workflow_approval_policies_update ON puls_workflow.approval_policies
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Setup: approval_policy_steps
DROP POLICY IF EXISTS puls_workflow_approval_policy_steps_select ON puls_workflow.approval_policy_steps;
CREATE POLICY puls_workflow_approval_policy_steps_select ON puls_workflow.approval_policy_steps
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_approval_policy_steps_insert ON puls_workflow.approval_policy_steps;
CREATE POLICY puls_workflow_approval_policy_steps_insert ON puls_workflow.approval_policy_steps
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_approval_policy_steps_update ON puls_workflow.approval_policy_steps;
CREATE POLICY puls_workflow_approval_policy_steps_update ON puls_workflow.approval_policy_steps
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Setup: leave_types
DROP POLICY IF EXISTS puls_workflow_leave_types_select ON puls_workflow.leave_types;
CREATE POLICY puls_workflow_leave_types_select ON puls_workflow.leave_types
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_leave_types_insert ON puls_workflow.leave_types;
CREATE POLICY puls_workflow_leave_types_insert ON puls_workflow.leave_types
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_leave_types_update ON puls_workflow.leave_types;
CREATE POLICY puls_workflow_leave_types_update ON puls_workflow.leave_types
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Setup: expense_categories
DROP POLICY IF EXISTS puls_workflow_expense_categories_select ON puls_workflow.expense_categories;
CREATE POLICY puls_workflow_expense_categories_select ON puls_workflow.expense_categories
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_expense_categories_insert ON puls_workflow.expense_categories;
CREATE POLICY puls_workflow_expense_categories_insert ON puls_workflow.expense_categories
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_expense_categories_update ON puls_workflow.expense_categories;
CREATE POLICY puls_workflow_expense_categories_update ON puls_workflow.expense_categories
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Balances: leave_balances
DROP POLICY IF EXISTS puls_workflow_leave_balances_select ON puls_workflow.leave_balances;
CREATE POLICY puls_workflow_leave_balances_select ON puls_workflow.leave_balances
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR puls_core.is_team_member(employee_id)
    )
  );

DROP POLICY IF EXISTS puls_workflow_leave_balances_insert ON puls_workflow.leave_balances;
CREATE POLICY puls_workflow_leave_balances_insert ON puls_workflow.leave_balances
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_leave_balances_update ON puls_workflow.leave_balances;
CREATE POLICY puls_workflow_leave_balances_update ON puls_workflow.leave_balances
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Transactions: leave_requests
DROP POLICY IF EXISTS puls_workflow_leave_requests_select ON puls_workflow.leave_requests;
CREATE POLICY puls_workflow_leave_requests_select ON puls_workflow.leave_requests
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = leave_requests.employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_workflow_leave_requests_insert ON puls_workflow.leave_requests;
CREATE POLICY puls_workflow_leave_requests_insert ON puls_workflow.leave_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = puls_core.current_tenant_id()
    AND employee_id = puls_core.current_employee_id()
  );

DROP POLICY IF EXISTS puls_workflow_leave_requests_update_owner ON puls_workflow.leave_requests;
CREATE POLICY puls_workflow_leave_requests_update_owner ON puls_workflow.leave_requests
  FOR UPDATE TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND employee_id = puls_core.current_employee_id()
    AND status IN ('draft'::puls_workflow.leave_request_status, 'pending'::puls_workflow.leave_request_status)
  )
  WITH CHECK (
    tenant_id = puls_core.current_tenant_id()
    AND employee_id = puls_core.current_employee_id()
    AND status IN ('draft'::puls_workflow.leave_request_status, 'pending'::puls_workflow.leave_request_status)
  );

DROP POLICY IF EXISTS puls_workflow_leave_requests_update_admin ON puls_workflow.leave_requests;
CREATE POLICY puls_workflow_leave_requests_update_admin ON puls_workflow.leave_requests
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Transactions: expense_claims
DROP POLICY IF EXISTS puls_workflow_expense_claims_select ON puls_workflow.expense_claims;
CREATE POLICY puls_workflow_expense_claims_select ON puls_workflow.expense_claims
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = expense_claims.employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_workflow_expense_claims_insert ON puls_workflow.expense_claims;
CREATE POLICY puls_workflow_expense_claims_insert ON puls_workflow.expense_claims
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = puls_core.current_tenant_id()
    AND employee_id = puls_core.current_employee_id()
  );

DROP POLICY IF EXISTS puls_workflow_expense_claims_update_owner ON puls_workflow.expense_claims;
CREATE POLICY puls_workflow_expense_claims_update_owner ON puls_workflow.expense_claims
  FOR UPDATE TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND employee_id = puls_core.current_employee_id()
    AND status IN ('draft'::puls_workflow.expense_claim_status, 'pending'::puls_workflow.expense_claim_status)
  )
  WITH CHECK (
    tenant_id = puls_core.current_tenant_id()
    AND employee_id = puls_core.current_employee_id()
    AND status IN ('draft'::puls_workflow.expense_claim_status, 'pending'::puls_workflow.expense_claim_status)
  );

DROP POLICY IF EXISTS puls_workflow_expense_claims_update_admin ON puls_workflow.expense_claims;
CREATE POLICY puls_workflow_expense_claims_update_admin ON puls_workflow.expense_claims
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Metadata: leave_documents
DROP POLICY IF EXISTS puls_workflow_leave_documents_select ON puls_workflow.leave_documents;
CREATE POLICY puls_workflow_leave_documents_select ON puls_workflow.leave_documents
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.leave_requests lr
      WHERE lr.id = leave_documents.leave_request_id
        AND lr.tenant_id = puls_core.current_tenant_id()
        AND (
          puls_core.is_admin()
          OR lr.employee_id = puls_core.current_employee_id()
          OR EXISTS (
            SELECT 1
            FROM puls_core.employees e
            WHERE e.id = lr.employee_id
              AND e.manager_employee_id = puls_core.current_employee_id()
          )
        )
    )
  );

DROP POLICY IF EXISTS puls_workflow_leave_documents_insert ON puls_workflow.leave_documents;
CREATE POLICY puls_workflow_leave_documents_insert ON puls_workflow.leave_documents
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = puls_core.current_tenant_id()
    AND uploaded_by_employee_id = puls_core.current_employee_id()
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.leave_requests lr
      WHERE lr.id = leave_documents.leave_request_id
        AND lr.tenant_id = leave_documents.tenant_id
        AND lr.employee_id = puls_core.current_employee_id()
    )
  );

DROP POLICY IF EXISTS puls_workflow_leave_documents_update ON puls_workflow.leave_documents;
CREATE POLICY puls_workflow_leave_documents_update ON puls_workflow.leave_documents
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Metadata: expense_receipts
DROP POLICY IF EXISTS puls_workflow_expense_receipts_select ON puls_workflow.expense_receipts;
CREATE POLICY puls_workflow_expense_receipts_select ON puls_workflow.expense_receipts
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.expense_claims ec
      WHERE ec.id = expense_receipts.expense_claim_id
        AND ec.tenant_id = puls_core.current_tenant_id()
        AND (
          puls_core.is_admin()
          OR ec.employee_id = puls_core.current_employee_id()
          OR EXISTS (
            SELECT 1
            FROM puls_core.employees e
            WHERE e.id = ec.employee_id
              AND e.manager_employee_id = puls_core.current_employee_id()
          )
        )
    )
  );

DROP POLICY IF EXISTS puls_workflow_expense_receipts_insert ON puls_workflow.expense_receipts;
CREATE POLICY puls_workflow_expense_receipts_insert ON puls_workflow.expense_receipts
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = puls_core.current_tenant_id()
    AND uploaded_by_employee_id = puls_core.current_employee_id()
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.expense_claims ec
      WHERE ec.id = expense_receipts.expense_claim_id
        AND ec.tenant_id = expense_receipts.tenant_id
        AND ec.employee_id = puls_core.current_employee_id()
    )
  );

DROP POLICY IF EXISTS puls_workflow_expense_receipts_update ON puls_workflow.expense_receipts;
CREATE POLICY puls_workflow_expense_receipts_update ON puls_workflow.expense_receipts
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- Approvals: approval_requests
DROP POLICY IF EXISTS puls_workflow_approval_requests_select ON puls_workflow.approval_requests;
CREATE POLICY puls_workflow_approval_requests_select ON puls_workflow.approval_requests
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR requester_employee_id = puls_core.current_employee_id()
      OR approver_employee_id = puls_core.current_employee_id()
      OR EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = approval_requests.requester_employee_id
          AND e.manager_employee_id = puls_core.current_employee_id()
          AND e.tenant_id = puls_core.current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS puls_workflow_approval_requests_insert ON puls_workflow.approval_requests;
CREATE POLICY puls_workflow_approval_requests_insert ON puls_workflow.approval_requests
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_workflow_approval_requests_update ON puls_workflow.approval_requests;
CREATE POLICY puls_workflow_approval_requests_update ON puls_workflow.approval_requests
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT USAGE ON SCHEMA puls_workflow TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA puls_workflow TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA puls_workflow TO service_role;

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
  v_leave_policy UUID;
  v_expense_policy UUID;
  v_leave_type_annual UUID;
  v_leave_type_sick UUID;
  v_leave_type_excuse UUID;
  v_cat_meal UUID;
  v_cat_transport UUID;
  v_cat_travel UUID;
  v_cat_accommodation UUID;
  v_cat_representation UUID;
  v_cat_training UUID;
  v_cat_office UUID;
  v_lr_pending_1 UUID;
  v_lr_pending_2 UUID;
  v_ec_pending_1 UUID;
  v_ec_pending_2 UUID;
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
    WHERE e.tenant_id = v_tenant_id
      AND e.email = 'demo@mertteknik.local'
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

  -- Approval policies
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, description)
  VALUES
    (v_tenant_id, 'leave_manager_approval', 'İzin — Yönetici Onayı', 'leave', 'Demo: tek adım yönetici onayı'),
    (v_tenant_id, 'expense_manager_approval', 'Masraf — Yönetici Onayı', 'expense', 'Demo: tek adım yönetici onayı')
  ON CONFLICT (tenant_id, code) DO UPDATE SET
    name = EXCLUDED.name,
    module = EXCLUDED.module,
    description = EXCLUDED.description,
    updated_at = NOW();

  SELECT id INTO v_leave_policy
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'leave_manager_approval';

  SELECT id INTO v_expense_policy
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'expense_manager_approval';

  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type
  )
  VALUES
    (v_tenant_id, v_leave_policy, 1, 'manager'),
    (v_tenant_id, v_expense_policy, 1, 'manager')
  ON CONFLICT (policy_id, step_order) DO UPDATE SET
    approver_type = EXCLUDED.approver_type,
    updated_at = NOW();

  -- Leave types (8)
  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, is_paid, default_entitlement_days,
    requires_document, carry_over_allowed, max_carry_over_days, approval_policy_id
  )
  VALUES
    (v_tenant_id, 'annual', 'Yıllık İzin', TRUE, 20, FALSE, TRUE, 5, v_leave_policy),
    (v_tenant_id, 'sick', 'Hastalık İzni', TRUE, 10, TRUE, FALSE, NULL, v_leave_policy),
    (v_tenant_id, 'excuse', 'Mazeret İzni', TRUE, 10, FALSE, FALSE, NULL, v_leave_policy),
    (v_tenant_id, 'maternity', 'Doğum İzni', TRUE, NULL, TRUE, FALSE, NULL, v_leave_policy),
    (v_tenant_id, 'marriage', 'Evlilik İzni', TRUE, 3, FALSE, FALSE, NULL, v_leave_policy),
    (v_tenant_id, 'bereavement', 'Ölüm İzni', TRUE, 3, FALSE, FALSE, NULL, v_leave_policy),
    (v_tenant_id, 'unpaid', 'Ücretsiz İzin', FALSE, NULL, FALSE, FALSE, NULL, v_leave_policy),
    (v_tenant_id, 'compensatory', 'Telafi İzni', TRUE, NULL, FALSE, FALSE, NULL, v_leave_policy)
  ON CONFLICT (tenant_id, code) DO UPDATE SET
    name = EXCLUDED.name,
    is_paid = EXCLUDED.is_paid,
    default_entitlement_days = EXCLUDED.default_entitlement_days,
    requires_document = EXCLUDED.requires_document,
    carry_over_allowed = EXCLUDED.carry_over_allowed,
    max_carry_over_days = EXCLUDED.max_carry_over_days,
    approval_policy_id = EXCLUDED.approval_policy_id,
    updated_at = NOW();

  SELECT id INTO v_leave_type_annual FROM puls_workflow.leave_types WHERE tenant_id = v_tenant_id AND code = 'annual';
  SELECT id INTO v_leave_type_sick FROM puls_workflow.leave_types WHERE tenant_id = v_tenant_id AND code = 'sick';
  SELECT id INTO v_leave_type_excuse FROM puls_workflow.leave_types WHERE tenant_id = v_tenant_id AND code = 'excuse';

  -- Expense categories (7)
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, approval_policy_id
  )
  VALUES
    (v_tenant_id, 'travel', 'Seyahat', 15000, 0, '760.01', v_expense_policy),
    (v_tenant_id, 'accommodation', 'Konaklama', 15000, 0, '760.02', v_expense_policy),
    (v_tenant_id, 'meal', 'Yemek', 5000, 0, '760.03', v_expense_policy),
    (v_tenant_id, 'representation', 'Temsil', 8000, 500, '760.04', v_expense_policy),
    (v_tenant_id, 'training', 'Eğitim', 10000, 0, '760.05', v_expense_policy),
    (v_tenant_id, 'office', 'Ofis', 3000, 0, '760.06', v_expense_policy),
    (v_tenant_id, 'transportation', 'Ulaşım', 5000, 0, '760.07', v_expense_policy)
  ON CONFLICT (tenant_id, code) DO UPDATE SET
    name = EXCLUDED.name,
    monthly_limit = EXCLUDED.monthly_limit,
    receipt_required_over = EXCLUDED.receipt_required_over,
    erp_account_code = EXCLUDED.erp_account_code,
    approval_policy_id = EXCLUDED.approval_policy_id,
    updated_at = NOW();

  SELECT id INTO v_cat_meal FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant_id AND code = 'meal';
  SELECT id INTO v_cat_transport FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant_id AND code = 'transportation';
  SELECT id INTO v_cat_travel FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant_id AND code = 'travel';
  SELECT id INTO v_cat_accommodation FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant_id AND code = 'accommodation';
  SELECT id INTO v_cat_representation FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant_id AND code = 'representation';
  SELECT id INTO v_cat_training FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant_id AND code = 'training';
  SELECT id INTO v_cat_office FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant_id AND code = 'office';

  -- Leave balances 2026
  INSERT INTO puls_workflow.leave_balances (
    tenant_id, employee_id, leave_type_id, period_year,
    entitlement_days, carried_over_days, adjustment_days, used_days, pending_days
  )
  SELECT v_tenant_id, e.id, v_leave_type_annual, 2026, 20, 0, 0, 6, 0
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.id IN (v_demo_ik, v_emp_4403, v_emp_4404, v_emp_4405)
  ON CONFLICT (tenant_id, employee_id, leave_type_id, period_year) DO UPDATE SET
    entitlement_days = EXCLUDED.entitlement_days,
    carried_over_days = EXCLUDED.carried_over_days,
    adjustment_days = EXCLUDED.adjustment_days,
    used_days = EXCLUDED.used_days,
    pending_days = EXCLUDED.pending_days,
    updated_at = NOW();

  INSERT INTO puls_workflow.leave_balances (
    tenant_id, employee_id, leave_type_id, period_year,
    entitlement_days, carried_over_days, adjustment_days, used_days, pending_days
  )
  VALUES
    (v_tenant_id, v_demo_ik, v_leave_type_sick, 2026, 10, 0, 0, 0, 0),
    (v_tenant_id, v_demo_ik, v_leave_type_excuse, 2026, 10, 0, 0, 3, 0)
  ON CONFLICT (tenant_id, employee_id, leave_type_id, period_year) DO UPDATE SET
    entitlement_days = EXCLUDED.entitlement_days,
    carried_over_days = EXCLUDED.carried_over_days,
    adjustment_days = EXCLUDED.adjustment_days,
    used_days = EXCLUDED.used_days,
    pending_days = EXCLUDED.pending_days,
    updated_at = NOW();

  -- Leave requests: 4 for demo IK (2 approved + 2 pending), 2 approved for others
  INSERT INTO puls_workflow.leave_requests (
    tenant_id, employee_id, leave_type_id, start_date, end_date, business_days,
    description, status, submitted_at, approved_at,
    external_source, external_request_id
  )
  VALUES
    (v_tenant_id, v_demo_ik, v_leave_type_annual, '2026-03-10', '2026-03-14', 5,
     'Bahar izni', 'approved', '2026-03-01'::timestamptz, '2026-03-02'::timestamptz,
     'puls_demo_seed', 'lr-ik-approved-1'),
    (v_tenant_id, v_demo_ik, v_leave_type_annual, '2026-01-20', '2026-01-21', 2,
     'Kişisel izin', 'approved', '2026-01-15'::timestamptz, '2026-01-16'::timestamptz,
     'puls_demo_seed', 'lr-ik-approved-2'),
    (v_tenant_id, v_demo_ik, v_leave_type_annual, '2026-07-14', '2026-07-18', 5,
     'Yaz izni', 'pending', '2026-05-10'::timestamptz, NULL,
     'puls_demo_seed', 'lr-ik-pending-1'),
    (v_tenant_id, v_demo_ik, v_leave_type_excuse, '2026-05-22', '2026-05-22', 1,
     'Resmi işlem', 'pending', '2026-05-18'::timestamptz, NULL,
     'puls_demo_seed', 'lr-ik-pending-2')
  ON CONFLICT (tenant_id, external_source, external_request_id)
    WHERE external_source IS NOT NULL AND external_request_id IS NOT NULL
  DO UPDATE SET
    status = EXCLUDED.status,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    business_days = EXCLUDED.business_days,
    description = EXCLUDED.description,
    submitted_at = EXCLUDED.submitted_at,
    approved_at = EXCLUDED.approved_at,
    updated_at = NOW();

  IF v_emp_4403 IS NOT NULL THEN
    INSERT INTO puls_workflow.leave_requests (
      tenant_id, employee_id, leave_type_id, start_date, end_date, business_days,
      description, status, submitted_at, approved_at,
      external_source, external_request_id
    )
    VALUES
      (v_tenant_id, v_emp_4403, v_leave_type_annual, '2026-06-02', '2026-06-06', 5,
       'Üretim planlı izin', 'approved', '2026-05-20'::timestamptz, '2026-05-21'::timestamptz,
       'puls_demo_seed', 'lr-emp4403-approved-1')
    ON CONFLICT (tenant_id, external_source, external_request_id)
      WHERE external_source IS NOT NULL AND external_request_id IS NOT NULL
    DO UPDATE SET status = EXCLUDED.status, updated_at = NOW();
  END IF;

  IF v_emp_4404 IS NOT NULL THEN
    INSERT INTO puls_workflow.leave_requests (
      tenant_id, employee_id, leave_type_id, start_date, end_date, business_days,
      description, status, submitted_at, approved_at,
      external_source, external_request_id
    )
    VALUES
      (v_tenant_id, v_emp_4404, v_leave_type_annual, '2026-08-11', '2026-08-15', 5,
       'Yıllık izin', 'approved', '2026-05-01'::timestamptz, '2026-05-02'::timestamptz,
       'puls_demo_seed', 'lr-emp4404-approved-1')
    ON CONFLICT (tenant_id, external_source, external_request_id)
      WHERE external_source IS NOT NULL AND external_request_id IS NOT NULL
    DO UPDATE SET status = EXCLUDED.status, updated_at = NOW();
  END IF;

  SELECT id INTO v_lr_pending_1
  FROM puls_workflow.leave_requests
  WHERE tenant_id = v_tenant_id AND external_source = 'puls_demo_seed' AND external_request_id = 'lr-ik-pending-1';

  SELECT id INTO v_lr_pending_2
  FROM puls_workflow.leave_requests
  WHERE tenant_id = v_tenant_id AND external_source = 'puls_demo_seed' AND external_request_id = 'lr-ik-pending-2';

  -- Expense claims: 8 for demo IK
  INSERT INTO puls_workflow.expense_claims (
    tenant_id, employee_id, category_id, amount, currency, vat_rate, vat_included,
    expense_date, title, description, policy_status, status,
    submitted_at, approved_at, rejected_at, exported_at,
    external_source, external_claim_id
  )
  VALUES
    (v_tenant_id, v_demo_ik, v_cat_meal, 450.00, 'TRY', 10, TRUE,
     '2026-05-15', 'İş yemeği', 'Müşteri toplantısı', 'compliant', 'pending',
     '2026-05-15'::timestamptz, NULL, NULL, NULL,
     'puls_demo_seed', 'ec-pending-meal'),
    (v_tenant_id, v_demo_ik, v_cat_representation, 1890.00, 'TRY', 20, TRUE,
     '2026-05-12', 'Ulaşım / temsil', 'Ankara ziyareti', 'compliant', 'pending',
     '2026-05-12'::timestamptz, NULL, NULL, NULL,
     'puls_demo_seed', 'ec-pending-transport'),
    (v_tenant_id, v_demo_ik, v_cat_travel, 2000.00, 'TRY', 20, TRUE,
     '2026-05-08', 'İstanbul-Ankara uçak', 'Müşteri ziyareti', 'compliant', 'approved',
     '2026-05-08'::timestamptz, '2026-05-09'::timestamptz, NULL, NULL,
     'puls_demo_seed', 'ec-approved-1'),
    (v_tenant_id, v_demo_ik, v_cat_accommodation, 2040.00, 'TRY', 20, TRUE,
     '2026-05-09', 'Ankara otel', '1 gece konaklama', 'compliant', 'approved',
     '2026-05-09'::timestamptz, '2026-05-10'::timestamptz, NULL, NULL,
     'puls_demo_seed', 'ec-approved-2'),
    (v_tenant_id, v_demo_ik, v_cat_training, 2300.00, 'TRY', 20, TRUE,
     '2026-05-05', 'İK eğitimi', 'Online sertifika', 'compliant', 'approved',
     '2026-05-05'::timestamptz, '2026-05-06'::timestamptz, NULL, NULL,
     'puls_demo_seed', 'ec-approved-3'),
    (v_tenant_id, v_demo_ik, v_cat_office, 2300.00, 'TRY', 20, TRUE,
     '2026-05-03', 'Ofis malzemesi', 'Kırtasiye', 'compliant', 'approved',
     '2026-05-03'::timestamptz, '2026-05-04'::timestamptz, NULL, NULL,
     'puls_demo_seed', 'ec-approved-4'),
    (v_tenant_id, v_demo_ik, v_cat_transport, 1500.00, 'TRY', 20, TRUE,
     '2026-04-20', 'Taksi', 'Geç saat servisi', 'warning', 'rejected',
     '2026-04-20'::timestamptz, NULL, '2026-04-22'::timestamptz, NULL,
     'puls_demo_seed', 'ec-rejected-1'),
    (v_tenant_id, v_demo_ik, v_cat_travel, 21720.00, 'TRY', 20, TRUE,
     '2026-03-15', 'Yıllık seyahat paketi', 'ERP aktarımı', 'compliant', 'exported',
     '2026-03-10'::timestamptz, '2026-03-12'::timestamptz, NULL, '2026-03-20'::timestamptz,
     'puls_demo_seed', 'ec-exported-1')
  ON CONFLICT (tenant_id, external_source, external_claim_id)
    WHERE external_source IS NOT NULL AND external_claim_id IS NOT NULL
  DO UPDATE SET
    amount = EXCLUDED.amount,
    status = EXCLUDED.status,
    expense_date = EXCLUDED.expense_date,
    approved_at = EXCLUDED.approved_at,
    rejected_at = EXCLUDED.rejected_at,
    exported_at = EXCLUDED.exported_at,
    updated_at = NOW();

  SELECT id INTO v_ec_pending_1
  FROM puls_workflow.expense_claims
  WHERE tenant_id = v_tenant_id AND external_source = 'puls_demo_seed' AND external_claim_id = 'ec-pending-meal';

  SELECT id INTO v_ec_pending_2
  FROM puls_workflow.expense_claims
  WHERE tenant_id = v_tenant_id AND external_source = 'puls_demo_seed' AND external_claim_id = 'ec-pending-transport';

  -- Approval requests for pending leave + expense
  IF v_demo_manager IS NOT NULL THEN
    IF v_lr_pending_1 IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM puls_workflow.approval_requests ar
      WHERE ar.leave_request_id = v_lr_pending_1 AND ar.step_order = 1
    ) THEN
      INSERT INTO puls_workflow.approval_requests (
        tenant_id, module, leave_request_id, requester_employee_id,
        approver_employee_id, step_order, status
      )
      VALUES (
        v_tenant_id, 'leave', v_lr_pending_1, v_demo_ik,
        v_demo_manager, 1, 'pending'
      );
    END IF;

    IF v_lr_pending_2 IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM puls_workflow.approval_requests ar
      WHERE ar.leave_request_id = v_lr_pending_2 AND ar.step_order = 1
    ) THEN
      INSERT INTO puls_workflow.approval_requests (
        tenant_id, module, leave_request_id, requester_employee_id,
        approver_employee_id, step_order, status
      )
      VALUES (
        v_tenant_id, 'leave', v_lr_pending_2, v_demo_ik,
        v_demo_manager, 1, 'pending'
      );
    END IF;

    IF v_ec_pending_1 IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM puls_workflow.approval_requests ar
      WHERE ar.expense_claim_id = v_ec_pending_1 AND ar.step_order = 1
    ) THEN
      INSERT INTO puls_workflow.approval_requests (
        tenant_id, module, expense_claim_id, requester_employee_id,
        approver_employee_id, step_order, status
      )
      VALUES (
        v_tenant_id, 'expense', v_ec_pending_1, v_demo_ik,
        v_demo_manager, 1, 'pending'
      );
    END IF;

    IF v_ec_pending_2 IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM puls_workflow.approval_requests ar
      WHERE ar.expense_claim_id = v_ec_pending_2 AND ar.step_order = 1
    ) THEN
      INSERT INTO puls_workflow.approval_requests (
        tenant_id, module, expense_claim_id, requester_employee_id,
        approver_employee_id, step_order, status
      )
      VALUES (
        v_tenant_id, 'expense', v_ec_pending_2, v_demo_ik,
        v_demo_manager, 1, 'pending'
      );
    END IF;
  END IF;
END $$;
