-- Demo seed: Mert Teknik placeholder tenant
-- Auth users must be created via Supabase Auth API / dashboard; link user_id after signup.

INSERT INTO public.tenants (id, legal_name, trade_name, tax_no, kvkk_active, verbis_registered, plan_name)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Mert Teknik Anonim Şirketi',
  'Mert Teknik',
  '1234567890',
  TRUE,
  TRUE,
  'growth'
);

INSERT INTO public.departments (id, tenant_id, name, code, is_active) VALUES
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111111', 'Genel Yönetim', 'GY', TRUE),
  ('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111111', 'İnsan Kaynakları', 'IK', TRUE),
  ('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111111', 'Üretim', 'URT', TRUE);

INSERT INTO public.positions (id, tenant_id, name, code, department_id, level, salary_min, salary_max) VALUES
  ('33333333-3333-3333-3333-333333333301', '11111111-1111-1111-1111-111111111111', 'Genel Müdür', 'GM', '22222222-2222-2222-2222-222222222201', 6, 150000, 250000),
  ('33333333-3333-3333-3333-333333333302', '11111111-1111-1111-1111-111111111111', 'İK Müdürü', 'IKM', '22222222-2222-2222-2222-222222222202', 5, 90000, 140000),
  ('33333333-3333-3333-3333-333333333303', '11111111-1111-1111-1111-111111111111', 'Üretim Uzmanı', 'URTU', '22222222-2222-2222-2222-222222222203', 3, 45000, 65000);

INSERT INTO public.employees (anonymous_id, tenant_id, email, full_name, job_title, department_id, position_id, persona_role, hire_date) VALUES
  ('44444444-4444-4444-4444-444444444401', '11111111-1111-1111-1111-111111111111', 'gm@mertteknik.demo', 'Demo Genel Müdür', 'Genel Müdür', '22222222-2222-2222-2222-222222222201', '33333333-3333-3333-3333-333333333301', 'manager', '2010-01-15'),
  ('44444444-4444-4444-4444-444444444402', '11111111-1111-1111-1111-111111111111', 'ik@mertteknik.demo', 'Demo İK Müdürü', 'İK Müdürü', '22222222-2222-2222-2222-222222222202', '33333333-3333-3333-3333-333333333302', 'hr_admin', '2012-03-01'),
  ('44444444-4444-4444-4444-444444444403', '11111111-1111-1111-1111-111111111111', 'calisan@mertteknik.demo', 'Demo Çalışan', 'Üretim Uzmanı', '22222222-2222-2222-2222-222222222203', '33333333-3333-3333-3333-333333333303', 'employee', '2020-06-01'),
  ('44444444-4444-4444-4444-444444444404', '11111111-1111-1111-1111-111111111111', 'yonetici@mertteknik.demo', 'Demo Yönetici', 'Üretim Şefi', '22222222-2222-2222-2222-222222222203', '33333333-3333-3333-3333-333333333303', 'manager', '2015-09-10'),
  ('44444444-4444-4444-4444-444444444405', '11111111-1111-1111-1111-111111111111', 'ik2@mertteknik.demo', 'Demo İK Uzmanı', 'İK Uzmanı', '22222222-2222-2222-2222-222222222202', '33333333-3333-3333-3333-333333333302', 'employee', '2018-11-20');

INSERT INTO public.erp_connections (id, tenant_id, provider, display_name, is_active, sync_schedule)
VALUES (
  '55555555-5555-5555-5555-555555555501',
  '11111111-1111-1111-1111-111111111111',
  'canias',
  'Canias ERP — Mert Teknik',
  FALSE,
  '30 4 * * *'
);

INSERT INTO public.erp_field_mappings (tenant_id, connection_id, erp_namespace, erp_field, puls_namespace, puls_canonical_field, transform_rule) VALUES
  ('11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555501', 'canias.hr', 'SICIL_NO', 'identity', 'employee_code', '{"trim": true}'::jsonb),
  ('11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555501', 'canias.hr', 'AD_SOYAD', 'identity', 'full_name', '{}'::jsonb),
  ('11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555501', 'canias.org', 'DEPARTMAN_KODU', 'identity', 'department.code', '{}'::jsonb);

INSERT INTO public.performans_competency_templates (tenant_id, name, description, weight, sort_order) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Liderlik', 'Ekip yönetimi ve yönlendirme', 1, 1),
  ('11111111-1111-1111-1111-111111111111', 'Stratejik Düşünme', 'Uzun vadeli planlama', 1, 2),
  ('11111111-1111-1111-1111-111111111111', 'İletişim', 'Sözlü ve yazılı iletişim', 1, 3);
