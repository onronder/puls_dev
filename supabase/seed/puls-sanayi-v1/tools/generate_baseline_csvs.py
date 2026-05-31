#!/usr/bin/env python3
"""Generate PR13.4 baseline CSV pack for Puls Sanayi A.Ş. (deterministic)."""
from __future__ import annotations

import csv
import json
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = ROOT / "csv"
TENANT = "a0000001-0001-4001-8001-000000000001"
ANCHOR = date(2026, 1, 1)


def uid(block: int, n: int) -> str:
    return f"a000{block:04d}-{block:04d}-40{block:02d}-80{block:02d}-{n:012d}"


def setup_code(value: str) -> str:
    return value.lower().replace("-", "_")


def write_csv(name: str, headers: list[str], rows: list[dict]) -> None:
    path = CSV_DIR / name
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=headers, extrasaction="ignore", lineterminator="\n")
        w.writeheader()
        for row in rows:
            w.writerow({h: row.get(h, "") for h in headers})


def main() -> None:
    erp_conn = uid(16, 1)
    ns_canias = uid(18, 1)
    legal = uid(2, 1)

    locations = [
        {"id": uid(3, 1), "code": "IST-HQ", "name": "İstanbul HQ"},
        {"id": uid(3, 2), "code": "BRS-PRD", "name": "Bursa Üretim"},
        {"id": uid(3, 3), "code": "IZM-SLS", "name": "İzmir Satış/Servis"},
    ]
    loc_by_code = {l["code"]: l["id"] for l in locations}

    dept_spec = [
        ("GM", "Genel Müdürlük", 4, "IST-HQ", False),
        ("IK", "İnsan Kaynakları", 6, "IST-HQ", False),
        ("FIN", "Finans", 10, "IST-HQ", True),
        ("SAT", "Satış", 16, "IZM-SLS", False),
        ("PAZ", "Pazarlama", 6, "IST-HQ", False),
        ("URT", "Operasyon/Üretim", 32, "BRS-PRD", True),
        ("SATIN", "Satınalma", 8, "BRS-PRD", True),
        ("LOJ", "Lojistik", 12, "BRS-PRD", True),
        ("KAL", "Kalite/İSG", 8, "BRS-PRD", False),
        ("BT", "BT", 7, "IST-HQ", False),
        ("ARGE", "Ar-Ge", 7, "IST-HQ", False),
        ("MOP", "Müşteri Operasyonları", 4, "IZM-SLS", False),
    ]

    departments: list[dict] = []
    for i, (code, name, _hc, _loc, imported) in enumerate(dept_spec, start=1):
        departments.append(
            {
                "id": uid(4, i),
                "tenant_id": TENANT,
                "code": setup_code(code),
                "name": name,
                "parent_id": uid(4, 1) if code != "GM" else "",
                "manager_employee_id": "",
                "cost_center_id": "",
                "external_source": "canias" if imported else "",
                "external_department_id": f"CAN-DEP-{code}" if imported else "",
                "is_active": "true",
            }
        )
    dept_by_code = {code: departments[i] for i, (code, *_rest) in enumerate(dept_spec)}

    cost_centers: list[dict] = []
    cc_codes = [
        ("CC-GM", "Genel Yönetim Giderleri", False),
        ("CC-IK", "İK Giderleri", False),
        ("CC-FIN", "Finans Giderleri", True),
        ("CC-SAT", "Satış Giderleri", False),
        ("CC-PAZ", "Pazarlama Giderleri", False),
        ("CC-URT", "Üretim Giderleri", True),
        ("CC-SATIN", "Satınalma Giderleri", True),
        ("CC-LOJ", "Lojistik Giderleri", True),
        ("CC-KAL", "Kalite Giderleri", False),
        ("CC-BT", "BT Giderleri", False),
        ("CC-ARGE", "Ar-Ge Giderleri", False),
        ("CC-MOP", "Müşteri Ops Giderleri", False),
        ("CC-IST", "İstanbul Merkez", False),
        ("CC-BRS", "Bursa Tesis", False),
        ("CC-IZM", "İzmir Ofis", False),
    ]
    for i, (code, name, imported) in enumerate(cc_codes, start=1):
        cost_centers.append(
            {
                "id": uid(10, i),
                "tenant_id": TENANT,
                "legal_entity_id": legal,
                "parent_cost_center_id": "",
                "code": code,
                "name": name,
                "source_namespace_id": ns_canias if imported else "",
                "external_id": f"CAN-CC-{code}" if imported else "",
                "is_active": "true",
            }
        )
    cc_by_dept = {
        "GM": "CC-GM",
        "IK": "CC-IK",
        "FIN": "CC-FIN",
        "SAT": "CC-SAT",
        "PAZ": "CC-PAZ",
        "URT": "CC-URT",
        "SATIN": "CC-SATIN",
        "LOJ": "CC-LOJ",
        "KAL": "CC-KAL",
        "BT": "CC-BT",
        "ARGE": "CC-ARGE",
        "MOP": "CC-MOP",
    }
    cc_id = {c["code"]: c["id"] for c in cost_centers}

    position_templates = {
        "GM": [("GM", "Genel Müdür", 6), ("GM-Y", "Yönetim Asistanı", 4)],
        "IK": [("IK-M", "İK Müdürü", 5), ("IK-U", "İK Uzmanı", 3), ("IK-AS", "İK Asistanı", 2)],
        "FIN": [("FIN-M", "Finans Müdürü", 5), ("FIN-U", "Finans Uzmanı", 3), ("FIN-MH", "Muhasebe Uzmanı", 3)],
        "SAT": [("SAT-M", "Satış Müdürü", 5), ("SAT-MH", "Satış Mühendisi", 4), ("SAT-T", "Satış Temsilcisi", 3), ("SAT-DST", "Satış Destek Uzmanı", 2)],
        "PAZ": [("PAZ-M", "Pazarlama Müdürü", 5), ("PAZ-U", "Pazarlama Uzmanı", 3)],
        "URT": [
            ("URT-M", "Üretim Müdürü", 5),
            ("URT-S", "Üretim Şefi", 4),
            ("URT-OP", "Üretim Operatörü", 2),
            ("URT-TEK", "Teknisyen", 3),
            ("URT-KAL", "Kalite Kontrol Operatörü", 2),
        ],
        "SATIN": [("SATIN-M", "Satınalma Müdürü", 5), ("SATIN-U", "Satınalma Uzmanı", 3), ("SATIN-AN", "Satınalma Analisti", 3)],
        "LOJ": [("LOJ-M", "Lojistik Müdürü", 5), ("LOJ-U", "Lojistik Uzmanı", 3), ("LOJ-OP", "Depo Operatörü", 2), ("LOJ-PLN", "Sevkiyat Planlama Uzmanı", 3)],
        "KAL": [("KAL-M", "Kalite Müdürü", 5), ("KAL-U", "Kalite Uzmanı", 3), ("ISG-U", "İSG Uzmanı", 3)],
        "BT": [("BT-M", "BT Müdürü", 5), ("BT-U", "BT Uzmanı", 3), ("BT-DEV", "Yazılım Geliştirici", 3)],
        "ARGE": [("ARGE-M", "Ar-Ge Müdürü", 5), ("ARGE-U", "Ar-Ge Mühendisi", 4)],
        "MOP": [("MOP-M", "Müşteri Ops Müdürü", 5), ("MOP-U", "Müşteri Temsilcisi", 3)],
    }

    positions: list[dict] = []
    pos_idx = 1
    pos_by_dept: dict[str, list[dict]] = {}
    for code, _name, _hc, _loc, imported in dept_spec:
        pos_by_dept[code] = []
        for p_code, p_name, level in position_templates[code]:
            pos = {
                "id": uid(5, pos_idx),
                "tenant_id": TENANT,
                "code": setup_code(p_code),
                "name": p_name,
                "department_id": dept_by_code[code]["id"],
                "level": str(level),
                "parent_position_id": "",
                "employment_type": "full_time",
                "norm_headcount": "1",
                "external_source": "canias" if imported and pos_idx % 3 == 0 else "",
                "external_position_id": f"CAN-POS-{p_code}" if imported and pos_idx % 3 == 0 else "",
                "is_active": "true",
            }
            positions.append(pos)
            pos_by_dept[code].append(pos)
            pos_idx += 1

    first_names = [
        "Ayşe", "Mehmet", "Elif", "Can", "Zeynep", "Burak", "Deniz", "Emre", "Selin", "Oğuz",
        "Merve", "Kerem", "Ece", "Barış", "Gamze", "Tolga", "Pınar", "Serkan", "Aslı", "Murat",
    ]
    last_names = [
        "Yılmaz", "Kaya", "Demir", "Çelik", "Şahin", "Yıldız", "Aydın", "Öztürk", "Arslan", "Doğan",
        "Kılıç", "Aslan", "Koç", "Kurt", "Özkan", "Polat", "Erdoğan", "Güneş", "Aksoy", "Tekin",
    ]

    employees: list[dict] = []
    emp_idx = 1
    dept_heads: dict[str, str] = {}

    for code, _name, headcount, _loc_code, _imp in dept_spec:
        dept_positions = pos_by_dept[code]
        head_pos = dept_positions[0]
        for n in range(headcount):
            fn = first_names[(emp_idx + n) % len(first_names)]
            ln = last_names[(emp_idx * 3 + n) % len(last_names)]
            if n == 0:
                title = head_pos["name"]
                pos = head_pos
                role = "manager" if code != "GM" else "superadmin"
            elif n == 1 and headcount > 4:
                title = dept_positions[1]["name"] if len(dept_positions) > 1 else dept_positions[0]["name"]
                pos = dept_positions[1] if len(dept_positions) > 1 else dept_positions[0]
                role = "manager"
            else:
                pos = dept_positions[min(2 + (n % max(1, len(dept_positions) - 2)), len(dept_positions) - 1)]
                title = pos["name"]
                role = "employee"
            if code == "IK" and n == 1:
                role = "hr_admin"
            hire = ANCHOR - timedelta(days=365 * ((emp_idx + n) % 12))
            emp = {
                "id": uid(6, emp_idx),
                "tenant_id": TENANT,
                "employee_code": f"PS-{emp_idx:03d}",
                "email": f"ps-{emp_idx:03d}@puls-sanayi.demo",
                "full_name": f"{fn} {ln}",
                "job_title": title,
                "department_id": dept_by_code[code]["id"],
                "position_id": pos["id"],
                "persona_role": role,
                "employment_status": "active",
                "hire_date": hire.isoformat(),
                "external_source": "",
                "external_employee_id": "",
            }
            employees.append(emp)
            if n == 0:
                dept_heads[code] = emp["id"]
            emp_idx += 1

    ceo_id = dept_heads["GM"]
    reporting: list[dict] = []
    r_idx = 1
    for emp in employees:
        if emp["id"] == ceo_id:
            continue
        dept_code = next(c for c, d in dept_by_code.items() if d["id"] == emp["department_id"])
        if emp["id"] == dept_heads.get(dept_code):
            mgr = ceo_id
        elif emp["persona_role"] == "manager":
            mgr = dept_heads[dept_code]
        else:
            mgr = dept_heads[dept_code]
            for e in employees:
                if e["department_id"] == emp["department_id"] and e["persona_role"] == "manager" and e["id"] != emp["id"]:
                    mgr = e["id"]
                    break
        reporting.append(
            {
                "id": uid(7, r_idx),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "manager_employee_id": mgr,
                "relationship_type": "primary_manager",
                "starts_on": "2026-01-01",
                "is_active": "true",
                "source": "bootstrap",
            }
        )
        r_idx += 1

    for d in departments:
        code = d["code"]
        if code in dept_heads:
            d["manager_employee_id"] = dept_heads[code]
            d["cost_center_id"] = cc_id[cc_by_dept[code]]

    le_assign, loc_assign, cc_assign = [], [], []
    a_idx = 1
    for emp in employees:
        dept_code = next(c for c, dd in dept_by_code.items() if dd["id"] == emp["department_id"])
        loc_code = next(lc for c, _n, _h, lc, _i in dept_spec if c == dept_code)
        le_assign.append(
            {
                "id": uid(8, a_idx),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "legal_entity_id": legal,
                "starts_on": "2026-01-01",
                "is_active": "true",
                "source": "bootstrap",
            }
        )
        loc_assign.append(
            {
                "id": uid(9, a_idx),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "location_id": loc_by_code[loc_code],
                "starts_on": "2026-01-01",
                "is_active": "true",
                "source": "bootstrap",
            }
        )
        cc_assign.append(
            {
                "id": uid(11, a_idx),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "cost_center_id": cc_id[cc_by_dept[dept_code]],
                "starts_on": "2026-01-01",
                "is_active": "true",
                "source": "bootstrap",
            }
        )
        a_idx += 1

    policies = [
        {"id": uid(13, 1), "code": "LEAVE-STD", "name": "Standart İzin Onayı", "module": "leave"},
        {"id": uid(13, 2), "code": "EXP-STD", "name": "Standart Masraf Onayı", "module": "expense"},
        {"id": uid(13, 3), "code": "LEAVE-HR", "name": "İK İzin Onayı", "module": "leave"},
    ]
    policy_rows: list[dict] = []
    step_idx = 1
    for p in policies:
        policy_rows.append(
            {
                "record_type": "policy",
                "target_table": "approval_policies",
                "id": p["id"],
                "tenant_id": TENANT,
                "code": p["code"],
                "name": p["name"],
                "module": p["module"],
                "description": f"{p['name']} policy",
                "is_active": "true",
                "step_order": "",
                "approver_type": "",
                "policy_id": "",
                "specific_employee_id": "",
                "is_required": "",
            }
        )
        for order, approver in [(1, "manager"), (2, "hr_admin")]:
            policy_rows.append(
                {
                    "record_type": "step",
                    "target_table": "approval_policy_steps",
                    "id": uid(13, 100 + step_idx),
                    "tenant_id": TENANT,
                    "code": "",
                    "name": "",
                    "module": "",
                    "description": "",
                    "is_active": "",
                    "step_order": str(order),
                    "approver_type": approver,
                    "policy_id": p["id"],
                    "specific_employee_id": "",
                    "is_required": "true",
                }
            )
            step_idx += 1

    leave_types = [
        ("yillik", "Yıllık İzin", "true", "14", uid(13, 1)),
        ("hastalik", "Hastalık İzni", "true", "0", uid(13, 1)),
        ("dogum", "Doğum İzni", "true", "112", uid(13, 3)),
        ("evlilik", "Evlilik İzni", "true", "3", uid(13, 1)),
        ("olum", "Ölüm İzni", "true", "3", uid(13, 1)),
        ("ucretsiz", "Ücretsiz İzin", "false", "0", uid(13, 1)),
        ("saatlik", "Saatlik İzin", "true", "0", uid(13, 1)),
        ("eski_tip", "Eski İzin Tipi (Pasif)", "true", "0", uid(13, 1)),
    ]
    lt_rows = []
    for i, (code, name, paid, ent, pol) in enumerate(leave_types, start=1):
        lt_rows.append(
            {
                "id": uid(12, i),
                "tenant_id": TENANT,
                "code": code,
                "name": name,
                "is_paid": paid,
                "default_entitlement_days": ent,
                "requires_document": "false",
                "requires_approval": "true",
                "show_in_calendar": "true",
                "carry_over_allowed": "true" if code == "yillik" else "false",
                "max_carry_over_days": "5" if code == "yillik" else "",
                "approval_policy_id": pol,
                "is_active": "false" if code == "eski_tip" else "true",
            }
        )
    annual_lt = lt_rows[0]["id"]

    leave_balances = []
    for i, emp in enumerate(employees, start=1):
        leave_balances.append(
            {
                "id": uid(14, i),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "leave_type_id": annual_lt,
                "period_year": "2026",
                "source": "puls",
                "entitlement_days": "14",
                "carried_over_days": str(i % 5),
                "adjustment_days": "0",
                "used_days": str(i % 4),
                "pending_days": "0",
                "as_of_date": "2026-01-01",
            }
        )

    expense_cats = [
        ("yemek", "Yemek", "5000", uid(13, 2)),
        ("ulasim", "Ulaşım", "8000", uid(13, 2)),
        ("konaklama", "Konaklama", "15000", uid(13, 2)),
        ("malzeme", "Ofis Malzemesi", "3000", uid(13, 2)),
        ("egitim", "Eğitim", "10000", uid(13, 2)),
        ("yakit", "Yakıt", "6000", uid(13, 2)),
        ("bakim", "Bakım/Onarım", "7000", uid(13, 2)),
        ("hed", "Hediye/İkram", "2000", uid(13, 2)),
        ("diger", "Diğer", "4000", uid(13, 2)),
        ("eski_kat", "Eski Kategori (Pasif)", "1000", uid(13, 2)),
    ]
    exp_rows = []
    for i, (code, name, lim, pol) in enumerate(expense_cats, start=1):
        exp_rows.append(
            {
                "id": uid(15, i),
                "tenant_id": TENANT,
                "code": code,
                "name": name,
                "monthly_limit": lim,
                "receipt_required_over": "500",
                "default_vat_rate": "20",
                "approval_policy_id": pol,
                "erp_account_code": f"770.{i:02d}",
                "is_active": "false" if code == "eski_kat" else "true",
            }
        )

    erp_mappings = []
    mapping_specs = [
        ("employee", "EMPLOYEE_CODE", "puls_core", "employees", "employee_code"),
        ("employee", "FULL_NAME", "puls_core", "employees", "full_name"),
        ("department", "DEPT_CODE", "puls_core", "departments", "code"),
        ("department", "DEPT_NAME", "puls_core", "departments", "name"),
        ("position", "POS_CODE", "puls_core", "positions", "code"),
        ("position", "POS_NAME", "puls_core", "positions", "name"),
        ("cost_center", "CC_CODE", "puls_core", "cost_centers", "code"),
        ("cost_center", "CC_NAME", "puls_core", "cost_centers", "name"),
        ("employee", "HIRE_DATE", "puls_core", "employees", "hire_date"),
        ("employee", "EMAIL", "puls_core", "employees", "email"),
        ("department", "MANAGER_CODE", "puls_core", "departments", "manager_employee_id"),
        ("location", "LOC_CODE", "puls_core", "locations", "code"),
    ]
    for i, (se, sf, ts, tt, tf) in enumerate(mapping_specs, start=1):
        erp_mappings.append(
            {
                "id": uid(17, i),
                "tenant_id": TENANT,
                "connection_id": erp_conn,
                "source_entity": se,
                "source_field": sf,
                "target_schema": ts,
                "target_table": tt,
                "target_field": tf,
                "transform_rule": "{}",
                "is_required": "false",
                "is_sensitive": "false",
                "is_active": "true",
            }
        )

    identity_map = []
    im_idx = 1
    for d in departments:
        if d["external_source"] == "canias":
            identity_map.append(
                {
                    "id": uid(19, im_idx),
                    "tenant_id": TENANT,
                    "source_namespace_id": ns_canias,
                    "entity_type": "department",
                    "external_id": d["external_department_id"],
                    "canonical_schema": "puls_core",
                    "canonical_table": "departments",
                    "canonical_id": d["id"],
                    "is_active": "true",
                }
            )
            im_idx += 1
    for p in positions:
        if p["external_source"] == "canias":
            identity_map.append(
                {
                    "id": uid(19, im_idx),
                    "tenant_id": TENANT,
                    "source_namespace_id": ns_canias,
                    "entity_type": "position",
                    "external_id": p["external_position_id"],
                    "canonical_schema": "puls_core",
                    "canonical_table": "positions",
                    "canonical_id": p["id"],
                    "is_active": "true",
                }
            )
            im_idx += 1
    for c in cost_centers:
        if c["source_namespace_id"]:
            identity_map.append(
                {
                    "id": uid(19, im_idx),
                    "tenant_id": TENANT,
                    "source_namespace_id": ns_canias,
                    "entity_type": "cost_center",
                    "external_id": c["external_id"],
                    "canonical_schema": "puls_core",
                    "canonical_table": "cost_centers",
                    "canonical_id": c["id"],
                    "is_active": "true",
                }
            )
            im_idx += 1

    perf_cycles = [
        {
            "id": uid(20, 1),
            "tenant_id": TENANT,
            "name": "2025 Performans Dönemi",
            "status": "closed",
            "starts_at": "2025-01-01",
            "ends_at": "2025-12-31",
            "scope": "tenant",
            "kpi_frequency": "quarterly",
        },
        {
            "id": uid(20, 2),
            "tenant_id": TENANT,
            "name": "2026 Performans Dönemi",
            "status": "active",
            "starts_at": "2026-01-01",
            "ends_at": "2026-12-31",
            "scope": "tenant",
            "kpi_frequency": "quarterly",
        },
    ]

    perf21_headers = [
        "target_table", "id", "tenant_id", "name", "description", "weight", "scale_min", "scale_max",
        "sort_order", "is_active", "category_code", "category_name", "weight_pct", "band", "label",
        "min_score", "max_score", "employee_id", "source_module", "skill_topic", "need_level",
        "priority", "status", "current_step", "target_step", "readiness_score", "missing_competencies",
    ]
    perf21: list[dict] = []
    competencies = [
        ("İletişim", "Etkili iletişim becerileri"),
        ("Takım Çalışması", "Ekip içi iş birliği"),
        ("Problem Çözme", "Analitik problem çözme"),
        ("Liderlik", "Ekip yönetimi ve koçluk"),
        ("Teknik Uzmanlık", "Alana özgü teknik bilgi"),
        ("Müşteri Odaklılık", "Müşteri ihtiyaçlarını anlama"),
        ("Planlama", "İş planlama ve önceliklendirme"),
        ("Kalite Bilinci", "Kalite standartlarına uyum"),
        ("İnovasyon", "Yenilikçi yaklaşım"),
        ("Uyum", "Değişime adaptasyon"),
    ]
    for i, (name, desc) in enumerate(competencies, start=1):
        perf21.append(
            {
                "target_table": "competency_templates",
                "id": uid(21, i),
                "tenant_id": TENANT,
                "name": name,
                "description": desc,
                "weight": "1",
                "scale_min": "1",
                "scale_max": "5",
                "sort_order": str(i),
                "is_active": "true",
            }
        )
    kpi_weights = [
        ("FIN", "Finansal", "30"),
        ("OPS", "Operasyonel", "25"),
        ("CUS", "Müşteri", "20"),
        ("PPL", "İnsan", "15"),
        ("INN", "İnovasyon", "10"),
    ]
    for i, (code, name, pct) in enumerate(kpi_weights, start=1):
        perf21.append(
            {
                "target_table": "kpi_category_weights",
                "id": uid(21, 100 + i),
                "tenant_id": TENANT,
                "category_code": code,
                "category_name": name,
                "weight_pct": pct,
                "sort_order": str(i),
                "is_active": "true",
            }
        )
    bands = [
        ("very_good", "Çok İyi", "90", "100"),
        ("good", "İyi", "75", "89.99"),
        ("expected", "Beklenen", "60", "74.99"),
        ("development", "Gelişim", "40", "59.99"),
        ("risk", "Risk", "0", "39.99"),
    ]
    for i, (band, label, mn, mx) in enumerate(bands, start=1):
        perf21.append(
            {
                "target_table": "score_bands",
                "id": uid(21, 200 + i),
                "tenant_id": TENANT,
                "band": band,
                "label": label,
                "min_score": mn,
                "max_score": mx,
                "sort_order": str(i),
                "is_active": "true",
            }
        )

    skills = [
        "Kaynak planlama", "SAP Canias", "Excel ileri", "Proje yönetimi", "İngilizce B2",
        "Statik kalite kontrol", "Forklift güvenliği", "CRM kullanımı", "SQL temel", "Sunum becerileri",
        "Zaman yönetimi", "Arıza giderme", "Satış müzakere", "Bütçe planlama", "Ekip koçluğu",
    ]
    for i in range(30):
        emp = employees[(i * 4) % len(employees)]
        perf21.append(
            {
                "target_table": "training_needs",
                "id": uid(21, 300 + i + 1),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "source_module": "performance",
                "skill_topic": skills[i % len(skills)],
                "need_level": "recommended",
                "priority": str((i % 5) + 1),
                "status": "open",
            }
        )

    for i in range(25):
        emp = employees[(i * 7 + 2) % len(employees)]
        if emp["id"] == ceo_id:
            emp = employees[3]
        perf21.append(
            {
                "target_table": "career_profiles",
                "id": uid(21, 400 + i + 1),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "current_step": "Uzman",
                "target_step": "Kıdemli Uzman",
                "readiness_score": str(55 + (i % 35)),
                "missing_competencies": '["Liderlik","Teknik Uzmanlık"]',
            }
        )

    contracts = []
    for i in range(20):
        emp = employees[i * 6 % len(employees)]
        contracts.append(
            {
                "id": uid(22, i + 1),
                "tenant_id": TENANT,
                "employee_id": emp["id"],
                "contract_type": "employment",
                "start_date": "2024-01-01" if i % 2 else "2025-06-01",
                "end_date": "2027-12-31" if i % 3 else "",
                "status": "active",
                "signature_status": "signed" if i % 4 else "awaiting",
                "risk_band": ["low", "medium", "high"][i % 3],
                "metadata_only": "true",
                "external_source": "",
                "external_contract_id": "",
            }
        )

    write_csv(
        "01_tenant.csv",
        ["id", "name", "legal_name", "trade_name", "tax_no", "industry", "timezone", "locale", "plan_name", "kvkk_active"],
        [{
            "id": TENANT,
            "name": "Puls Sanayi A.Ş.",
            "legal_name": "Puls Sanayi Anonim Şirketi",
            "trade_name": "Puls Sanayi",
            "tax_no": "9876543210",
            "industry": "Endüstriyel ekipman imalatı ve saha servisi",
            "timezone": "Europe/Istanbul",
            "locale": "tr-TR",
            "plan_name": "enterprise",
            "kvkk_active": "true",
        }],
    )
    write_csv("02_legal_entities.csv", ["id", "tenant_id", "code", "name", "is_active"], [
        {"id": legal, "tenant_id": TENANT, "code": "PS-LE", "name": "Puls Sanayi A.Ş.", "is_active": "true"}
    ])
    write_csv("03_locations.csv", ["id", "tenant_id", "legal_entity_id", "code", "name", "is_active"], [
        {"id": l["id"], "tenant_id": TENANT, "legal_entity_id": legal, "code": l["code"], "name": l["name"], "is_active": "true"}
        for l in locations
    ])
    write_csv(
        "04_departments.csv",
        ["id", "tenant_id", "code", "name", "parent_id", "manager_employee_id", "cost_center_id", "external_source", "external_department_id", "is_active"],
        departments,
    )
    write_csv(
        "05_positions.csv",
        ["id", "tenant_id", "code", "name", "department_id", "level", "parent_position_id", "employment_type", "norm_headcount", "external_source", "external_position_id", "is_active"],
        positions,
    )
    write_csv(
        "06_employees.csv",
        ["id", "tenant_id", "employee_code", "email", "full_name", "job_title", "department_id", "position_id", "persona_role", "employment_status", "hire_date", "external_source", "external_employee_id"],
        employees,
    )
    write_csv(
        "07_employee_reporting_lines.csv",
        ["id", "tenant_id", "employee_id", "manager_employee_id", "relationship_type", "starts_on", "is_active", "source"],
        reporting,
    )
    write_csv(
        "08_employee_legal_entity_assignments.csv",
        ["id", "tenant_id", "employee_id", "legal_entity_id", "starts_on", "is_active", "source"],
        le_assign,
    )
    write_csv(
        "09_employee_location_assignments.csv",
        ["id", "tenant_id", "employee_id", "location_id", "starts_on", "is_active", "source"],
        loc_assign,
    )
    write_csv(
        "10_cost_centers.csv",
        ["id", "tenant_id", "legal_entity_id", "parent_cost_center_id", "code", "name", "source_namespace_id", "external_id", "is_active"],
        cost_centers,
    )
    write_csv(
        "11_employee_cost_center_assignments.csv",
        ["id", "tenant_id", "employee_id", "cost_center_id", "starts_on", "is_active", "source"],
        cc_assign,
    )
    write_csv(
        "12_leave_types.csv",
        ["id", "tenant_id", "code", "name", "is_paid", "default_entitlement_days", "requires_document", "requires_approval", "show_in_calendar", "carry_over_allowed", "max_carry_over_days", "approval_policy_id", "is_active"],
        lt_rows,
    )
    write_csv(
        "13_approval_policies.csv",
        ["record_type", "target_table", "id", "tenant_id", "code", "name", "module", "description", "is_active", "step_order", "approver_type", "policy_id", "specific_employee_id", "is_required"],
        policy_rows,
    )
    write_csv(
        "14_leave_balances.csv",
        ["id", "tenant_id", "employee_id", "leave_type_id", "period_year", "source", "entitlement_days", "carried_over_days", "adjustment_days", "used_days", "pending_days", "as_of_date"],
        leave_balances,
    )
    write_csv(
        "15_expense_categories.csv",
        ["id", "tenant_id", "code", "name", "monthly_limit", "receipt_required_over", "default_vat_rate", "approval_policy_id", "erp_account_code", "is_active"],
        exp_rows,
    )
    write_csv(
        "16_erp_connections.csv",
        ["id", "tenant_id", "provider", "display_name", "connection_method", "base_url", "firm_code", "is_active", "sync_direction", "sync_schedule"],
        [{
            "id": erp_conn,
            "tenant_id": TENANT,
            "provider": "canias",
            "display_name": "Canias ERP (Pasif)",
            "connection_method": "rest_api",
            "base_url": "",
            "firm_code": "PS01",
            "is_active": "false",
            "sync_direction": "erp_to_puls",
            "sync_schedule": "",
        }],
    )
    write_csv(
        "17_erp_field_mappings.csv",
        ["id", "tenant_id", "connection_id", "source_entity", "source_field", "target_schema", "target_table", "target_field", "transform_rule", "is_required", "is_sensitive", "is_active"],
        erp_mappings,
    )
    write_csv(
        "18_source_namespaces.csv",
        ["id", "tenant_id", "code", "name", "source_type", "priority_rank", "connection_id", "is_active"],
        [{
            "id": ns_canias,
            "tenant_id": TENANT,
            "code": "CANIAS",
            "name": "Canias ERP Kaynağı",
            "source_type": "erp",
            "priority_rank": "1",
            "connection_id": erp_conn,
            "is_active": "true",
        }],
    )
    write_csv(
        "19_entity_identity_map.csv",
        ["id", "tenant_id", "source_namespace_id", "entity_type", "external_id", "canonical_schema", "canonical_table", "canonical_id", "is_active"],
        identity_map,
    )
    write_csv(
        "20_performance_cycles.csv",
        ["id", "tenant_id", "name", "status", "starts_at", "ends_at", "scope", "kpi_frequency"],
        perf_cycles,
    )
    write_csv("21_performance_parameters.csv", perf21_headers, perf21)
    write_csv(
        "22_contracts.csv",
        ["id", "tenant_id", "employee_id", "contract_type", "start_date", "end_date", "status", "signature_status", "risk_band", "metadata_only", "external_source", "external_contract_id"],
        contracts,
    )

    meta = {
        "generatedEmployees": len(employees),
        "generatedReporting": len(reporting),
        "generatedTrainingNeeds": sum(1 for r in perf21 if r["target_table"] == "training_needs"),
        "generatedCareerProfiles": sum(1 for r in perf21 if r["target_table"] == "career_profiles"),
        "generatedIdentityMap": len(identity_map),
        "generatedPositions": len(positions),
    }
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
