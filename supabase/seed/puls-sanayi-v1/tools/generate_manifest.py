#!/usr/bin/env python3
"""Emit manifest.json with tableColumnMap aligned to generated CSV headers."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = ROOT / "csv"


def headers(name: str) -> list[str]:
    with (CSV_DIR / name).open(encoding="utf-8") as f:
        return next(csv.reader(f))


def count_rows(name: str) -> int:
    with (CSV_DIR / name).open(encoding="utf-8") as f:
        return sum(1 for _ in f) - 1


manifest = {
    "version": "puls-sanayi-v1",
    "canonicalTenant": "Puls Sanayi A.Ş.",
    "employeeCount": 120,
    "tenantId": "a0000001-0001-4001-8001-000000000001",
    "sourceCrosswalk": "docs/product/13_data_dictionary_seed_crosswalk.json",
    "artifactIdNote": "Numbered CSV filenames are artifact identifiers, not load order.",
    "baselineSeedArtifacts": [
        "pack.tenant_org",
        "pack.locations_assignments",
        "pack.org_departments",
        "pack.org_positions",
        "pack.employee_roster",
        "pack.reporting_lines",
        "pack.cost_center_assignments",
        "pack.leave_types",
        "pack.approval_policies",
        "pack.leave_balances",
        "pack.expense_categories",
        "pack.cost_center_erp_mapping",
        "pack.performance_cycles",
        "pack.performance_parameters",
        "pack.training_catalog",
        "pack.career_profiles",
        "pack.contracts_metadata",
        "pack.erp_metadata",
    ],
    "scenarioSeedArtifactsDeferredTo": "PR13.5",
    "loadOrder": [
        "01_tenant.csv",
        "16_erp_connections.csv",
        "18_source_namespaces.csv",
        "02_legal_entities.csv",
        "03_locations.csv",
        "10_cost_centers.csv",
        "04_departments.csv",
        "05_positions.csv",
        "06_employees.csv",
        "07_employee_reporting_lines.csv",
        "08_employee_legal_entity_assignments.csv",
        "09_employee_location_assignments.csv",
        "11_employee_cost_center_assignments.csv",
        "__phase_post_load_department_updates__",
        "13_approval_policies.csv",
        "12_leave_types.csv",
        "14_leave_balances.csv",
        "15_expense_categories.csv",
        "17_erp_field_mappings.csv",
        "19_entity_identity_map.csv",
        "20_performance_cycles.csv",
        "21_performance_parameters.csv",
        "22_contracts.csv",
    ],
    "csvFiles": [
        {"file": "csv/01_tenant.csv", "artifactId": "01", "dbObject": "puls_core.tenants", "expectedRows": 1},
        {"file": "csv/02_legal_entities.csv", "artifactId": "02", "dbObject": "puls_core.legal_entities", "expectedRows": 1},
        {"file": "csv/03_locations.csv", "artifactId": "03", "dbObject": "puls_core.locations", "expectedRows": 3},
        {"file": "csv/04_departments.csv", "artifactId": "04", "dbObject": "puls_core.departments", "expectedRows": 12},
        {"file": "csv/05_positions.csv", "artifactId": "05", "dbObject": "puls_core.positions", "expectedRows": {"min": 35, "max": 50}},
        {"file": "csv/06_employees.csv", "artifactId": "06", "dbObject": "puls_core.employees", "expectedRows": 120},
        {"file": "csv/07_employee_reporting_lines.csv", "artifactId": "07", "dbObject": "puls_core.employee_reporting_lines", "expectedRows": {"min": 119}},
        {"file": "csv/08_employee_legal_entity_assignments.csv", "artifactId": "08", "dbObject": "puls_core.employee_legal_entity_assignments", "expectedRows": 120},
        {"file": "csv/09_employee_location_assignments.csv", "artifactId": "09", "dbObject": "puls_core.employee_location_assignments", "expectedRows": 120},
        {"file": "csv/10_cost_centers.csv", "artifactId": "10", "dbObject": "puls_core.cost_centers", "expectedRows": {"min": 12, "max": 20}},
        {"file": "csv/11_employee_cost_center_assignments.csv", "artifactId": "11", "dbObject": "puls_core.employee_cost_center_assignments", "expectedRows": 120},
        {"file": "csv/12_leave_types.csv", "artifactId": "12", "dbObject": "puls_workflow.leave_types", "expectedRows": {"min": 6, "max": 10}},
        {"file": "csv/13_approval_policies.csv", "artifactId": "13", "dbObject": "multi-table", "expectedRows": {"min": 6, "max": 12}},
        {"file": "csv/14_leave_balances.csv", "artifactId": "14", "dbObject": "puls_workflow.leave_balances", "expectedRows": {"min": 120}},
        {"file": "csv/15_expense_categories.csv", "artifactId": "15", "dbObject": "puls_workflow.expense_categories", "expectedRows": {"min": 8, "max": 15}},
        {"file": "csv/16_erp_connections.csv", "artifactId": "16", "dbObject": "puls_integration.erp_connections", "expectedRows": 1},
        {"file": "csv/17_erp_field_mappings.csv", "artifactId": "17", "dbObject": "puls_integration.erp_field_mappings", "expectedRows": {"min": 10, "max": 25}},
        {"file": "csv/18_source_namespaces.csv", "artifactId": "18", "dbObject": "puls_integration.source_namespaces", "expectedRows": 1},
        {"file": "csv/19_entity_identity_map.csv", "artifactId": "19", "dbObject": "puls_integration.entity_identity_map", "expectedRows": {"min": 6, "max": 15}},
        {"file": "csv/20_performance_cycles.csv", "artifactId": "20", "dbObject": "puls_performance.performance_cycles", "expectedRows": {"min": 1, "max": 2}},
        {"file": "csv/21_performance_parameters.csv", "artifactId": "21", "dbObject": "multi-table", "expectedRows": {"min": 40}},
        {"file": "csv/22_contracts.csv", "artifactId": "22", "dbObject": "puls_workflow.contracts", "expectedRows": {"min": 15, "max": 30}},
    ],
    "validationExpectations": {
        "employees": 120,
        "departments": 12,
        "locations": 3,
        "training_needs": {"min": 20, "max": 40},
        "career_profiles": {"min": 20, "max": 40, "notPerEmployee": True},
    },
    "forbiddenFields": ["api_key", "secret", "password", "token", "credentials_ref"],
    "tableColumnMap": {
        "csv/01_tenant.csv": {
            "multiTable": False,
            "dbObject": "puls_core.tenants",
            "insertableColumns": headers("01_tenant.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/02_legal_entities.csv": {
            "multiTable": False,
            "dbObject": "puls_core.legal_entities",
            "insertableColumns": headers("02_legal_entities.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/03_locations.csv": {
            "multiTable": False,
            "dbObject": "puls_core.locations",
            "insertableColumns": headers("03_locations.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/04_departments.csv": {
            "multiTable": False,
            "dbObject": "puls_core.departments",
            "insertableColumns": headers("04_departments.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/05_positions.csv": {
            "multiTable": False,
            "dbObject": "puls_core.positions",
            "insertableColumns": headers("05_positions.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/06_employees.csv": {
            "multiTable": False,
            "dbObject": "puls_core.employees",
            "insertableColumns": headers("06_employees.csv"),
            "excludedColumns": {
                "user_id": "PR13.5 auth bootstrap",
                "manager_employee_id": "cache",
                "legal_entity_id": "cache",
                "location_id": "cache",
                "cost_center_id": "cache",
            },
            "stagingOnlyColumns": [],
        },
        "csv/07_employee_reporting_lines.csv": {
            "multiTable": False,
            "dbObject": "puls_core.employee_reporting_lines",
            "insertableColumns": headers("07_employee_reporting_lines.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/08_employee_legal_entity_assignments.csv": {
            "multiTable": False,
            "dbObject": "puls_core.employee_legal_entity_assignments",
            "insertableColumns": headers("08_employee_legal_entity_assignments.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/09_employee_location_assignments.csv": {
            "multiTable": False,
            "dbObject": "puls_core.employee_location_assignments",
            "insertableColumns": headers("09_employee_location_assignments.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/10_cost_centers.csv": {
            "multiTable": False,
            "dbObject": "puls_core.cost_centers",
            "insertableColumns": headers("10_cost_centers.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/11_employee_cost_center_assignments.csv": {
            "multiTable": False,
            "dbObject": "puls_core.employee_cost_center_assignments",
            "insertableColumns": headers("11_employee_cost_center_assignments.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/12_leave_types.csv": {
            "multiTable": False,
            "dbObject": "puls_workflow.leave_types",
            "insertableColumns": headers("12_leave_types.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/13_approval_policies.csv": {
            "multiTable": True,
            "description": "Approval policies and steps",
            "stagingOnlyColumns": ["record_type", "target_table"],
            "targets": {
                "approval_policies": {
                    "dbObject": "puls_workflow.approval_policies",
                    "insertableColumns": ["id", "tenant_id", "code", "name", "module", "description", "is_active"],
                    "requiredColumns": ["id", "tenant_id", "code", "name", "module"],
                    "expectedRows": {"min": 2, "max": 4},
                },
                "approval_policy_steps": {
                    "dbObject": "puls_workflow.approval_policy_steps",
                    "insertableColumns": ["id", "tenant_id", "policy_id", "step_order", "approver_type", "specific_employee_id", "is_required"],
                    "requiredColumns": ["id", "tenant_id", "policy_id", "step_order", "approver_type"],
                    "expectedRows": {"min": 4, "max": 8},
                },
            },
        },
        "csv/14_leave_balances.csv": {
            "multiTable": False,
            "dbObject": "puls_workflow.leave_balances",
            "insertableColumns": headers("14_leave_balances.csv"),
            "excludedColumns": {"remaining_days": "GENERATED"},
            "stagingOnlyColumns": [],
        },
        "csv/15_expense_categories.csv": {
            "multiTable": False,
            "dbObject": "puls_workflow.expense_categories",
            "insertableColumns": headers("15_expense_categories.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/16_erp_connections.csv": {
            "multiTable": False,
            "dbObject": "puls_integration.erp_connections",
            "insertableColumns": headers("16_erp_connections.csv"),
            "excludedColumns": {"credentials_ref": "never seed credentials"},
            "stagingOnlyColumns": [],
        },
        "csv/17_erp_field_mappings.csv": {
            "multiTable": False,
            "dbObject": "puls_integration.erp_field_mappings",
            "insertableColumns": headers("17_erp_field_mappings.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/18_source_namespaces.csv": {
            "multiTable": False,
            "dbObject": "puls_integration.source_namespaces",
            "insertableColumns": headers("18_source_namespaces.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/19_entity_identity_map.csv": {
            "multiTable": False,
            "dbObject": "puls_integration.entity_identity_map",
            "insertableColumns": headers("19_entity_identity_map.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/20_performance_cycles.csv": {
            "multiTable": False,
            "dbObject": "puls_performance.performance_cycles",
            "insertableColumns": headers("20_performance_cycles.csv"),
            "stagingOnlyColumns": [],
        },
        "csv/21_performance_parameters.csv": {
            "multiTable": True,
            "description": "Multi-table baseline context file — setup parameters plus employee-scoped training/career context",
            "stagingOnlyColumns": ["target_table"],
            "targets": {
                "competency_templates": {
                    "dbObject": "puls_performance.competency_templates",
                    "insertableColumns": ["id", "tenant_id", "name", "description", "weight", "scale_min", "scale_max", "sort_order", "is_active"],
                    "requiredColumns": ["id", "tenant_id", "name"],
                    "expectedRows": {"min": 8, "max": 15},
                },
                "kpi_category_weights": {
                    "dbObject": "puls_performance.kpi_category_weights",
                    "insertableColumns": ["id", "tenant_id", "category_code", "category_name", "weight_pct", "sort_order", "is_active"],
                    "requiredColumns": ["id", "tenant_id", "category_code", "weight_pct"],
                    "expectedRows": {"min": 4, "max": 8},
                },
                "score_bands": {
                    "dbObject": "puls_performance.score_bands",
                    "insertableColumns": ["id", "tenant_id", "band", "label", "min_score", "max_score", "sort_order", "is_active"],
                    "requiredColumns": ["id", "tenant_id", "band", "min_score", "max_score"],
                    "expectedRows": {"min": 3, "max": 5},
                },
                "training_needs": {
                    "dbObject": "puls_performance.training_needs",
                    "insertableColumns": ["id", "tenant_id", "employee_id", "source_module", "skill_topic", "need_level", "priority", "status"],
                    "requiredColumns": ["id", "tenant_id", "employee_id", "skill_topic"],
                    "expectedRows": {"min": 20, "max": 40},
                },
                "career_profiles": {
                    "dbObject": "puls_performance.career_profiles",
                    "insertableColumns": ["id", "tenant_id", "employee_id", "current_step", "target_step", "readiness_score", "missing_competencies"],
                    "requiredColumns": ["id", "tenant_id", "employee_id", "current_step", "target_step"],
                    "expectedRows": {"min": 20, "max": 40},
                },
            },
        },
        "csv/22_contracts.csv": {
            "multiTable": False,
            "dbObject": "puls_workflow.contracts",
            "insertableColumns": headers("22_contracts.csv"),
            "stagingOnlyColumns": [],
        },
    },
}

# sync union headers for multi-table files from actual CSV
h21 = headers("21_performance_parameters.csv")
manifest["tableColumnMap"]["csv/21_performance_parameters.csv"]["unionHeader"] = h21
h13 = headers("13_approval_policies.csv")
manifest["tableColumnMap"]["csv/13_approval_policies.csv"]["unionHeader"] = h13

(ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("Wrote manifest.json")
