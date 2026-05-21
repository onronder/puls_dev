# Supabase Demo Data Ihtiyaclari

Bu dokuman, frontend ekranlarinin dolu gorunmesi icin Supabase'e atilmasi gereken minimum demo veri setini tarif eder. Gercek ERP entegrasyonu musteri API'lari ile sonradan gelecegi icin bu data, demo ve development seed amaclidir.

## 1. Mevcut Tablolar ve Kullanilacaklar

Proje ozetine gore mevcut/planli tablolar:

| Tablo | Durum | Frontend kullanim |
|---|---|---|
| `profiles` | Lovable auth | Login/profile |
| `tenants` | Lovable auth | Tenant adi |
| `user_tenants` | Lovable auth | Kullanici-tenant iliskisi |
| `user_roles` | Lovable auth | Rol/persona fallback |
| `departments` | Puls | Dashboard, calisanlar, ayarlar |
| `positions` | Puls | Dashboard, calisanlar, ayarlar |
| `employees` | Puls | Tum HR ekranlari |
| `erp_connections` | Puls | Dashboard, ERP ayarlari |
| `erp_field_mappings` | Puls | ERP ayarlari |
| `erp_sync_logs` | Puls | ERP durum/senkron |
| `performans_competency_templates` | Puls | Performans |
| `performans_cycles` | PR #6 | Donem yonetimi |
| `puls_vault.conversation_messages` | Ileri | AI Koc MVP-2 |
| `puls_audit.audit_logs` | Puls audit | Activity/audit |

Bu ekran seti icin ek demo tablolar ya da view'lar gerekebilir. Bunlar hemen gercek production model olmak zorunda degil; migration ile eklenebilir veya Supabase view/mock table olarak baslanabilir.

## 2. Eklenmesi Onerilen Demo/MVP Tablolari

### 2.1 Izin

`leave_types`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| tenant_id | uuid | Mert Teknik |
| code | text | annual |
| name | text | Yillik Izin |
| paid | boolean | true |
| default_days | numeric | 20 |
| requires_document | boolean | false |
| requires_approval | boolean | true |
| is_active | boolean | true |

Seed izin tipleri:

1. Yillik Izin
2. Hastalik Izni
3. Mazeret Izni
4. Dogum Izni
5. Evlilik Izni
6. Olum Izni
7. Ucretsiz Izin
8. Telafi Izni

`leave_balances`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| tenant_id | uuid | - |
| employee_id | uuid | Demo IK |
| leave_type_id | uuid | annual |
| year | int | 2026 |
| total_days | numeric | 20 |
| used_days | numeric | 6 |
| pending_days | numeric | 5 |
| remaining_days | numeric | 14 |

`leave_requests`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| tenant_id | uuid | - |
| employee_id | uuid | - |
| leave_type_id | uuid | annual |
| start_date | date | 2026-07-14 |
| end_date | date | 2026-07-18 |
| business_days | numeric | 5 |
| delegate_employee_id | uuid | Ozge |
| description | text | Yaz izni |
| status | enum/text | pending/approved/rejected/cancelled |
| approver_employee_id | uuid | manager |
| approved_at | timestamptz | nullable |
| rejection_reason | text | nullable |

Minimum demo:

- Demo IK icin 4 izin talebi.
- Diger calisanlar icin takvimde gorunecek 2 onayli izin.
- 2 bekleyen izin onayi.

### 2.2 Masraf

`expense_categories`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| tenant_id | uuid | - |
| code | text | travel |
| name | text | Seyahat |
| monthly_limit | numeric | 15000 |
| requires_receipt_over | numeric | 0 |
| approval_level | text | manager |
| accounting_code | text | 760.01 |
| is_active | boolean | true |

Seed kategorileri:

1. Seyahat
2. Konaklama
3. Yemek
4. Temsil
5. Egitim
6. Ofis
7. Ulasim

`expense_claims`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| tenant_id | uuid | - |
| employee_id | uuid | - |
| category_id | uuid | travel |
| amount | numeric | 2340 |
| currency | text | TRY |
| tax_included | boolean | true |
| tax_rate | numeric | 20 |
| expense_date | date | 2026-05-10 |
| title | text | Istanbul-Ankara ucak |
| description | text | Musteri ziyareti |
| receipt_url | text | nullable |
| status | text | draft/pending/approved/rejected/paid |
| approver_employee_id | uuid | manager |
| finance_status | text | pending/paid |

Minimum demo:

- Demo kullanici icin 8 masraf.
- 2 pending, 4 approved, 1 rejected, 1 paid.
- Bu ay onaylanan toplam demo metrikle uyumlu olmali.

### 2.3 Performans

Mevcut:

- `performans_competency_templates`
- `performans_cycles`

Onerilen:

`performance_scores`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| tenant_id | uuid | - |
| employee_id | uuid | - |
| cycle_id | uuid | 2026 H1 |
| kpi_score | numeric | 92 |
| competency_score | numeric | 4.3 |
| overall_score | numeric | 93.6 |
| status_band | text | very_good |
| updated_at | timestamptz | - |

`performance_kpis`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| employee_id | uuid | - |
| cycle_id | uuid | - |
| category | text | Stratejik IK |
| name | text | KPI stratejisi tamamlanma |
| target_value | numeric | 100 |
| actual_value | numeric | 94 |
| unit | text | percent |
| weight | numeric | 20 |
| source | text | manual/erp |

Minimum demo:

- 1 aktif donem.
- 4 calisan icin score.
- Demo IK icin 6 KPI satiri.
- 3 yetkinlik degerlendirme satiri.

### 2.4 Sozlesme

`contracts`

| Alan | Tip | Ornek |
|---|---|---|
| id | uuid | - |
| tenant_id | uuid | - |
| employee_id | uuid | - |
| contract_type | text | Belirsiz Sureli |
| start_date | date | 2025-01-01 |
| end_date | date | nullable |
| status | text | active/expiring/ended |
| signature_status | text | signed/awaiting |
| file_url | text | nullable |

Minimum demo:

- 4 aktif sozlesme.
- 1 yaklasan bitis.
- 1 imza bekleyen.

### 2.5 Activity / Audit

Eger `puls_audit.audit_logs` kullanilacaksa dashboard activity icin view yeterli:

`dashboard_activity_view`

Alanlar:

- id
- tenant_id
- actor_name
- module
- action_label
- entity_label
- status
- created_at

Minimum demo activity:

- ERP baglantisi olusturuldu.
- Demo calisan eklendi.
- Yetkinlik sablonu eklendi.
- Izin talebi olusturuldu.
- Masraf bildirimi gonderildi.
- Performans donemi acildi.

## 3. Demo Verinin Tutarlilik Kurallari

Artifact'ta duzeltilmesi gereken hard-coded degerler:

| Artifact Degeri | Yeni Demo Degeri |
|---|---|
| Logo Tiger bagli | Canias pasif / baglanti hazir |
| 104 aktif calisan | 4 aktif calisan |
| 8 departman | 3 departman |
| 24 pozisyon | 3 pozisyon |
| Mevlut Yilmaz Genel Mudur + IK Direktoru karisik | Demo IK Yoneticisi veya tek persona |
| 10,7 / 10 Baglilik | 8,7 / 10 veya %87 |

## 4. Demo Data Seti Onerisi

Tenant:

- Mert Teknik A.S.

Departmanlar:

1. Insan Kaynaklari
2. Uretim
3. Finans

Pozisyonlar:

1. IK Yoneticisi
2. Uretim Muduru
3. Finans Uzmani

Calisanlar:

1. Demo IK Yoneticisi, IK Yoneticisi, persona `ik_admin`
2. Ayse Demir, Finans Uzmani, persona `finans`
3. Mehmet Kaya, Uretim Muduru, persona `yonetici`
4. Ozge Buyuksahin, IK Uzmani veya Calisan, persona `calisan`

ERP:

- Provider: Canias.
- Status: inactive/configured.
- Last sync: null.
- Mapping completion: 0-40%.

Izin:

- Demo IK: 20 yillik hak, 6 kullanilmis, 14 kalan.
- 2 pending request.
- 2 approved historical request.
- Ozge ve Onur/Mehmet icin takvim eventleri.

Masraf:

- Demo IK: aylik limit 15000 TRY.
- Bu ay onaylanan 8640 TRY.
- Bekleyen toplam 2340 TRY olacak sekilde 2 pending kayit:
  - Is yemegi: 450 TRY.
  - Ulasim/Temsil: 1890 TRY.
- Yil toplami yaklasik 34200 TRY.

Performans:

- Aktif donem: 2026 H1.
- Demo IK overall score: 93.6.
- Diger calisan skorlarini 72-88 araliginda tut.
- Skala disina cikma: tum 10 uzerinden skorlar max 10.

## 5. Frontend Query Stratejisi

Her sayfa icin query yapisi:

- `useTenant()`
- `usePersona()`
- `useDashboardMetrics()`
- `usePerformanceOverview()`
- `useLeaveOverview(employeeId | scope)`
- `useExpenseOverview(employeeId | scope)`
- `useMenuItems(persona)`

Demo data yoksa:

- Empty state goster.
- Hard-coded sayi basma.
- Sadece development flag altinda `demoFallback` kullan.

## 6. Seed Dosyasi Onerisi

Cursor icin tek seed hedefi:

- `supabase/seed-demo-core.sql`
- `supabase/seed-demo-self-service.sql`
- `supabase/seed-demo-performance.sql`

Ilk etapta tek dosya da kabul:

- `supabase/seed-demo.sql` genisletilebilir.

Seed tekrar calistirilabilir olmali:

- Tenant natural key veya fixed UUID.
- `insert ... on conflict do update`.
- User auth kaydi manuel/Supabase Auth nedeniyle dikkatli.
- Demo employee kayitlari auth user olmadan da listeleri doldurabilmeli.
