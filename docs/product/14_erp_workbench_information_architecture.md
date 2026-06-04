# PR14.21 - ERP Workbench Information Architecture

PR14.21 refactors `/erp` from one long vertical connector page into a tabbed workbench. It does not change connector runtime, database schema, credential handling, import apply, or ERP/source writeback.

## Product Claim

PULS remains a source-independent connectivity product. Canias is one connector profile, not the workbench architecture.

The `/erp` page should help an admin understand one question at a time:

- What source is selected?
- Which PULS canonical fields and identities are mapped?
- Is setup ready enough to check?
- What credential boundary is still missing?
- What preview/apply evidence exists?
- What safe activity history has been recorded?

## UX Model

| Tab             | Purpose                                                                                                         |
| --------------- | --------------------------------------------------------------------------------------------------------------- |
| Setup           | Lifecycle, source capabilities, primary setup actions, and setup guardrail                                      |
| Fields          | Source namespaces, domain ownership, canonical classes, field mapping, transfer modes, and guardrails           |
| Check           | Dry-run setup check and readiness checks                                                                        |
| Credentials     | Credential posture and secure-reference handoff without secret capture                                          |
| Preview & Apply | Import preview, human review readiness, controlled apply design, approval policy, and closed execution contract |
| Activity        | Safe connector timeline and next actions                                                                        |

## Mobile Rules

- Tabs must be horizontally scrollable on narrow screens.
- Each tab must keep its own vertical rhythm and avoid horizontal overflow.
- The top summary remains compact so mobile users can understand connector posture before drilling into a tab.
- Dense audit details belong in Activity, not in the first setup view.

## Scope

| Area               | PR14.21 behavior                                                             |
| ------------------ | ---------------------------------------------------------------------------- |
| Route UI           | Adds tabbed workbench navigation for selected connectors                     |
| No-connector state | Keeps the first-run source-selection flow focused and unchanged              |
| Adapter            | No behavior change                                                           |
| Database           | No migration                                                                 |
| Runtime            | No connector calls, no sync execution, no import apply                       |
| Credentials        | No secret input, no secret display, no credential readback                   |
| Tests              | Authenticated e2e verifies tab navigation and keeps mobile overflow coverage |

## Acceptance Criteria

- `/erp` no longer shows every connector section in one uninterrupted vertical page.
- The selected connector state exposes Setup, Fields, Check, Credentials, Preview & Apply, and Activity tabs.
- Admin actions still use the existing adapter mutations.
- Preflight, preview, and review actions open the relevant tab after success.
- No product UI action calls `apply_import_batch`.
- No migration, seed CSV, manifest, package, or environment file changes are introduced.
- Mobile route stabilization continues to prove `/erp` has no horizontal overflow.
