# PR17.2G3A Expense Receipt OCR Review Hardening

> **Status:** Implemented as a narrow hardening slice after PR17.2G3. No OCR provider, production enqueue, Railway deployment, or canonical expense mutation is included.

PR17.2G3 added the human-review boundary for expense receipt OCR results. PR17.2G3A tightens that boundary before PR17.2G4 vendor/production-enqueue work starts.

## Scope

- Block OCR self-review server-side, even when the requester also has `hr_admin` or `superadmin` authority.
- Keep review write access limited to:
  - non-requester `hr_admin` / `superadmin`, or
  - non-requester assigned approver for the related expense claim.
- Extend the rollback-only G3 smoke to prove:
  - an unassigned employee cannot record an OCR review,
  - the requester cannot review their own receipt OCR result,
  - the assigned approver can still record the review,
  - repeated review remains rejected.
- Clarify that PR17.2G3's correction UX records correction notes only. Structured corrected field entry is intentionally deferred until a later apply/review slice.
- Carry G4 backlog items explicitly:
  - structured correction form + client-side field validation,
  - OCR job recover/dead-letter smoke,
  - heartbeat during long provider calls,
  - tenant OCR flag, quota, cost, KVKK/GDPR, and data-residency gates.

## Explicit Non-Goals

- No canonical `expense_claims` update.
- No production OCR enqueue.
- No provider SDK or external OCR call.
- No browser enqueue.
- No new notification event.
- No OCR result override/reopen flow.

## Verification

Primary gate:

```bash
bash scripts/verify-17-2-g3a-expense-receipt-ocr-review-hardening.sh
```

Aggregate gate:

```bash
pnpm run verify:pr17
```

Optional rollback smoke:

```bash
psql "$DATABASE_URL" -f docs/data/17_2_g3_expense_receipt_ocr_human_review_smoke.sql
```
