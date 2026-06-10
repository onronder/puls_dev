-- PR17.2F3: workflow evidence finalization hardening.
-- Verifies the actual private storage object size metadata before an upload intent is finalized.

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
  v_storage_size_text TEXT;
  v_storage_size_bytes BIGINT;
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

  SELECT object.metadata ->> 'size'
  INTO v_storage_size_text
  FROM storage.objects object
  WHERE object.bucket_id = v_upload.storage_bucket
    AND object.name = v_upload.storage_path;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_STORAGE_OBJECT_MISSING: Uploaded storage object was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_storage_size_text IS NULL OR v_storage_size_text = '' OR TRANSLATE(v_storage_size_text, '0123456789', '') <> '' THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_STORAGE_SIZE_UNVERIFIED: Uploaded storage object size metadata could not be verified.'
      USING ERRCODE = 'P0001';
  END IF;

  v_storage_size_bytes := v_storage_size_text::BIGINT;

  IF v_storage_size_bytes IS DISTINCT FROM v_upload.file_size_bytes THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_STORAGE_SIZE_MISMATCH: Uploaded storage object size does not match the upload intent.'
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
      'storage_size_verified', TRUE,
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

COMMENT ON FUNCTION puls_workflow.finalize_workflow_evidence_upload(UUID, BIGINT, TEXT, TEXT)
  IS 'Finalizes workflow evidence upload intents only after private storage object existence and size metadata match the server-generated upload intent. SHA-256 remains client-declared metadata.';

REVOKE ALL ON FUNCTION puls_workflow.finalize_workflow_evidence_upload(UUID, BIGINT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.finalize_workflow_evidence_upload(UUID, BIGINT, TEXT, TEXT) TO authenticated;
