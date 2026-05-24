-- Synthetic demo data for Lovable auth schema (run in Supabase SQL Editor).
-- 1. Replace USER_UUID below with your auth.users id (Dashboard → Authentication → Users).
-- 2. Run the full script once.

DO $$
DECLARE
  v_user_id UUID := 'REPLACE_WITH_YOUR_AUTH_USER_UUID';
  v_tenant_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  INSERT INTO public.tenants (
    id, name, vkn, sector, plan, status, timezone,
    legal_name, trade_name, tax_no, plan_name
  )
  VALUES (
    v_tenant_id,
    'Mert Teknik A.Ş.',
    '1234567890',
    'İmalat',
    'growth',
    'active',
    'Europe/Istanbul',
    'Mert Teknik Anonim Şirketi',
    'Mert Teknik',
    '1234567890',
    'growth'
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    legal_name = EXCLUDED.legal_name,
    trade_name = EXCLUDED.trade_name;

  INSERT INTO public.departments (id, tenant_id, name, code, is_active) VALUES
    ('22222222-2222-2222-2222-222222222201', v_tenant_id, 'Genel Yönetim', 'GY', TRUE),
    ('22222222-2222-2222-2222-222222222202', v_tenant_id, 'İnsan Kaynakları', 'IK', TRUE),
    ('22222222-2222-2222-2222-222222222203', v_tenant_id, 'Üretim', 'URT', TRUE)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.positions (id, tenant_id, name, code, department_id, level, salary_min, salary_max) VALUES
    ('33333333-3333-3333-3333-333333333301', v_tenant_id, 'Genel Müdür', 'GM', '22222222-2222-2222-2222-222222222201', 6, 150000, 250000),
    ('33333333-3333-3333-3333-333333333302', v_tenant_id, 'İK Müdürü', 'IKM', '22222222-2222-2222-2222-222222222202', 5, 90000, 140000),
    ('33333333-3333-3333-3333-333333333303', v_tenant_id, 'Üretim Uzmanı', 'URTU', '22222222-2222-2222-2222-222222222203', 3, 45000, 65000)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.employees (anonymous_id, tenant_id, user_id, email, full_name, job_title, department_id, position_id, persona_role, hire_date) VALUES
    ('44444444-4444-4444-4444-444444444402', v_tenant_id, NULL, 'gm@mertteknik.demo', 'Demo Genel Müdür', 'Genel Müdür', '22222222-2222-2222-2222-222222222201', '33333333-3333-3333-3333-333333333301', 'manager', '2010-01-15'),
    ('44444444-4444-4444-4444-444444444401', v_tenant_id, v_user_id, 'demo@mertteknik.local', 'Demo İK Yöneticisi', 'İK Müdürü', '22222222-2222-2222-2222-222222222202', '33333333-3333-3333-3333-333333333302', 'hr_admin', '2012-03-01'),
    ('44444444-4444-4444-4444-444444444403', v_tenant_id, NULL, 'calisan@mertteknik.demo', 'Demo Çalışan', 'Üretim Uzmanı', '22222222-2222-2222-2222-222222222203', '33333333-3333-3333-3333-333333333303', 'employee', '2020-06-01'),
    ('44444444-4444-4444-4444-444444444404', v_tenant_id, NULL, 'yonetici@mertteknik.demo', 'Demo Yönetici', 'Üretim Şefi', '22222222-2222-2222-2222-222222222203', '33333333-3333-3333-3333-333333333303', 'manager', '2015-09-10'),
    ('44444444-4444-4444-4444-444444444405', v_tenant_id, NULL, 'ik2@mertteknik.demo', 'Demo İK Uzmanı', 'İK Uzmanı', '22222222-2222-2222-2222-222222222202', '33333333-3333-3333-3333-333333333302', 'employee', '2018-11-20')
  ON CONFLICT (anonymous_id) DO NOTHING;

  -- Wire department managers after employees exist (FK: manager_employee_id → public.employees)
  UPDATE public.departments SET manager_employee_id = '44444444-4444-4444-4444-444444444402'::uuid
  WHERE id = '22222222-2222-2222-2222-222222222201'::uuid AND tenant_id = v_tenant_id;

  UPDATE public.departments SET manager_employee_id = '44444444-4444-4444-4444-444444444401'::uuid
  WHERE id = '22222222-2222-2222-2222-222222222202'::uuid AND tenant_id = v_tenant_id;

  UPDATE public.departments SET manager_employee_id = '44444444-4444-4444-4444-444444444404'::uuid
  WHERE id = '22222222-2222-2222-2222-222222222203'::uuid AND tenant_id = v_tenant_id;

  IF NOT EXISTS (SELECT 1 FROM public.user_tenants WHERE user_id = v_user_id AND tenant_id = v_tenant_id) THEN
    INSERT INTO public.user_tenants (user_id, tenant_id, is_default) VALUES (v_user_id, v_tenant_id, TRUE);
  END IF;

  -- Optional user_roles (use a valid app_role enum value for your project):
  -- patron | ik_admin | yonetici | calisan | finans | hukuk_uyum
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_user_id AND tenant_id = v_tenant_id) THEN
    INSERT INTO public.user_roles (user_id, tenant_id, role) VALUES (v_user_id, v_tenant_id, 'ik_admin');
  END IF;

  INSERT INTO public.erp_connections (id, tenant_id, provider, display_name, is_active, sync_schedule)
  VALUES (
    '55555555-5555-5555-5555-555555555501',
    v_tenant_id,
    'canias',
    'Canias ERP — Mert Teknik (demo)',
    FALSE,
    '30 4 * * *'
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.performans_competency_templates (tenant_id, name, description, weight, sort_order)
  SELECT v_tenant_id, 'Liderlik', 'Ekip yönetimi ve yönlendirme', 1, 1
  WHERE NOT EXISTS (SELECT 1 FROM public.performans_competency_templates WHERE tenant_id = v_tenant_id AND name = 'Liderlik');

  INSERT INTO public.performans_competency_templates (tenant_id, name, description, weight, sort_order)
  SELECT v_tenant_id, 'Stratejik Düşünme', 'Uzun vadeli planlama', 1, 2
  WHERE NOT EXISTS (SELECT 1 FROM public.performans_competency_templates WHERE tenant_id = v_tenant_id AND name = 'Stratejik Düşünme');

  INSERT INTO public.performans_competency_templates (tenant_id, name, description, weight, sort_order)
  SELECT v_tenant_id, 'İletişim', 'Sözlü ve yazılı iletişim', 1, 3
  WHERE NOT EXISTS (SELECT 1 FROM public.performans_competency_templates WHERE tenant_id = v_tenant_id AND name = 'İletişim');

  INSERT INTO public.performans_cycles (tenant_id, name, status, starts_at, ends_at)
  SELECT v_tenant_id, '2026 Yıllık Değerlendirme', 'active', '2026-01-01', '2026-12-31'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.performans_cycles
    WHERE tenant_id = v_tenant_id AND name = '2026 Yıllık Değerlendirme'
  );
END $$;
