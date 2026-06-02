# PR14.7 — Role + Tenant E2E Matrix and Empty-State Contract

PR14.7 promotes the live authenticated e2e gate from a single-login smoke into a product contract for role behavior and tenant posture.

## Product Claim

Role and tenant posture must be proven before connector setup persistence.

PULS Connector Lab is the first-run empty-state tenant for product onboarding.

Puls Teknik A.S. remains the seeded operational tenant for source-real regression proof.

Empty tenant behavior is a product state, not a missing-data bug.

Connector setup persistence stays future until the first-run empty-state contract is stable.

## Tenant Postures

| Tenant | Purpose | Expected posture |
|--------|---------|------------------|
| Puls Teknik A.S. | Seeded operational proof | Canias metadata present, preflight ready, organization data populated |
| PULS Connector Lab | First customer opening state | No connector selected, no organization data, setup guidance visible |

## Role Matrix

| Role | Secret prefix | Business expectation |
|------|---------------|----------------------|
| Admin | `E2E_ADMIN_*` or legacy `E2E_*` | Full seeded tenant posture and setup route access |
| HR admin | `E2E_HR_*` | People operations access without setup bounce |
| Manager | `E2E_MANAGER_*` | Manager mode exposes team-scoped performance posture |
| Employee | `E2E_EMPLOYEE_*` | Self-scoped experience; setup routes redirect to settings |
| Connector admin | `E2E_CONNECTOR_ADMIN_*` | PULS Connector Lab first-run dashboard and connector setup wizard |

Secrets must live in GitHub repository secrets. No role password belongs in source files, docs, logs, or screenshots.

## Empty-State Contract

The empty tenant starts on `/dashboard`. It should show that the workspace exists, setup is pending, and the next useful action is choosing a data source or opening company setup.

The `/erp` page is the connector setup wizard entry point. In no-connector posture, Connection setup starts with source selection, keeps connection record creation disabled, and keeps credential storage, runtime sync, and ERP writes closed.

The first-run product flow is:

1. Open dashboard
2. Choose data source
3. Review source setup draft
4. Complete mapping and identity strategy in future PRs

## PR14.7 Scope

In scope:

- Dashboard empty-state copy and primary/secondary setup actions
- ERP no-connector wizard copy and source-selection posture
- Live authenticated role + tenant Playwright matrix
- CI env wiring for role secrets
- Docs and verify gate

Out of scope:

- Persisting selected connectors
- Credential capture or credential storage
- Runtime sync
- ERP writes
- New migrations or seed changes

## Acceptance

- `Puls Teknik A.S.` admin sees seeded operational posture and Canias readiness.
- `PULS Connector Lab` admin sees first-run empty dashboard and `/erp` setup wizard.
- HR can reach people operations.
- Manager can reach manager-scoped performance posture.
- Employee remains self-scoped and cannot access setup routes.
- The product still has no runtime sync, no credential storage, and no ERP writes.

## Handoff To PR14.8

After PR14.7, connector setup persistence can be designed with the right questions:

- Is provider selection a draft, request, or committed connector record?
- Who can create or reset a connector setup draft?
- Which fields become tenant-level connector metadata?
- What audit record is created before credentials exist?
- How does dashboard readiness change after provider selection but before mapping?
