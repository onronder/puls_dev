# PR13.7 — AI Coach Action Boundary

Defines what AI Coach is **allowed** and **forbidden** to do with connector/ERP context after PR13.6 DB context readiness. This is an action-boundary contract — not live LLM runtime.

**PR13.7 is connector discovery and action-boundary readiness, not runtime integration.**

AI Coach is a process-embedded value layer, not only the `/ai-koc` page. PR13.6 proved DB context readiness, not live LLM chat.

## Executive summary

AI Coach may **explain**, **summarize**, **detect gaps**, **draft next steps**, and **prepare human review** from tenant-scoped DB context. **AI Coach may suggest, explain, and draft; humans confirm every workflow action.**

AI Coach must not call workflow mutation RPCs autonomously. AI Coach must not approve, reject, deactivate, restore, sync, export, or write to ERP without explicit human action.

**Source disclosure is required:** PULS-owned, imported/Canias, metadata-only, or unknown.

**llm-gateway is a future service-boundary hint**, not a live PR13.7 runtime.

**erp-connector is a future connector boundary**, not a PR13.7 runtime connector.

## Relationship to PR13.6

| PR | Proves |
|----|--------|
| PR13.6 | DB context assembly for 8 touchpoints; guardrails UI; `source: real` path; no live chat |
| PR13.7 | Action taxonomy — what AI may do with that context; Canias/ERP-specific guardrails; forbidden autonomous paths |

PR13.6 guardrails carry forward: human-in-the-loop — **no autonomous mutations** — **no auto-approvals** — **no ERP writes**.

## Allowed AI Coach outputs

| Action class | Meaning | Runtime posture |
|--------------|---------|-----------------|
| `explain` | Explain policy, source, readiness, risk | Allowed from DB context |
| `summarize` | Summarize queues, gaps, connector readiness | Allowed |
| `detect_gap` | Detect missing assignments/mappings | Allowed |
| `draft_next_step` | Draft human-readable next action | Allowed |
| `prepare_review` | Prepare import/export review checklist | Allowed |
| `source_disclosure` | Label PULS-owned vs Canias/imported | Required |

## Forbidden AI Coach actions

| Forbidden action | Reason |
|------------------|--------|
| `create_leave_request` by AI | User must submit |
| `create_expense_claim` by AI | User must submit |
| `decide_approval_request` by AI | No auto-approvals |
| `deactivate_leave_type` / `restore_leave_type` by AI | Setup lifecycle remains human/admin |
| `deactivate_expense_category` / `restore_expense_category` by AI | Setup lifecycle remains human/admin |
| `sync_canias_now` | Runtime connector out of scope |
| `write_to_canias` | No ERP writes |
| `delete_or_overwrite_canias_master` | Destructive ERP write ban |
| `insert_vault_message_seed` | Vault is sensitive/system |

## Human confirmation model

Every workflow mutation requires explicit user intent:

1. AI may surface a draft or recommendation
2. User reviews source disclosure labels
3. User clicks/confirms the actual mutation in PULS UI or admin workflow
4. No background job, webhook, or LLM tool call performs the mutation autonomously

## Source disclosure model

Every AI Coach response involving data must label provenance:

| Label | Meaning |
|-------|---------|
| PULS-owned | Created/edited in PULS; user may mutate per CRUD rules |
| imported/Canias | From Canias import; read-only in org setup UI |
| metadata-only | ERP connection/mapping metadata; no live sync |
| unknown | Insufficient context; AI must not invent source |

## Canias/ERP-specific guardrails

- **Canias is the first native ERP integration track for PULS v1.0.**
- **PULS remains the workflow system of record** for leave, expense, approvals, performance, and in-app decisions.
- Canias remains master for imported HR/org/cost-center master data until explicit export paths are designed.
- **No automatic destructive ERP writes.**
- AI may explain inactive Canias connection posture and mapping gaps — must not trigger sync or write.
- No credentials, API keys, tokens, or `credentials_ref` values in PR13.7 artifacts.

## Tool/action taxonomy

Future `llm-gateway` tools (not PR13.7 runtime) must map to allowed action classes only:

| Future tool (hint) | Maps to | Autonomous? |
|--------------------|---------|-------------|
| `explain_readiness` | `explain` | No |
| `summarize_queue` | `summarize` | No |
| `detect_mapping_gap` | `detect_gap` | No |
| `draft_import_checklist` | `prepare_review` | No |
| `label_source` | `source_disclosure` | No (required) |
| `sync_canias_now` | — | **Forbidden** |
| `write_to_canias` | — | **Forbidden** |
| `decide_approval_request` | — | **Forbidden** |

## Future llm-gateway handoff

[`services/llm-gateway/`](../../services/llm-gateway/) is a health-only skeleton (`0.1.0-skeleton`). Future PR will:

1. Accept tenant-scoped context from PR13.6 read models only
2. Enforce action boundary before any tool invocation
3. Never store API keys in repo; env/vault only
4. Remain optional — app works without live LLM

**llm-gateway is a future service-boundary hint, not a live PR13.7 runtime.**

## Future erp-connector handoff

[`services/erp-connector/`](../../services/erp-connector/) is a health-only skeleton. Future PR will:

1. Implement import/export per [`13_canias_field_mapping_matrix.json`](./13_canias_field_mapping_matrix.json)
2. Require human confirmation for every batch
3. Never perform automatic destructive ERP writes
4. Use `credentials_ref` in vault — never in seed or docs

**erp-connector is a future connector boundary, not a PR13.7 runtime connector.**

## Acceptance criteria

- [x] Allowed action classes documented with runtime posture
- [x] Forbidden actions include `decide_approval_request`, `sync_canias_now`, `write_to_canias`
- [x] Human confirmation model explicit
- [x] Source disclosure required for all data references
- [x] No live chat, OpenAI runtime, or autonomous execution implied
- [x] Cross-links to PR13.6 context readiness and Canias discovery pack

## References

- [`13_ai_coach_db_context_readiness.md`](./13_ai_coach_db_context_readiness.md)
- [`13_canias_connector_discovery.md`](./13_canias_connector_discovery.md)
- [`13_canias_ai_connector_readiness_matrix.md`](./13_canias_ai_connector_readiness_matrix.md)
- [`13_ai_coach_process_touchpoints.md`](./13_ai_coach_process_touchpoints.md)
