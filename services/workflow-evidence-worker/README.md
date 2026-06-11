# PULS Workflow Evidence Worker

PR17.2G2B adds a disabled-by-default worker skeleton for expense receipt evidence processing.

The worker can:

- claim `puls_workflow.expense_receipt_ocr_jobs`,
- heartbeat active OCR job leases,
- read attached `expense_receipts` metadata through Supabase REST,
- download the private `workflow-evidence` object with the service-role key,
- compute a server-side SHA-256 content hash,
- run a zero-network PDF text-layer extraction when `PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS=pdf_text`,
- complete the G2A RPC contract with a disabled/mock/pdf_text provider result.

The worker does not:

- call an OCR provider,
- add a Railway deployment file,
- enqueue jobs from browser workflows,
- mutate canonical `expense_claims` values,
- read ERP connector credentials,
- expose service-role keys in health or loggable header helpers.

Production enqueue and provider selection remain blocked until later PR17.2G gates add tenant-level OCR enablement, quotas, cost controls, and KVKK/GDPR/provider decisions.

The `pdf_text` route is a local free-route benchmark path only. It does not perform image OCR and does not send document bytes or text to any vendor.
