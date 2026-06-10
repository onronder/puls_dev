-- PR17.2F1: workflow evidence upload backend boundary.
-- Adds a private storage/RLS/RPC staging model for leave, expense, and contract
-- evidence without changing browser forms, OCR, external delivery, or canonical
-- workflow submit behavior.

DO $$
BEGIN
  CREATE TYPE puls_workflow.evidence_upload_domain AS ENUM ('leave', 'expense', 'contract');
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

DO $$
BEGIN
  CREATE TYPE puls_workflow.evidence_upload_status AS ENUM (
    'intent_created',
    'uploaded',
    'attached',
    'expired',
    'rejected',
    'deleted'
  );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

DO $$
BEGIN
  CREATE TYPE puls_workflow.evidence_scan_status AS ENUM (
    'not_scanned',
    'blocked'
  );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'workflow-evidence',
  'workflow-evidence',
  FALSE,
  15728640,
  ARRAY['application/pdf', 'image/png', 'image/jpeg']::TEXT[]
)
ON CONFLICT (id) DO UPDATE
SET
  public = FALSE,
  file_size_limit = 15728640,
  allowed_mime_types = ARRAY['application/pdf', 'image/png', 'image/jpeg']::TEXT[];

CREATE TABLE IF NOT EXISTS puls_workflow.evidence_uploads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  owner_employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE RESTRICT,
  domain puls_workflow.evidence_upload_domain NOT NULL,
  storage_bucket TEXT NOT NULL DEFAULT 'workflow-evidence',
  storage_path TEXT NOT NULL,
  original_file_name TEXT NOT NULL,
  file_extension TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  file_size_bytes BIGINT NOT NULL,
  sha256_client TEXT NULL,
  status puls_workflow.evidence_upload_status NOT NULL DEFAULT 'intent_created',
  scan_status puls_workflow.evidence_scan_status NOT NULL DEFAULT 'not_scanned',
  subject_table TEXT NULL,
  subject_id UUID NULL,
  attached_table TEXT NULL,
  attached_id UUID NULL,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
  uploaded_at TIMESTAMPTZ NULL,
  attached_at TIMESTAMPTZ NULL,
  rejected_at TIMESTAMPTZ NULL,
  deleted_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (storage_bucket = 'workflow-evidence'),
  CHECK (file_size_bytes > 0),
  CHECK (file_size_bytes <= 15728640),
  CHECK (original_file_name = BTRIM(original_file_name)),
  CHECK (original_file_name <> ''),
  CHECK (file_extension IN ('pdf', 'png', 'jpg', 'jpeg')),
  CHECK (
    (mime_type = 'application/pdf' AND file_extension = 'pdf')
    OR (mime_type = 'image/png' AND file_extension = 'png')
    OR (mime_type = 'image/jpeg' AND file_extension IN ('jpg', 'jpeg'))
  ),
  CHECK (sha256_client IS NULL OR sha256_client ~ '^[a-fA-F0-9]{64}$'),
  CHECK (
    (domain IN ('leave'::puls_workflow.evidence_upload_domain, 'expense'::puls_workflow.evidence_upload_domain) AND subject_table IS NULL AND subject_id IS NULL)
    OR (domain = 'contract'::puls_workflow.evidence_upload_domain AND subject_table = 'puls_workflow.contracts' AND subject_id IS NOT NULL)
    OR (status = 'attached'::puls_workflow.evidence_upload_status AND subject_table IS NOT NULL AND subject_id IS NOT NULL)
  ),
  CHECK (
    (status = 'attached'::puls_workflow.evidence_upload_status AND attached_table IS NOT NULL AND attached_id IS NOT NULL AND attached_at IS NOT NULL)
    OR (status <> 'attached'::puls_workflow.evidence_upload_status AND attached_table IS NULL AND attached_id IS NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS evidence_uploads_storage_path_idx
  ON puls_workflow.evidence_uploads (storage_bucket, storage_path);

CREATE INDEX IF NOT EXISTS evidence_uploads_owner_status_idx
  ON puls_workflow.evidence_uploads (tenant_id, owner_employee_id, status);

CREATE INDEX IF NOT EXISTS evidence_uploads_subject_idx
  ON puls_workflow.evidence_uploads (tenant_id, subject_table, subject_id)
  WHERE subject_table IS NOT NULL AND subject_id IS NOT NULL;

DROP TRIGGER IF EXISTS evidence_uploads_set_updated_at ON puls_workflow.evidence_uploads;
CREATE TRIGGER evidence_uploads_set_updated_at
  BEFORE UPDATE ON puls_workflow.evidence_uploads
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

ALTER TABLE puls_workflow.evidence_uploads ENABLE ROW LEVEL SECURITY;

ALTER TABLE puls_workflow.contract_files
  ADD COLUMN IF NOT EXISTS uploaded_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL;

COMMENT ON COLUMN puls_workflow.contract_files.metadata_only
  IS 'True means the database stores file metadata only; binary content lives in the private workflow-evidence storage bucket.';

COMMENT ON TABLE puls_workflow.evidence_uploads
  IS 'PR17.2F1 staging table for workflow evidence upload intents. Binary content is private storage; rows contain safe metadata only.';

CREATE OR REPLACE FUNCTION puls_workflow._workflow_evidence_extension_for_mime(
  p_mime_type TEXT
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE p_mime_type
    WHEN 'application/pdf' THEN 'pdf'
    WHEN 'image/png' THEN 'png'
    WHEN 'image/jpeg' THEN 'jpg'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow._workflow_evidence_max_bytes(
  p_domain puls_workflow.evidence_upload_domain
)
RETURNS BIGINT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, puls_workflow
AS $$
  SELECT CASE p_domain
    WHEN 'contract'::puls_workflow.evidence_upload_domain THEN 15728640::BIGINT
    ELSE 10485760::BIGINT
  END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow._workflow_evidence_is_assigned_approver(
  p_domain puls_workflow.evidence_upload_domain,
  p_subject_id UUID,
  p_employee_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
  SELECT CASE
    WHEN p_domain = 'leave'::puls_workflow.evidence_upload_domain THEN EXISTS (
      SELECT 1
      FROM puls_workflow.approval_requests ar
      WHERE ar.leave_request_id = p_subject_id
        AND ar.approver_employee_id = p_employee_id
    )
    WHEN p_domain = 'expense'::puls_workflow.evidence_upload_domain THEN EXISTS (
      SELECT 1
      FROM puls_workflow.approval_requests ar
      WHERE ar.expense_claim_id = p_subject_id
        AND ar.approver_employee_id = p_employee_id
    )
    ELSE FALSE
  END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.can_upload_workflow_evidence_storage_object(
  p_storage_path TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_workflow.evidence_uploads upload
    WHERE upload.storage_bucket = 'workflow-evidence'
      AND upload.storage_path = p_storage_path
      AND upload.tenant_id = puls_core.current_tenant_id()
      AND upload.owner_employee_id = puls_core.current_employee_id()
      AND upload.status = 'intent_created'::puls_workflow.evidence_upload_status
      AND upload.expires_at > NOW()
  );
$$;

CREATE OR REPLACE FUNCTION puls_workflow.can_read_workflow_evidence_storage_object(
  p_storage_path TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_workflow.evidence_uploads upload
    WHERE upload.storage_bucket = 'workflow-evidence'
      AND upload.storage_path = p_storage_path
      AND upload.tenant_id = puls_core.current_tenant_id()
      AND upload.status IN (
        'uploaded'::puls_workflow.evidence_upload_status,
        'attached'::puls_workflow.evidence_upload_status
      )
      AND (
        puls_core.is_admin()
        OR upload.owner_employee_id = puls_core.current_employee_id()
        OR (
          upload.status = 'attached'::puls_workflow.evidence_upload_status
          AND upload.domain = 'leave'::puls_workflow.evidence_upload_domain
          AND EXISTS (
            SELECT 1
            FROM puls_workflow.leave_requests lr
            WHERE lr.id = upload.subject_id
              AND lr.tenant_id = upload.tenant_id
              AND (
                lr.employee_id = puls_core.current_employee_id()
                OR EXISTS (
                  SELECT 1
                  FROM puls_core.employees e
                  WHERE e.id = lr.employee_id
                    AND e.manager_employee_id = puls_core.current_employee_id()
                )
                OR puls_workflow._workflow_evidence_is_assigned_approver(
                  'leave'::puls_workflow.evidence_upload_domain,
                  lr.id,
                  puls_core.current_employee_id()
                )
              )
          )
        )
        OR (
          upload.status = 'attached'::puls_workflow.evidence_upload_status
          AND upload.domain = 'expense'::puls_workflow.evidence_upload_domain
          AND EXISTS (
            SELECT 1
            FROM puls_workflow.expense_claims ec
            WHERE ec.id = upload.subject_id
              AND ec.tenant_id = upload.tenant_id
              AND (
                ec.employee_id = puls_core.current_employee_id()
                OR EXISTS (
                  SELECT 1
                  FROM puls_core.employees e
                  WHERE e.id = ec.employee_id
                    AND e.manager_employee_id = puls_core.current_employee_id()
                )
                OR puls_workflow._workflow_evidence_is_assigned_approver(
                  'expense'::puls_workflow.evidence_upload_domain,
                  ec.id,
                  puls_core.current_employee_id()
                )
              )
          )
        )
        OR (
          upload.status = 'attached'::puls_workflow.evidence_upload_status
          AND upload.domain = 'contract'::puls_workflow.evidence_upload_domain
          AND EXISTS (
            SELECT 1
            FROM puls_workflow.contracts c
            WHERE c.id = upload.subject_id
              AND c.tenant_id = upload.tenant_id
              AND c.employee_id = puls_core.current_employee_id()
          )
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION puls_workflow.create_workflow_evidence_upload_intent(
  p_domain TEXT,
  p_original_file_name TEXT,
  p_mime_type TEXT,
  p_file_size_bytes BIGINT,
  p_sha256_client TEXT DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_domain puls_workflow.evidence_upload_domain;
  v_original_file_name TEXT := BTRIM(COALESCE(p_original_file_name, ''));
  v_mime_type TEXT := LOWER(BTRIM(COALESCE(p_mime_type, '')));
  v_extension TEXT;
  v_max_bytes BIGINT;
  v_upload_id UUID := gen_random_uuid();
  v_storage_path TEXT;
  v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '24 hours';
BEGIN
  IF auth.uid() IS NULL OR v_tenant_id IS NULL OR v_employee_id IS NULL THEN
    RAISE EXCEPTION 'PULS_AUTH_REQUIRED: Authentication required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_domain, '') NOT IN ('leave', 'expense', 'contract') THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_DOMAIN_INVALID: Evidence domain is invalid.'
      USING ERRCODE = 'P0001';
  END IF;
  v_domain := p_domain::puls_workflow.evidence_upload_domain;

  IF v_original_file_name = '' OR length(v_original_file_name) > 180 THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_FILE_NAME_INVALID: File name is required.'
      USING ERRCODE = 'P0001';
  END IF;

  v_extension := puls_workflow._workflow_evidence_extension_for_mime(v_mime_type);
  IF v_extension IS NULL THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_MIME_TYPE_INVALID: File type is not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_domain = 'contract'::puls_workflow.evidence_upload_domain AND v_mime_type <> 'application/pdf' THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_CONTRACT_PDF_REQUIRED: Contract evidence must be PDF in this release.'
      USING ERRCODE = 'P0001';
  END IF;

  v_max_bytes := puls_workflow._workflow_evidence_max_bytes(v_domain);
  IF p_file_size_bytes IS NULL OR p_file_size_bytes <= 0 OR p_file_size_bytes > v_max_bytes THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_FILE_SIZE_INVALID: File size exceeds the allowed limit.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_sha256_client IS NOT NULL AND p_sha256_client !~ '^[a-fA-F0-9]{64}$' THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_SHA256_INVALID: Client hash metadata must be a SHA-256 hex value.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_domain = 'contract'::puls_workflow.evidence_upload_domain THEN
    IF p_subject_id IS NULL OR NOT puls_core.is_admin() THEN
      RAISE EXCEPTION 'PULS_EVIDENCE_CONTRACT_ADMIN_REQUIRED: Contract evidence requires an admin and contract id.'
        USING ERRCODE = 'P0001';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM puls_workflow.contracts c
      WHERE c.id = p_subject_id
        AND c.tenant_id = v_tenant_id
    ) THEN
      RAISE EXCEPTION 'PULS_EVIDENCE_CONTRACT_NOT_FOUND: Contract was not found.'
        USING ERRCODE = 'P0001';
    END IF;
  ELSIF p_subject_id IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_SUBJECT_NOT_ALLOWED: Leave and expense evidence is attached during submit.'
      USING ERRCODE = 'P0001';
  END IF;

  v_storage_path := v_tenant_id::TEXT || '/' || v_domain::TEXT || '/' || v_upload_id::TEXT || '/evidence.' || v_extension;

  INSERT INTO puls_workflow.evidence_uploads (
    id,
    tenant_id,
    owner_employee_id,
    domain,
    storage_bucket,
    storage_path,
    original_file_name,
    file_extension,
    mime_type,
    file_size_bytes,
    sha256_client,
    status,
    scan_status,
    subject_table,
    subject_id,
    expires_at
  )
  VALUES (
    v_upload_id,
    v_tenant_id,
    v_employee_id,
    v_domain,
    'workflow-evidence',
    v_storage_path,
    v_original_file_name,
    v_extension,
    v_mime_type,
    p_file_size_bytes,
    LOWER(p_sha256_client),
    'intent_created'::puls_workflow.evidence_upload_status,
    'not_scanned'::puls_workflow.evidence_scan_status,
    CASE WHEN v_domain = 'contract'::puls_workflow.evidence_upload_domain THEN 'puls_workflow.contracts' ELSE NULL END,
    CASE WHEN v_domain = 'contract'::puls_workflow.evidence_upload_domain THEN p_subject_id ELSE NULL END,
    v_expires_at
  );

  PERFORM puls_workflow.write_audit_log(
    v_tenant_id,
    v_employee_id,
    'workflow_evidence.intent_created',
    'evidence_uploads',
    v_upload_id,
    jsonb_build_object(
      'domain', v_domain::TEXT,
      'mime_type', v_mime_type,
      'file_extension', v_extension,
      'file_size_bytes', p_file_size_bytes,
      'sha256_client_present', p_sha256_client IS NOT NULL,
      'server_generated_storage_path', TRUE,
      'scan_status', 'not_scanned',
      'expires_at', v_expires_at
    )
  );

  RETURN jsonb_build_object(
    'evidence_upload_id', v_upload_id,
    'storage_bucket', 'workflow-evidence',
    'storage_path', v_storage_path,
    'expires_at', v_expires_at,
    'max_file_size_bytes', v_max_bytes,
    'mime_type', v_mime_type,
    'scan_status', 'not_scanned'
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.finalize_workflow_evidence_upload(
  p_evidence_upload_id UUID,
  p_file_size_bytes BIGINT,
  p_mime_type TEXT,
  p_sha256_client TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit, storage
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_upload puls_workflow.evidence_uploads%ROWTYPE;
  v_mime_type TEXT := LOWER(BTRIM(COALESCE(p_mime_type, '')));
BEGIN
  IF auth.uid() IS NULL OR v_tenant_id IS NULL OR v_employee_id IS NULL THEN
    RAISE EXCEPTION 'PULS_AUTH_REQUIRED: Authentication required.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_upload
  FROM puls_workflow.evidence_uploads
  WHERE id = p_evidence_upload_id
    AND tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_NOT_FOUND: Evidence upload was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.owner_employee_id <> v_employee_id AND NOT puls_core.is_admin() THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_FORBIDDEN: Evidence upload does not belong to this user.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.status <> 'intent_created'::puls_workflow.evidence_upload_status THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_STATUS_INVALID: Evidence upload cannot be finalized.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.expires_at <= NOW() THEN
    UPDATE puls_workflow.evidence_uploads
    SET status = 'expired'::puls_workflow.evidence_upload_status
    WHERE id = v_upload.id;

    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_EXPIRED: Evidence upload intent has expired.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_file_size_bytes IS DISTINCT FROM v_upload.file_size_bytes OR v_mime_type IS DISTINCT FROM v_upload.mime_type THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_METADATA_MISMATCH: Finalized file metadata must match the upload intent.'
      USING ERRCODE = 'P0001';
  END IF;

  IF LOWER(p_sha256_client) IS DISTINCT FROM v_upload.sha256_client THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_HASH_MISMATCH: Client hash metadata must match the upload intent.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM storage.objects object
    WHERE object.bucket_id = v_upload.storage_bucket
      AND object.name = v_upload.storage_path
  ) THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_STORAGE_OBJECT_MISSING: Uploaded storage object was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE puls_workflow.evidence_uploads
  SET
    status = 'uploaded'::puls_workflow.evidence_upload_status,
    uploaded_at = NOW()
  WHERE id = v_upload.id
  RETURNING * INTO v_upload;

  PERFORM puls_workflow.write_audit_log(
    v_tenant_id,
    v_employee_id,
    'workflow_evidence.upload_finalized',
    'evidence_uploads',
    v_upload.id,
    jsonb_build_object(
      'domain', v_upload.domain::TEXT,
      'mime_type', v_upload.mime_type,
      'file_extension', v_upload.file_extension,
      'file_size_bytes', v_upload.file_size_bytes,
      'sha256_client_present', v_upload.sha256_client IS NOT NULL,
      'storage_object_exists', TRUE,
      'scan_status', v_upload.scan_status::TEXT
    )
  );

  RETURN jsonb_build_object(
    'evidence_upload_id', v_upload.id,
    'status', v_upload.status::TEXT,
    'storage_bucket', v_upload.storage_bucket,
    'storage_path', v_upload.storage_path,
    'scan_status', v_upload.scan_status::TEXT
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.attach_contract_file_evidence(
  p_evidence_upload_id UUID,
  p_contract_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_upload puls_workflow.evidence_uploads%ROWTYPE;
  v_contract_file_id UUID;
BEGIN
  IF auth.uid() IS NULL OR v_tenant_id IS NULL OR v_employee_id IS NULL OR NOT puls_core.is_admin() THEN
    RAISE EXCEPTION 'PULS_ADMIN_REQUIRED: Admin access required.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_upload
  FROM puls_workflow.evidence_uploads
  WHERE id = p_evidence_upload_id
    AND tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_NOT_FOUND: Evidence upload was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.domain <> 'contract'::puls_workflow.evidence_upload_domain
     OR v_upload.subject_table <> 'puls_workflow.contracts'
     OR v_upload.subject_id IS DISTINCT FROM p_contract_id THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_CONTRACT_MISMATCH: Evidence upload does not belong to this contract.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.status <> 'uploaded'::puls_workflow.evidence_upload_status THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_STATUS_INVALID: Evidence upload must be finalized before attach.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.expires_at <= NOW() THEN
    UPDATE puls_workflow.evidence_uploads
    SET status = 'expired'::puls_workflow.evidence_upload_status
    WHERE id = v_upload.id;

    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_EXPIRED: Evidence upload intent has expired.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.contracts c
    WHERE c.id = p_contract_id
      AND c.tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_CONTRACT_NOT_FOUND: Contract was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO puls_workflow.contract_files (
    tenant_id,
    contract_id,
    uploaded_by_employee_id,
    file_ref,
    file_name,
    mime_type,
    file_size_bytes,
    metadata_only
  )
  VALUES (
    v_tenant_id,
    p_contract_id,
    v_employee_id,
    v_upload.storage_path,
    v_upload.original_file_name,
    v_upload.mime_type,
    v_upload.file_size_bytes,
    TRUE
  )
  RETURNING id INTO v_contract_file_id;

  UPDATE puls_workflow.evidence_uploads
  SET
    status = 'attached'::puls_workflow.evidence_upload_status,
    attached_table = 'puls_workflow.contract_files',
    attached_id = v_contract_file_id,
    attached_at = NOW()
  WHERE id = v_upload.id;

  PERFORM puls_workflow.write_audit_log(
    v_tenant_id,
    v_employee_id,
    'workflow_evidence.contract_file_attached',
    'contract_files',
    v_contract_file_id,
    jsonb_build_object(
      'evidence_upload_id', v_upload.id,
      'contract_id', p_contract_id,
      'mime_type', v_upload.mime_type,
      'file_extension', v_upload.file_extension,
      'file_size_bytes', v_upload.file_size_bytes,
      'metadata_only', TRUE,
      'scan_status', v_upload.scan_status::TEXT
    )
  );

  RETURN jsonb_build_object(
    'contract_file_id', v_contract_file_id,
    'evidence_upload_id', v_upload.id,
    'status', 'attached'
  );
END;
$$;

DROP POLICY IF EXISTS puls_workflow_evidence_uploads_select ON puls_workflow.evidence_uploads;
CREATE POLICY puls_workflow_evidence_uploads_select
  ON puls_workflow.evidence_uploads
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR owner_employee_id = puls_core.current_employee_id()
      OR (
        status = 'attached'::puls_workflow.evidence_upload_status
        AND puls_workflow.can_read_workflow_evidence_storage_object(storage_path)
      )
    )
  );

DROP POLICY IF EXISTS workflow_evidence_objects_select ON storage.objects;
CREATE POLICY workflow_evidence_objects_select
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'workflow-evidence'
    AND puls_workflow.can_read_workflow_evidence_storage_object(name)
  );

DROP POLICY IF EXISTS workflow_evidence_objects_insert ON storage.objects;
CREATE POLICY workflow_evidence_objects_insert
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'workflow-evidence'
    AND puls_workflow.can_upload_workflow_evidence_storage_object(name)
  );

DROP POLICY IF EXISTS workflow_evidence_objects_update ON storage.objects;
DROP POLICY IF EXISTS workflow_evidence_objects_delete ON storage.objects;

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
          OR puls_workflow._workflow_evidence_is_assigned_approver(
            'leave'::puls_workflow.evidence_upload_domain,
            lr.id,
            puls_core.current_employee_id()
          )
        )
    )
  );

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
          OR puls_workflow._workflow_evidence_is_assigned_approver(
            'expense'::puls_workflow.evidence_upload_domain,
            ec.id,
            puls_core.current_employee_id()
          )
        )
    )
  );

DROP POLICY IF EXISTS puls_workflow_leave_documents_insert ON puls_workflow.leave_documents;
DROP POLICY IF EXISTS puls_workflow_leave_documents_update ON puls_workflow.leave_documents;
DROP POLICY IF EXISTS puls_workflow_expense_receipts_insert ON puls_workflow.expense_receipts;
DROP POLICY IF EXISTS puls_workflow_expense_receipts_update ON puls_workflow.expense_receipts;
DROP POLICY IF EXISTS puls_workflow_contract_files_insert ON puls_workflow.contract_files;
DROP POLICY IF EXISTS puls_workflow_contract_files_update ON puls_workflow.contract_files;

REVOKE ALL ON TABLE puls_workflow.evidence_uploads FROM anon, authenticated;
GRANT SELECT ON TABLE puls_workflow.evidence_uploads TO authenticated;

REVOKE ALL ON FUNCTION puls_workflow._workflow_evidence_extension_for_mime(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow._workflow_evidence_max_bytes(puls_workflow.evidence_upload_domain) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow._workflow_evidence_is_assigned_approver(puls_workflow.evidence_upload_domain, UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.can_upload_workflow_evidence_storage_object(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION puls_workflow.can_read_workflow_evidence_storage_object(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow._workflow_evidence_is_assigned_approver(puls_workflow.evidence_upload_domain, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION puls_workflow.can_upload_workflow_evidence_storage_object(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION puls_workflow.can_read_workflow_evidence_storage_object(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION puls_workflow.create_workflow_evidence_upload_intent(TEXT, TEXT, TEXT, BIGINT, TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION puls_workflow.finalize_workflow_evidence_upload(UUID, BIGINT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION puls_workflow.attach_contract_file_evidence(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.create_workflow_evidence_upload_intent(TEXT, TEXT, TEXT, BIGINT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION puls_workflow.finalize_workflow_evidence_upload(UUID, BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION puls_workflow.attach_contract_file_evidence(UUID, UUID) TO authenticated;
