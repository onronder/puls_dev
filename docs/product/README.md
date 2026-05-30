# PULS Product Packaging (PR13)

V1 product packaging strategy and inventory documents.

## PR13.0 strategy pack

| Document | Purpose |
|----------|---------|
| [13_v1_product_packaging_strategy.md](./13_v1_product_packaging_strategy.md) | Scope lock, principles, PR13 roadmap, non-goals |
| [13_v1_feature_traceability_matrix.md](./13_v1_feature_traceability_matrix.md) | V1 features → routes, backends, demo, AI, honest status |
| [13_demo_data_packaging_principles.md](./13_demo_data_packaging_principles.md) | DB-backed demo tenant; embedded TS retirement |
| [13_ai_coach_process_touchpoints.md](./13_ai_coach_process_touchpoints.md) | AI Coach value layer, guardrails, touchpoints |
| [13_canias_first_integration_boundary.md](./13_canias_first_integration_boundary.md) | Canias-first ERP boundary, MVP constraints |

Verify: [`../../scripts/verify-13-v1-product-packaging.sh`](../../scripts/verify-13-v1-product-packaging.sh)

## PR13.1 inventory pack

| Document | Purpose |
|----------|---------|
| [13_feature_db_coverage_inventory.md](./13_feature_db_coverage_inventory.md) | Feature → route → adapter → DB object matrix |
| [13_db_table_completeness_classes.md](./13_db_table_completeness_classes.md) | DB object completeness classes for demo packaging |
| [13_embedded_demo_dependency_map.md](./13_embedded_demo_dependency_map.md) | `fetchDemo*` / embedded TS dependency inventory |
| [13_ai_context_data_requirements.md](./13_ai_context_data_requirements.md) | AI Coach DB context requirements and gaps |

Verify: [`../../scripts/verify-13-feature-db-coverage.sh`](../../scripts/verify-13-feature-db-coverage.sh)

## Related packs

| Pack | Entry point |
|------|-------------|
| API contract (PR12) | [`../api/README.md`](../api/README.md) |
| Data inventories (PR11) | [`../data/README.md`](../data/README.md) |
| V1 product specs | [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md) |
