# PR16.10.0 Connector Access Readiness

PR16.10.0 turns the ERP connector surface from a development-style checklist into a
provider-independent access readiness product surface.

The goal is not to call Canias or any other customer API. Customer API credentials,
base URLs, network details, and test accounts are still missing. This PR makes that
gap explicit and gives operators a safe, reusable way to see what can progress before
live API access exists.

## Product Contract

- `/erp` shows a single access readiness summary for the selected connector.
- The summary works for Canias, Logo, CSV / Excel, and custom API provider options.
- The model is provider-independent and derived from existing safe setup evidence:
  - source selection,
  - connection method,
  - metadata / mapping contract,
  - secure credential reference posture,
  - customer/API access readiness,
  - offline dry-run preview path.
- The UI exposes only status evidence and next actions.
- Real actions are shown only when the app can do something:
  - request secure access reference,
  - review metadata/mapping,
  - open the dry-run preview step.

## Safety Boundary

- No provider API calls.
- No credential value readback.
- No source writeback.
- No ERP writeback.
- No raw provider response or raw payload display.
- No new authenticated table write path.
- No database migration is required for this PR; the model is derived from existing
  `puls_integration` setup, credential, mapping, namespace, job, and preview evidence.

## Why This Exists Before PR17

PR17 will productize the full HR app page by page. Before that, the connector surface
must stop behaving like a developer notebook. PR16.10.0 gives the connector module a
production-grade state language while real customer API access is unavailable.

## Verification

```bash
scripts/verify-16-10-0-connector-access-readiness.sh WORKTREE
pnpm test -- src/lib/data/setup/erp.test.ts
pnpm check-i18n
pnpm typecheck
pnpm lint
pnpm build
```

Browser smoke:

- `/erp` loads for an authenticated admin.
- A selected connector shows `Erişim hazırlığı`.
- The summary shows provider calls, credential readback, and source writeback closed.
- The checklist shows source, method, metadata, secure reference, customer/API access,
  and offline preview path.
- Buttons are only rendered for real actions.
