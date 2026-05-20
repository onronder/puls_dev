# PULS AI Coach — Cursor Composer 2.5 Başlangıç Promptu (v2 — Mobile-First, Boş Repo)

> **Kullanım:** Bu dokümanın tamamını Cursor Composer Agent moduna yapıştır. Agent önce **0. Onay & Bağlam Doğrulama** bölümünü tamamlamalı, ardından **9. Sprint-1: Foundation & Scaffold** ile somut işe başlamalı.
>
> **Önemli Bağlam:** Yeni boş repo (`puls_dev`) ile sıfırdan başlıyoruz. Eski `puls-core` reposundaki Lovable çıktısı **sadece referans** — kopyala-yapıştır değil, öğrenme materyali. Hedef: **mobile-first + kaliteli web** — landing site (https://pulshr.netlify.app) görsel/etkileşim referansı.

---

## 0. Onay & Bağlam Doğrulama (Agent İlk Adım)

Cursor Agent, koda dokunmadan önce şunları yap:

1. Aktif repo'nun `puls_dev` (boş) olduğunu doğrula.
2. `/Users/onuronder/Documents/Claude/Projects/Puls/` altındaki üç **v1.0** referans dokümanı oku ve indeksle:
   - `Puls_Mimari_Kararlar_Dokumani_v1.0.docx` (77 sayfa — mühendislik anayasası, 14 bölüm + 2 ek)
   - `Puls_Veri_Sozlugu_v1.0.xlsx` (25 sheet — alan-bazlı veri sözlüğü)
   - `Puls_UX_UI_Audit_Raporu_v1.0.docx` (56 sayfa — 19 ekran UX/UI audit + pazar konumlama)
3. `/Users/onuronder/Documents/Claude/Projects/Puls/EkranGörüntüleri/` altındaki 19 PNG'yi tarayıp her birinin hangi modüle ait olduğunu Veri Sözlüğü ile eşle.
4. **Landing site** https://pulshr.netlify.app'i tarayıcıda incele (renk paleti, tipografi, mobil mockup stili, "Conversation-first AI HR platform" mesajı). Bu site tasarım sistemimizin **canlı kaynağıdır**.
5. **Eski referans repo** `/Users/onuronder/puls-core/` — Lovable'ın ürettiği ilk iskelet. Sadece component örnekleri ve i18n yapısı için bak; **kopyalama**.
6. Kullanıcıya **kısa bir özet** ver (max 200 kelime): "Bağlamı anladım — şu var, şu yok, ilk işin şu olacak, şu sorum var."
7. Kullanıcı onay verene kadar **kod yazma**.

---

## 1. Proje Tek Cümlede

**PULS AI Coach** — Türkiye 50-250 çalışanlı KOBİ'leri için **Self-HR Platform**. Apple Sağlık'ın sağlık alanında yaptığını İK'da yapar: çalışan kendi kariyer sağlığını (KPI, hedefler, kariyer ilerlemesi, hak ve sorumlulukları) kendi rızasıyla, kendi gözünden yönetir. AI Koç™ bu sistemin merkezi — çalışan ile doğal dilde konuşur, yöneticiye anonim sinyaller üretir. 4857 İş Kanunu ve KVKK ekran-içine yerleştirilmiş, $20/kullanıcı/ay AI Coach paketi ile fiyat-erişilebilir.

**Pazar konumlanma cümlesi:** *"Türkiye KOBİ'sinin İlk Konuşma-Önce İK Platformu — 4857 maddeleri ekran içinde, KVKK k-anonymity gizliliği yerleşik, klasik İK metodolojisi (İş Analizi → İş Değerleme → Pozisyon KPI) tek workflow'da, AI Koç ile."*

---

## 2. Mevcut Durum

### Yeni Çalışma Repo'su
- **`puls_dev`** — boş, sıfırdan kurulacak. Tüm scaffold + iskelet burada inşa edilir.

### Eski Referans Repo (sadece okumak için)
- **`/Users/onuronder/puls-core/`** — Lovable'ın ürettiği ilk iskelet. Stack: TanStack Start v1.167 + React 19 + shadcn/ui + Tailwind v4 + Capacitor v8. Tüm `useQuery` hook'ları fixture döndürüyor; gerçek backend yok.
- **Cursor için kural:** Bu repo'dan **kopyala-yapıştır yapma**. Sadece (a) folder structure, (b) i18n setup, (c) shadcn/ui component listesinin nasıl organize edildiği, (d) Capacitor config örnekleri için bak. Yeniden yaz.

### Canlı Pazarlama Sitesi (TASARIM REFERANSI)
- **https://pulshr.netlify.app** — karanlık tema + neon yeşil (#00C853-benzeri) accent. Hero: "KOBİ'ler için kariyer sağlığı, iş hukuku uyumu ve proaktif İK sistemi." Mobil mockup'lar iPhone frame içinde. Çalışan persona'sına hitap eden ses tonu.
- **Cursor için kural:** Renk paleti, tipografi, spacing, mockup kompozisyonu **bu siteyle uyumlu** olmalı. Inspector kullanarak veya screenshot'lardan token'ları çıkar.

### Demo Mockup (UI Referans)
- Artifact URL: `https://claude.ai/public/artifacts/b527cc16-99cf-43fe-82b7-399325c69635` — 19 sayfa interaktif UI mockup (desktop-bias).
- 19 PNG'si `EkranGörüntüleri/` altında.
- **Cursor için kural:** Bu mockup desktop-bias; bizim hedefimiz mobile-first. UX/UI Audit Bölüm 4'teki bulgulara göre revize ederek implement et — birebir kopyalama.

### Sunum (Pitch)
- `PULS-ITU-Cekirdek-Pitch-Final.pdf` — 12 sayfa. Pazar konumlanma + 26 ekran + ekip + traction. Stratejik mesajları (Apple Sağlık metaforu, anonim sinyal sistemi, Türkiye-yerli regülasyon) kod-içi ve UI-içi mesajlarla uyumlu olmalı.

---

## 3. Mobile-First İlke (BAĞLAYICI — Önceki versiyondan değişti)

**Tüm UI önce mobile için tasarlanır, sonra tablet/desktop genişletilir.** Bu bir ekran-uyumluluk meselesi değil, **ürün kimliğidir**: Çalışan persona'sı işin %80'ini telefonda yapacak (izin talebi, masraf fişi, AI Koç sohbeti, KPI bakma).

### Mobile-First Standartları

| Boyut | Hedef | Notlar |
|---|---|---|
| Default viewport | 375px (iPhone SE/13 mini) | Tasarım baseline |
| Breakpoint sm | 640px | Tablet portrait |
| Breakpoint md | 768px | Tablet landscape / küçük laptop |
| Breakpoint lg | 1024px | Desktop |
| Breakpoint xl | 1280px | Geniş desktop |
| Touch target min | 44×44 pt | Apple HIG + WCAG 2.5.5 |
| Bottom tab nav | Var (mobile) | Çalışan persona |
| Sidebar nav | Var (desktop) | Yönetici persona ağırlıklı |
| Floating widget | Var (her persona + her sayfa) | AI Koç (audit C1 zorunluluk) |

### Mobile-First Kod Konvansiyonu
- Tailwind class'ları **mobile-first** yazılır: `text-base md:text-lg lg:text-xl` (default = mobile).
- Layout: önce stack (column), sonra grid. `flex flex-col md:flex-row` deseni.
- Bottom-sheet, swipe-to-action, pull-to-refresh — mobile-native interaction patterns kullan.
- Capacitor native API'leri (Camera, Haptics, StatusBar) prefer (web fallback ile).

### Kalite Web Standardı
- Web sürümü ikincil ama "kaliteli" — sidebar nav, geniş tablo, multi-column dashboard.
- Landing site (`pulshr.netlify.app`) görsel kalite çıtası — mockup'lardaki yumuşak gölge, generous spacing, modern tipografi.

---

## 4. Tech Stack — Bağlayıcı Kararlar

| Katman | Karar | Kanıt |
|---|---|---|
| Frontend | TanStack Start v1.167+ + React 19 + shadcn/ui + Tailwind v4 | Mimari Bölüm 1.1.1 |
| Mobile | Capacitor v8 (React Native DEĞİL) — iOS + Android | Mimari Bölüm 1.1.1 |
| BaaS | Supabase (Frankfurt EU) — auth, postgres, RLS, pgvector, storage, realtime, edge functions | Mimari Bölüm 1.1.2 |
| Custom Services | Railway (Frankfurt) — 23 focused-service (Sprint-2'den itibaren) | Mimari Bölüm 1.1.3 |
| LLM Gateway | Anthropic Bedrock (Frankfurt) primary + OpenAI fallback (Sprint-2) | Mimari Bölüm 1.1.4 |
| Vektör Arama | pgvector (Supabase native) | Mimari Bölüm 7.4 |
| OCR (Cüzdan) | Mindee/Vision/Textract — Sprint-2 araştırma | Mimari Bölüm 11.2.6 |
| E-İmza | DocuSign / E-Devlet / iyzico — adapter pattern | Mimari Bölüm 1.1.3 |
| Auth | Supabase Auth + persona-bazlı RLS | Mimari Bölüm 5.1 |
| State | TanStack Query | Standart |
| Form | React Hook Form + Zod | Standart |
| i18n | i18next, tr-TR default + en-US opsiyonel | Standart |
| Package Manager | bun (pnpm de kabul) | `bun.lockb` mevcut eski repo'da |
| Node Version | 22.x | LTS |

**Yasak/Riskli:**
- ❌ React Native'e geçiş (gündem dışı — Capacitor sabit)
- ❌ Frontend'den doğrudan LLM API çağrısı (her şey LLM Gateway üzerinden, Sprint-2)
- ❌ PII'yi LLM'e ham göndermek (PII redaction pipeline zorunlu — Mimari 4.2.2)
- ❌ Brüt ücret tüm rollerde açık göstermek (rol-bazlı maskeleme şart — Audit 5.5)
- ❌ localStorage/sessionStorage'da PII (KVKK ihlali riski)
- ❌ Doğrudan `main`'e push (PR + review şart, Sprint-1'de bile)

---

## 5. 20 Modül Haritası

### 12 Ana Modül
1. **KPI Hedefleri** (eski Ölç™) — pozisyon-bazlı KPI + Reporter_Model
2. **Performans** — Hedef + Yetkinlik = Genel formülü
3. **Eğitim Analizi (Okul™)** — 5 aşamalı süreç + Kirkpatrick 4
4. **Kariyer Haritası (Harita™)** — 5 basamaklı ladder + readiness skoru
5. **İş Değerleme (Kale™)** — 7-faktör Hay-benzeri + ücret kademesi K1-K4 *(Kale™ artık hukuki değil, scope değişti)*
6. **Görev Tanımı** — pozisyon görev kartı + org chart
7. **İş Tanımı** — resmi pozisyon dokümanı
8. **İş Analizi** — pozisyon analiz formu
9. **İzin · Tatil™** — 4857 m.53 inline
10. **Masraf · Cüzdan™** — OCR fiş + ERP write
11. **Sözleşme · Belge™** — 4857 m.8 inline + yaşam döngüsü
12. **AI Koç™ (Koç™)** — Çalışan Sırdaş (vault + tool-call rozetleri)

### 8 Tanım & Kurulum Modülü
13. **Şirket Kurulum** (tenant) · 14. **Departmanlar** (identity) · 15. **Pozisyonlar** (is-tanimi) · 16. **Çalışanlar** (identity) · 17. **İzin Tipleri** (tatil) · 18. **Masraf Kategorileri** (cuzdan) · 19. **Performans Parametreleri** (performans) · 20. **ERP Entegrasyon** (erp-config)

### Bağla™ (silently)
Sidebar'da YOK. AI Koç tool'u olarak silently sentiment çıkarımı yapar; k-anonymity ≥5 ile ekip metriklerine akar.

**Detay:** Mimari Bölüm 11.1 + Veri Sözlüğü 16 sheet.

---

## 6. İki-Persona Mimarisi (KRİTİK — Audit C1)

Her sayfa header'ında **mode toggle pill** (çift role'lü kullanıcılar için):

| Persona | UX | İçerik | Veri Yetkisi |
|---|---|---|---|
| **Çalışan (Sırdaş)** | Floating widget + per-module inline panel + bottom-tab nav | Kendi kariyeri, izni, masrafı, hukuki sorusu | Kendi anonim_id + kendi vault |
| **Yönetici (Asistan)** | Dedicated sayfa + sidebar nav | Ekip metrikleri (k-anonymity ≥5), sözleşme taslağı, disiplin | Yönettiği ekip + ERP yetki |

**Vault İzolasyonu (taşa yazılı):** Manager asla bir başka çalışanın vault'una giremez. RLS: `auth.uid() = anonymous_employee_id`. Puls operasyon ekibi dahil **hiç kimse** vault'u okuyamaz.

**Brüt Ücret Maskeleme:**
- `hr_admin` / `payroll_admin` → tam (₺205.000)
- `manager` (kendi ekibi) → "₺•••.000 [Görüntüle]" — onay + audit log
- `employee` (kendisi) → tam
- `employee` (başkası) → tam yasak

---

## 7. 3-Katmanlı Gizlilik Mimarisi (Mimari Bölüm 4)

1. **Gizli Vault** — Supabase ayrı `vault` şeması, AES-256, RLS = `auth.uid() = anonymous_employee_id`
2. **Sinyal Motoru** — Konuşma → PII redaction pipeline → sentiment + intent (LLM Gateway üzerinden)
3. **k-anonymity ≥5** — Ekip seviyesi sinyal sadece 5+ aktif kullanıcı ekipte. Müzakere edilemez.

PII patterns: Türk isimleri sözlüğü, Türk şehirleri, TC kimlik, telefon, e-posta, şirket isimleri (tenant-specific), tarih genelleştirme.

---

## 8. Çalışma Konvansiyonları

### Tool Registry Pattern (Brain + Muscles) — Sprint-2'de inşa edilir
- LLM (Beyin) intent okur, planlar, doğal dilde konuşur.
- Deterministik kod (Kaslar) iş kuralı uygular, veri okur/yazar.
- LLM **direkt** state mutate etmez — sadece `tool` çağırır.
- Tüm tool'lar Zod schema ile validate.
- Destructive tool'lar için **confirmation card** zorunlu.

### Naming Konvansiyonları
- Modül namespace'leri: `kpi`, `performans`, `okul`, `kariyer`, `kale`, `gorev-tanimi`, `is-tanimi`, `is-analizi`, `tatil`, `cuzdan`, `belge`, `koc`, `bagla`, `bordro`, `audit`, `identity`, `tenant`, `erp-config`.
- Tool isimleri: `modul_action` (snake_case) — örn. `cuzdan_create_expense_from_photo`.
- DB tabloları: snake_case, çoğul (`employees`, `kpi_assignments`).
- RLS policy isimleri: `{table}_{role}_{operation}` — örn. `vault_employee_select_own`.
- Component'ler: PascalCase, modül prefix'i (`KocChatPanel`, `CuzdanFormCard`).
- API endpoint'leri (Railway): `/api/v1/{namespace}/{action}` (REST).
- Branch: `feature/{module}/{short-description}` (örn. `feature/foundation/tailwind-tokens`).

### Git Workflow
- Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
- Her PR için: TypeScript build pass + ESLint pass + (Sprint-2'den itibaren) ilgili modülün eval suite pass.
- Doğrudan `main`'e push **yasak** — Sprint-1'de bile branch protection.

### Veri Sözlüğü Disiplini
Excel **tek kaynak**. Yeni alan/tool/modül eklerken:
1. Excel'in ilgili sheet'inde alan listesini güncelle.
2. Sonra kod yaz.
3. PR description'da Excel hücre referansı belirt.

### Türkçe Konuşma / İngilizce Kod
- Kullanıcı ile iletişim: Türkçe.
- Kod, isim, log mesajları, commit mesajları, README: İngilizce.
- UI metni (kullanıcının gördüğü her şey): Türkçe (i18next dictionary).

---

## 9. SPRINT-1: FOUNDATION & SCAFFOLD (İlk 2 Hafta)

**Hedef:** Boş `puls_dev` repo'sundan **deployable, çalışan, mobile-first iskelet** üretmek. Hiçbir gerçek modül feature'ı yok — sadece (a) tüm stack çalışıyor, (b) tasarım sistemi yerleşmiş, (c) auth + persona toggle iskeleti var, (d) ilk Supabase tablosu + RLS örneği var, (e) CI/CD yeşil, (f) mobile + web ikisi de render ediyor.

### Sprint-1 Deliverable Listesi

#### 9.1 Repo Scaffold (Gün 1-2)
- TanStack Start v1.167+ project init (`bun create tanstack-start`).
- TypeScript strict mode (`tsconfig.json`).
- Vite + tsconfig-paths.
- Folder structure (puls-core'dan örnek alarak, kopyalamadan):
  ```
  src/
    routes/
      __root.tsx
      _app.tsx
      _app.dashboard.tsx       (placeholder)
      login.tsx
    components/
      ui/                       (shadcn/ui)
      puls/                     (domain components — Sprint-2'den)
      layout/                   (Header, Sidebar, BottomTab, FloatingWidget)
    lib/
      auth.ts
      supabase.ts
      utils.ts
    hooks/
    i18n/
      locales/
        tr-TR.json
        en-US.json
    styles.css
  supabase/
    migrations/
    seed.sql
  capacitor.config.ts
  ```
- `README.md` (geliştirme nasıl başlatılır + env vars + Capacitor build + Supabase reset).
- `.env.example` (Supabase URL/anon key placeholder, Anthropic API key placeholder).

#### 9.2 Tasarım Sistemi (Gün 2-3)
- Tailwind v4 setup + `tailwind.config.ts`.
- **Renk paleti (landing site referans):**
  - `primary-50` ... `primary-950` — neon yeşil tonları (~#00C853 ana)
  - `surface-light` / `surface-dark` — koyu mod default
  - `ink` / `muted` / `subtle` — text tonları
  - `success` / `warning` / `danger` / `info` — status tokens (DS-1 audit çözümü)
- **Tipografi:**
  - Sans-serif: Inter (system fallback)
  - Mono: JetBrains Mono (sadece kod identifier'larda — KPI sayılarında tabular-nums sans-serif)
  - Type scale: 12 / 14 / 16 / 18 / 24 / 32 / 48 / 64
- **Spacing:** 8-pt grid (Tailwind default uyumlu).
- **Border radius:** sm/md/lg/xl/2xl tokens.
- **Shadow:** elevation 1-5 (mockup mobil frame ile uyumlu yumuşak gölgeler).
- Dark mode default (landing site uyumlu); light mode opt-in toggle hazır.
- `globals.css` token'ları CSS variable olarak yaz.

#### 9.3 shadcn/ui Setup + İlk Component'ler (Gün 3-4)
- `bunx shadcn-ui@latest init` — Tailwind v4 uyumlu.
- İlk 10 component:
  - `button`, `input`, `label`, `card`, `dialog`, `drawer` (mobile sheet için), `sheet`, `dropdown-menu`, `avatar`, `toast` (sonner)
- Her component'in Storybook story'si veya basit demo route'u (`/__dev/components`).

#### 9.4 Capacitor Init (Gün 4)
- `capacitor.config.ts` — `appId: io.puls.app`, `appName: PULS`, `webDir: dist`.
- `bun cap add ios && bun cap add android` (build edilmesin, sadece config).
- Önemli plugin'ler `package.json`'a ekle (henüz kullanılmayacak): `@capacitor/camera`, `@capacitor/push-notifications`, `@capacitor/haptics`, `@capacitor/status-bar`, `@capacitor/keyboard`, `@capacitor/preferences`, `@capacitor-community/speech-recognition`.
- README'ye iOS + Android build talimatları.

#### 9.5 Supabase Init + İlk Migration (Gün 4-5)
- `bunx supabase init` (local stack).
- İlk migration: `supabase/migrations/0001_foundation.sql`:
  - `tenants` tablosu (id, legal_name, trade_name, tax_no, kvkk_active, verbis_registered, paket, created_at)
  - `employees` tablosu (anonymous_id UUID PK, tenant_id FK, email, full_name CACHE, job_title CACHE, department_id FK NULL, position_id FK NULL, persona_role ENUM, hire_date, created_at)
  - `departments` tablosu (id, tenant_id FK, name, code, parent_id FK NULL, manager_employee_id FK NULL, is_active, created_at)
  - `positions` tablosu (id, tenant_id FK, name, code, department_id FK, level, parent_position_id FK NULL, salary_min, salary_max, employment_type, norm_headcount, created_at)
  - `vault.conversation_messages` (ayrı şema, AES-256 placeholder — şimdilik plain, MVP-2'de pgsodium)
  - `audit.audit_logs` (id, tenant_id, actor_id, action, target_object JSONB, occurred_at, request_metadata JSONB)
- RLS policy'leri her tablo için (tenant izolasyonu + persona-bazlı yetki).
- `supabase/seed.sql` — 1 demo tenant + 5 demo çalışan + 3 demo departman + 5 demo pozisyon.
- `bunx supabase db reset` ile temiz çalıştığını doğrula.

#### 9.6 Auth + Persona Toggle (Gün 5-7)
- `src/lib/supabase.ts` — Supabase client (Frankfurt region).
- `src/lib/auth.tsx` — `AuthProvider` context (Supabase Auth + persona_role).
- `_app.tsx` route guard: oturum yoksa `/login`'e.
- `/login` sayfası — minimal form (e-posta + şifre + Sign in).
- `PersonaTogglePill` component (Mimari 5.6 spec):
  - Header'da, çift role'lü kullanıcı için görünür.
  - Aktif persona koyu yeşil (primary), pasif açık gri.
  - Geçişte route state korunur, persona-uygun görünüme atar.
  - Audit log: her geçiş `audit.audit_logs`'a yazılır.
- `maskSalary(userRole, targetEmployeeRole, amount)` utility (`src/lib/privacy.ts`).
- Cross-tenant erişim engelleme testi (Playwright veya basit pytest).

#### 9.7 Root Layout — Mobile-First + Web Genişletme (Gün 7-9)
- `src/components/layout/AppHeader.tsx` — Logo + PersonaTogglePill + UserMenu (avatar).
- `src/components/layout/BottomTabNav.tsx` — sadece mobile (`md:hidden`); 4-5 ana tab (Dashboard, KPI, AI Koç, Tatil, Profil — Çalışan persona; Dashboard, Ekip, Onaylar, AI Koç — Yönetici persona).
- `src/components/layout/Sidebar.tsx` — sadece desktop (`hidden md:flex`); 20 modül grupları (İK Yönetimi / Çalışan Süreçleri / Yapay Zeka / Tanım & Kurulum).
- `src/components/layout/FloatingAIButton.tsx` — sağ-altta sticky (her sayfada görünür); henüz işlevsiz (Sprint-2'de bağlanacak).
- `_app.tsx` layout: header + (bottom tab VEYA sidebar) + content + floating AI button.
- Responsive smoke test: 375px / 768px / 1280px render edilmeli (Playwright veya Chrome DevTools).

#### 9.8 i18n Setup (Gün 9-10)
- i18next + react-i18next.
- `tr-TR.json` (default) + `en-US.json` (placeholder).
- `useTranslation` hook ile login + header + nav metinleri.
- `scripts/check-i18n.mjs` — eksik key tespiti (puls-core'daki ile aynı pattern).

#### 9.9 CI/CD (Gün 10-12)
- GitHub Actions: `.github/workflows/ci.yml`:
  - Lint (ESLint) + Format check (Prettier).
  - TypeScript build (`bun run build`).
  - Playwright smoke test (3 breakpoint render + login flow).
  - i18n check (`bun run check-i18n`).
- Husky pre-commit: `bun run lint && bun run typecheck`.
- Conventional Commits enforcement (commitlint).
- Branch protection: `main` PR şart + reviewer şart + CI yeşil şart.
- README'de "How to deploy" (Netlify veya Vercel staging).

#### 9.10 README + CHANGELOG + Veri Sözlüğü Sync (Gün 12-14)
- Tam README: proje tanımı + stack + dev kurulum + Supabase reset + Capacitor build + deploy + linkler.
- CHANGELOG.md (Conventional Commits + Sprint-1 entries).
- `Puls_Veri_Sozlugu_v1.0.xlsx` "Ortak Alanlar" sheet'inde implement edilen field'ları ✅ olarak işaretle (manuel).

### Sprint-1 NOT-IN-SCOPE
- ❌ LLM Gateway servisi (Railway) — **Sprint-2**
- ❌ Tool Registry implementasyonu — **Sprint-2**
- ❌ Eval pipeline — **Sprint-2**
- ❌ Cost attribution dashboard — **Sprint-2**
- ❌ AI Koç chat UI (component'i ileride) — **Sprint-2 sonu**
- ❌ Cüzdan™ OCR, Tatil™ form, Belge™ timeline, KPI tablosu — **Sprint-3+**
- ❌ ERP connector (Canias/Logo) — **Sprint-4**
- ❌ K-anonymity sinyal motoru — **Sprint-5**
- ❌ Pilot müşteri onboarding — **Sprint-6 sonu**

---

## 10. Definition of Done (Sprint-1)

- [ ] `puls_dev` repo boş başladı, sonunda çalışan iskelet var.
- [ ] `bun install && bun run dev` ile uygulama localhost:3000'de açılıyor.
- [ ] `bunx supabase start && bunx supabase db reset` ile local stack çalışıyor; tablolar + RLS + seed data yerinde.
- [ ] Login sayfası → seeded user ile giriş → Dashboard placeholder görünüyor.
- [ ] PersonaTogglePill çift role'lü user için render ediliyor; tıklayınca header'da görsel değişiyor; audit log'a yazıyor.
- [ ] 375px / 768px / 1280px responsive test: BottomTab mobil görünür, Sidebar desktop görünür, FloatingAIButton her ikisinde sağ-altta.
- [ ] Renk paleti landing site (`pulshr.netlify.app`) ile karşılaştırıldığında uyumlu (dark mode default + neon yeşil accent).
- [ ] Capacitor `bun cap sync ios && bun cap sync android` hatasız (build edilmedi, sadece config doğrulama).
- [ ] GitHub Actions yeşil (lint + typecheck + Playwright smoke).
- [ ] Husky pre-commit + Conventional Commits aktif.
- [ ] Cross-tenant erişim engelleme testi geçiyor (tenant A'nın user'ı tenant B'nin employee'lerini göremiyor).
- [ ] README + CHANGELOG + .env.example tamam.
- [ ] Veri Sözlüğü Excel'inde implement edilen field'lar ✅ işaretli.

---

## 11. Çalışma Modu Kuralları (Cursor Agent İçin)

1. **Plan Önce, Sonra Kod:** Her büyük task öncesi 5-10 satır plan yaz, kullanıcıya göster, onay al.
2. **Küçük Commit, Sık PR:** Bir feature 1-3 dosyayı geçerse ara PR önerir. Anlamlı commit mesajları.
3. **Mimari Doküman Bağlayıcı:** Kararlar buradan akar. Çelişki gördüğünde **kod uydurma değil, doküman güncelle önerisi** sun.
4. **Veri Sözlüğü Senkron:** Yeni field eklediğinde önce Excel'i güncelle, sonra kod yaz.
5. **Audit Bulgu Takip:** UX/UI Audit Bölüm 6'daki Critical/High aksiyonlar her ekran yazılırken kontrol listesi olarak.
6. **Türkçe Konuş, İngilizce Kodla:** Kullanıcı ile Türkçe; kod/log/commit İngilizce.
7. **Test Yazma Kuralı:** Her tool için min 5 golden case (Sprint-2'den); her RLS policy için min 1 cross-tenant engelleme testi (Sprint-1'den).
8. **Lovable ile Eş Çalışma:** Lovable component prompt template'leri (Mimari Ek B) hazır; UI bileşeni gerekirse önce Lovable'a ürettir, sonra git pull ile entegre et. **Sprint-1'de Lovable yok** — agent kendi yazar.
9. **Asla:** API key'leri commit etme, brüt ücret loglarda görünmesin, çalışan adı LLM'e ham gitmesin (Sprint-2'den).
10. **Stop ve Sor:** Mert Teknik A.Ş. verisi gerekirse → ürün sahibine sor; İş Değerleme metodoloji (Hay vs Mercer) → ürün sahibine sor; ERP first-tier (Canias vs Logo) → ürün sahibine sor; renk/tipografi token'ı için landing site'tan emin değilsen → ürün sahibine sor.

---

## 12. Referans Doküman Matrisi

| Sorun | Hangi Doküman | Hangi Bölüm |
|---|---|---|
| Bir modülün ne olduğu | Veri Sözlüğü Excel | İlgili sheet |
| Bir modülün UI'ı nasıl olmalı | Audit v1.0 + landing site | Audit Bölüm 4 + Mimari Bölüm 6 |
| Tasarım token'ı (renk, type, spacing) | Landing site + Mimari Bölüm 6.4 | Inspector ile çıkar |
| Mikroservis sorumluluğu | Excel "Mikroservis Haritası" + Mimari 1.1.3 | — |
| KPI/alan veri tipi | Excel ilgili sheet | "Veri Tipi" sütunu |
| KVKK / 4857 inline metin | Mimari Bölüm 10 + RAG corpus (Sprint-3+) | — |
| Persona yetkisi | Mimari Bölüm 5 + RLS policy | — |
| Pazar konumlanma argümanı | Mimari Bölüm 14 + Audit Bölüm 10 | — |
| Pilot müşteri (Mert Teknik) profili | PDF Pitch sayfa 11 | — |
| Stratejik konumlanma cümlesi | Mimari Bölüm 14 callout | — |
| Mobile-first standartları | Bu doküman Bölüm 3 | — |

---

## 13. Pilot Müşteri Bağlamı (Mert Teknik A.Ş.)

- **Çalışan sayısı:** 104
- **Sektör:** İmalat + Satış
- **ERP:** Henüz netleşmedi (Canias mı, Logo mu — sor)
- **Hedef:** Tüm 20 modül kullanımda olacak.
- **Onboarding Hedefi:** MVP-1 Ay 6 sonu (Sprint-12 civarı).

---

## 14. ARR / Fiyatlama (PDF Pitch)

| Paket | Çalışan | Fiyat | Hedef |
|---|---|---|---|
| Starter | <50 | $5/ay/kullanıcı | Kurucu/operasyon |
| Growth | 50-100 | $4/ay/kullanıcı | İK + GM |
| Growth+ | 100-250 | $3/ay/kullanıcı | İK + CFO |
| Enterprise | 500+ | $2/ay/kullanıcı | Kurumsal |
| **AI Coach (ek paket)** | Her segment | **$20/ay/kullanıcı** | BetterUp'tan %93 ucuz |

**ARR Ramp:** Y1 $142K → Y3 $685K → Y5 $7.7M (Y5'in %77'si core, %23 AI).

Bu fiyatlama **mühendislik kısıtıdır** — Mimari Bölüm 8'de model tiering + prompt caching marjı korumak için (Sprint-2 LLM Gateway tasarımının baseline'ı).

---

## 15. Ekip Bağlamı

- **Alkım Erdönmez (CEO)** — İTÜ Makina Müh., İK süreçleri uzmanı. **Ürün/UX kararları → Alkım.**
- **Onur Önder (CTO)** — İTÜ Bilgisayar Müh. Yüksek Lisans. **Bu Cursor session'ı Onur açtı. Teknik kararlar → Onur.**
- **Özge Büyükşahin (CSO)** — Sorwe satış deneyimi, KOBİ pazar ağı. **Satış/müşteri kararları → Özge.**

---

## 16. Risk Çerçevesi (Sprint-1 Relevant)

| Risk | Mitigation |
|---|---|
| Mobile + desktop dual stack karmaşası | Mobile-first disiplinle başla, desktop genişletme — tek codebase |
| Capacitor Tailwind v4 ile sorun | Sprint-1'de sadece config + sync test (build sonraki sprint'te) |
| Supabase Frankfurt EU latency | İlk pilot ile ölç; gerekirse İstanbul edge cache |
| Persona toggle kullanıcı kafa karışıklığı | Sprint-1 sadece iskelet; UX test Sprint-2'de pilot ile |
| Lovable component'lerinden referans kopyalama riski | YASAK — sadece pattern öğren, kendin yaz |

---

## 17. İlk Mesajın (Cursor Composer 2.5'a)

```
Selam Cursor Agent. Ben Onur Önder, Puls AI Coach platformunun CTO'suyum.

Boş bir puls_dev repo'sundan sıfırdan başlıyoruz. Yukarıdaki "0. Onay &
Bağlam Doğrulama" adımını uygula:

1. Üç v1.0 dokümanı oku (Puls/ altında)
2. EkranGörüntüleri/ altındaki 19 PNG'yi tara
3. Landing site pulshr.netlify.app'i incele (renk paleti + tasarım dili)
4. Eski referans repo /Users/onuronder/puls-core/'a göz at (sadece pattern
   öğrenmek için, kopyalama)
5. Bana 200 kelimelik özet ver: "Bağlamı anladım — şu var, şu yok, ilk işin
   şu olacak, şu sorum var."

Onaylarsam Sprint-1 Bölüm 9 ile başlayacağız (Foundation & Scaffold).
Mobile-first ilkesi (Bölüm 3) bağlayıcı.

Türkçe konuş benimle. Soru sor — varsayım yapma.
```

---

## 18. Bu Doküman Hakkında

- **Versiyon:** v2 (Mayıs 2026) — Boş repo + mobile-first revizyonu
- **v1 farkları:** Sprint-1 odağı LLM Gateway'den Foundation/Scaffold'a kaydı; mobile-first ilkesi Bölüm 3 olarak eklendi; puls-core "sadece referans" konumuna düştü; landing site tasarım sistemi kaynağı oldu.
- **Kaynak:** 3 v1.0 referans doküman + PDF İTÜ Çekirdek Pitch + https://pulshr.netlify.app + eski puls-core (referans) + 19 ekran görüntüsü
- **Hazırlayan:** Claude (Onur Önder ile birlikte iteratif olarak)
- **Sonraki Revizyon:** Sprint-1 sonunda bu doküman v2.1 olur (Sprint çıktıları + öğrenilenler + Sprint-2 detay).

---

**ÖNEMLİ:** Bu prompt Cursor'a verilirken **tamamı** kopyalanmalı. Cursor Agent büyük context'i bu dokümanı baştan sona işleyecek; kırpılırsa bağlam kaybedilir. ~7000 kelimedir — Cursor için uzun ama uygundur.
