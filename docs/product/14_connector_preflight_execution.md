# PR14.11 Connector Preflight Execution

PR14.11 turns connector setup into an explicit dry-run readiness gate. It does not pretend that a live connector exists. It checks whether the selected source, field contract, namespace, identity strategy, and safety boundaries are ready before any future runtime connector can move data.

## What This Proves

- Admin users can run a setup check from `/erp`.
- The result is computed from tenant-scoped setup records, mappings, namespaces, and identity evidence.
- The UI explains pass, warning, and blocked outcomes in product language.
- Managers can inspect the same result without running setup actions.
- Dashboard copy can distinguish `mapping_ready` from `preflight_ready`.

## What This Does Not Prove

- No live connector API call.
- No connector import execution.
- No CSV file upload execution.
- No credential capture or secret storage.
- No runtime sync.
- No ERP write-back.

## Preflight Checks

| Check | Meaning |
|-------|---------|
| Source profile | A tenant-scoped connector setup exists and is enabled. |
| Required field contract | Required PULS canonical fields have mapped source fields. |
| Source namespace | External record identities have a clear source scope. |
| Record matching | Identity evidence exists before records are matched. |
| Credential boundary | API keys, passwords, FTP secrets, and OAuth tokens remain outside product metadata. |
| Runtime boundary | The check does not call a live API, import, export, or sync. |
| ERP write guardrail | PULS does not automatically or destructively write ERP master data. |

## Result Model

`ready` means all dry-run checks passed. `partial` means the setup can be reviewed but still has warnings. `blocked` means runtime connector execution must stay closed until missing steps are fixed.

The result is intentionally deterministic. It is derived from current setup state rather than from a hidden external test. That keeps the flow honest while customer-specific connector credentials and APIs are still future work.

## Acceptance Criteria

- `/erp` has an admin-only `Run setup check` action for selected connectors.
- `/erp` shows a preflight result summary with passed, warning, and blocked counts.
- `/erp` shows per-check explanations without raw technical errors.
- The action does not write seed data, import data, call a connector runtime, or write to ERP.
- Tests cover ready and blocked preflight outcomes.
- Verification forbids migrations, seed CSV/manifest changes, credentials, runtime sync, and connector write patterns.
