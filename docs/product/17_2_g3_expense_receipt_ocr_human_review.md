# PR17.2G3 Expense Receipt OCR Human Review

> **Status:** Implemented as a human-review boundary for existing expense receipt OCR results. No OCR provider, production enqueue, worker deployment change, or canonical expense mutation is included.

PR17.2G3 turns the G2A/G2B processing contract into a usable review surface. Authorized reviewers can inspect an attached receipt, see safe OCR/extraction suggestions, and record a human decision. The decision is audit-backed and intentionally separate from canonical expense approval.

## Scope

- Add review metadata to `puls_workflow.expense_receipt_ocr_results`:
  - `reviewed_by_employee_id`
  - `reviewed_at`
  - `review_note`
  - `corrected_fields`
- Add `record_expense_receipt_ocr_review(...)` for browser-authenticated reviewers.
- Allow only `accepted`, `corrected`, `rejected`, and `needs_new_document` as review decisions.
- Keep corrected fields whitelist-based:
  - `amount`
  - `currency`
  - `expense_date`
  - `category_label`
  - `merchant_name`
  - `vat_included`
- Record safe audit/event metadata:
  - review status,
  - corrected field count,
  - whether a note exists,
  - canonical write is false.
- Add an expense page review panel for manager approval rows and a read-only status view for the requester history.

## Authorization

Review write access is limited to:

- `hr_admin` / `superadmin`, or
- the assigned approval requester reviewer for the related expense claim.

Requesters, team managers who are not assigned approvers, and unrelated tenant users can read only through the existing OCR/evidence RLS paths; they cannot record a review decision.

## Explicit Non-Goals

- No canonical `expense_claims` update.
- No automatic apply of OCR/corrected values.
- No production enqueue trigger.
- No browser enqueue.
- No OCR provider SDK or external OCR call.
- No raw OCR text, provider payload, storage path, signed URL, or file bytes in audit metadata.
- No second review or decision overwrite once a result leaves `pending_review`.

## UI Contract

The `/masraf` page shows a compact OCR review panel only when an OCR result exists for an attached expense receipt:

- requester history rows show the current OCR review status read-only,
- manager approval rows show the same status plus decision actions,
- the document view action remains the source of truth for receipt inspection,
- review note is stored on the OCR result row, not in audit metadata,
- approval/rejection of the expense remains a separate workflow action.

## Verification

Primary gate:

```bash
bash scripts/verify-17-2-g3-expense-receipt-ocr-human-review.sh
```

Optional rollback smoke:

```bash
psql "$DATABASE_URL" -f docs/data/17_2_g3_expense_receipt_ocr_human_review_smoke.sql
```

The smoke creates a rollback-only tenant, expense claim, receipt, OCR job/result, assigned approver, and review decision. It asserts:

- authenticated assigned approver can record a review,
- review note and corrected fields stay on the result row,
- audit metadata does not contain review note, raw OCR text, or provider payload,
- canonical expense claim amount/status do not change,
- repeated review is rejected.

## Handoff

PR17.2G4 remains the first phase where production enqueue, tenant OCR enablement, provider selection, quota, cost, KVKK/GDPR, data residency, and benchmark gates can be evaluated.
