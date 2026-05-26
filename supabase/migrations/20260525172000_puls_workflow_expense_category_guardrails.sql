-- 10 PR10.5 — Expense category setup guardrails (validation trigger + partial unique index)
-- PULS setup guardrails only. No ERP/pre-accounting writes.
-- No resolver/decide/import changes. No UI changes.

-- ---------------------------------------------------------------------------
-- Normalization helper (BTRIM only; no silent lowercase on code)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._normalize_expense_category_text(p_value TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, puls_workflow
AS $$
  SELECT NULLIF(BTRIM(p_value), '');
$$;

-- ---------------------------------------------------------------------------
-- Guardrail trigger (SECURITY DEFINER; full-row BEFORE INSERT OR UPDATE)
-- DB does not silently lowercase code; it trims and rejects non-canonical values.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.validate_expense_category_guardrails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_name TEXT;
  v_code TEXT;
  v_account_code TEXT;
BEGIN
  v_name := puls_workflow._normalize_expense_category_text(NEW.name);
  v_code := puls_workflow._normalize_expense_category_text(NEW.code);
  v_account_code := puls_workflow._normalize_expense_category_text(NEW.erp_account_code);

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_NAME_REQUIRED: name is required.';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_CODE_REQUIRED: code is required.';
  END IF;

  IF v_code !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_CODE_INVALID: code must be lowercase slug.';
  END IF;

  IF NEW.monthly_limit IS NOT NULL AND NEW.monthly_limit < 0 THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_MONTHLY_LIMIT_INVALID: monthly_limit must be non-negative.';
  END IF;

  IF NEW.receipt_required_over IS NOT NULL AND NEW.receipt_required_over < 0 THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_RECEIPT_THRESHOLD_INVALID: receipt_required_over must be non-negative.';
  END IF;

  IF NEW.default_vat_rate IS NOT NULL AND (NEW.default_vat_rate < 0 OR NEW.default_vat_rate > 100) THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_VAT_INVALID: default_vat_rate must be between 0 and 100.';
  END IF;

  IF v_account_code IS NOT NULL AND v_account_code !~ '^[0-9]{3}(\.[0-9]{2})?$' THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_ACCOUNT_CODE_INVALID: erp_account_code format is invalid.';
  END IF;

  NEW.name := v_name;
  NEW.code := v_code;
  NEW.erp_account_code := v_account_code;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_workflow_expense_categories_validate_guardrails
  ON puls_workflow.expense_categories;

CREATE TRIGGER puls_workflow_expense_categories_validate_guardrails
  BEFORE INSERT OR UPDATE
  ON puls_workflow.expense_categories
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.validate_expense_category_guardrails();

-- ---------------------------------------------------------------------------
-- Active accounting-code uniqueness (tenant scoped; nulls allowed)
-- ---------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_workflow_expense_categories_active_account_code_unique
  ON puls_workflow.expense_categories (tenant_id, erp_account_code)
  WHERE is_active = TRUE AND erp_account_code IS NOT NULL;

-- ---------------------------------------------------------------------------
-- REVOKE / GRANT (internal validation surface; not callable from UI)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow._normalize_expense_category_text(TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow.validate_expense_category_guardrails() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_workflow._normalize_expense_category_text(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.validate_expense_category_guardrails() TO service_role;
