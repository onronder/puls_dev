# PR16.10.11 Security & Runtime Truth Hardening

PR16.10.11 closes the remaining PR16.10 trust-surface findings before PR17
productization work starts. It keeps PULS DataSource Manager's user journey
intact while hardening file import parsing, demo-data truthfulness, worker retry
behavior, CI audit gates, and service-role log redaction.

## Product Contract

- DataSource Manager remains source-instance oriented.
- No release notes, development notes, future-work notes, or debug explanations
  are added to production UI.
- CSV and Excel imports remain dry-run staging flows.
- XLSX support remains available through a maintained parser; vulnerable `xlsx@0.18.x` is not shipped.
- If real data fails and sample data is shown, the UI must explicitly tell the
  user that real data could not be loaded.
- Empty real data may still use the existing lightweight demo indicator when
  demo mode is enabled.

## Runtime Contract

- The connector worker no longer retries on a fixed interval after loop-level
  failures.
- Safe retry windows are respected with bounded jitter to reduce synchronized
  retries across workers.
- Worker health and safe contexts still do not expose service-role keys,
  credential references, raw payloads, or provider responses.
- Supabase service-role headers remain necessary for service RPC calls, but
  loggable header metadata must be redacted.

## CI Contract

- Vitest remains in CI.
- Dependency audit blocks high-severity vulnerable dependency paths.
- Supabase schema audit is part of the quality job. It uses CI secrets when
  configured and emits an explicit skip notice instead of failing when those
  secrets are absent.
- The CI gate must fail if `xlsx` re-enters the dependency graph or if the
  worker loop returns to fixed `setInterval` polling.

## Verification

```bash
scripts/verify-16-10-11-security-runtime-truth-hardening.sh WORKTREE
pnpm exec vitest run --config vitest.config.ts src/lib/data/setup/file-import-contract.test.ts
pnpm exec vitest run --config vitest.config.ts services/erp-connector/src/worker.test.ts
pnpm audit --audit-level high
pnpm run audit:supabase
pnpm run typecheck
pnpm run lint
pnpm run check-i18n
pnpm run build
```

Remote smoke should verify:

- DataSource Manager still opens with no visible development or release notes.
- CSV / Excel import sheet still accepts `.csv` and `.xlsx`.
- A formula cell without a cached value is rejected.
- A real-data error fallback shows the explicit sample-data warning.
- Worker retry behavior uses safe backoff and jitter rather than fixed interval
  polling.
