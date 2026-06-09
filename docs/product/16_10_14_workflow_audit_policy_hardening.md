# PR16.10.14 Workflow Audit & Policy Hardening

## Product Goal

PR16.10.14 closes the remaining pre-PR17 trust-surface gaps in the HR
workflow lane without changing the DataSource Manager journey. Leave, expense,
and approval records now produce tenant-bound row audit evidence even when the
mutation path is not the primary RPC business log. Expense receipt policy also
moves from a browser-side constant to the category contract and server RPC.

## Scope

- Add metadata-only row audit triggers for:
  - `puls_workflow.leave_requests`
  - `puls_workflow.expense_claims`
  - `puls_workflow.approval_requests`
- Keep workflow audit metadata safe:
  - no description text
  - no receipt payload
  - no document payload
  - no raw import payload
  - no credential or source payload
- Re-declare `puls_workflow.create_expense_claim` so receipt-required categories
  are blocked server-side while document upload is unavailable.
- Remove the hard-coded browser receipt threshold from `/masraf`.
- Read `receipt_required_over` from `expense_categories` and use it for the UI
  policy state.
- Add localized user-facing receipt-required errors.

## Non-Goals

- No connector runtime changes.
- No canonical import apply changes.
- No ERP/provider API calls.
- No notification delivery changes.
- No document upload implementation.
- No PR17 page productization.

## Safety Contract

- Audit trigger inserts are tenant-bound using the mutated row tenant.
- Audit metadata is limited to status, approval step, policy id, parent ids,
  requester/approver ids, operation, and target identity.
- Browser users cannot execute audit helper functions directly.
- Expense claims above `receipt_required_over` raise `PULS_RECEIPT_REQUIRED`
  until receipt upload support is implemented.
- Category monthly-limit overages remain policy warnings, not hard blocks.

## Verification

- `scripts/verify-16-10-14-workflow-audit-policy-hardening.sh`
- `pnpm run typecheck`
- `pnpm run test`
- `pnpm run lint`
- `pnpm run check-i18n`
- `pnpm run build`
- Browser smoke on `/masraf`
