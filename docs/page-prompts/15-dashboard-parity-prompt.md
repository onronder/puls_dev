# Cursor Prompt — /dashboard (Dashboard Parity)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/dashboard` ekranını Lovable prototipindeki `index.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

Ekran grubu: **Genel**

## Repo ve Kaynaklar

Ana repo:

```text
/Users/onuronder/Documents/puls_dev
```

Lovable referans repo:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot
```

Lovable route kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/index.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/dashboard`
- Hedef dosya: `src/routes/_app/dashboard.tsx`
- Navigation: Mevcut `/dashboard` korunur; Lovable root `/` referans alınır.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/dashboard.tsx`
- `src/lib/navigation.ts`
- `src/lib/demo/puls-demo-data.ts`
- `src/i18n/locales/tr-TR.json`
- `src/i18n/locales/en-US.json`
- `src/routeTree.gen.ts` route generation sonucu

Şunlara dokunma:

- Auth/login.
- `src/routes/_app.tsx` auth guard.
- Persona çözümleme.
- Supabase migration.
- Railway/API servisleri.
- Bu prompt’un hedefi olmayan route’lar.
- Capacitor dosyaları.

## Kullanılacak Ana Componentler

Öncelik mevcut Faz 1 componentleri:

```ts
import { DataList } from '#/components/puls/DataList'
import { EmptyState } from '#/components/puls/EmptyState'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { Segmented } from '#/components/puls/Segmented'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
```

Yeni UI primitive ekleme. Önce mevcut componentlerle çöz.

## Lovable Route Kodu

Aşağıdaki kod birebir referanstır. Ana projeye kör kopyalama yapma; `@/...` importlarını `#/...` yap, mevcut component API’lerine ve i18n yapısına adapte et.

```tsx
import { createFileRoute, Link } from "@tanstack/react-router";
import {
  Users,
  Building2,
  Briefcase,
  Layers,
  Plug,
  Gauge,
  ArrowRight,
  CalendarCheck,
  Receipt,
  Target,
  Sparkles,
} from "lucide-react";
import { PageContainer } from "@/components/puls/AppShell";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { tenant, recentActivity, erpStatus } from "@/lib/demo-data";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Dashboard — PULS" },
      { name: "description", content: "Mert Teknik A.Ş. için İK operasyon panosu." },
    ],
  }),
  component: Dashboard,
});

interface QueueItem {
  id: string;
  title: string;
  meta: string;
  to: string;
  search?: Record<string, string>;
  tone: "warning" | "info";
  icon: typeof Target;
}

const queue: QueueItem[] = [
  {
    id: "1",
    title: "Performans dönemi açılacak",
    meta: "2026 Q2 değerlendirmesi",
    to: "/performans",
    search: { configure: "1" },
    tone: "info",
    icon: Target,
  },
  {
    id: "2",
    title: "Canias alan eşleştirmesi bekliyor",
    meta: "6 / 12 alan tamamlandı",
    to: "/erp",
    tone: "warning",
    icon: Plug,
  },
  {
    id: "3",
    title: "2 izin onayı bekliyor",
    meta: "Ayşe K., Murat T.",
    to: "/izin",
    search: { tab: "approvals" },
    tone: "warning",
    icon: CalendarCheck,
  },
  {
    id: "4",
    title: "2 masraf onayı bekliyor",
    meta: "Toplam ₺1.740",
    to: "/masraf",
    search: { tab: "approvals" },
    tone: "warning",
    icon: Receipt,
  },
];

function Dashboard() {
  return (
    <PageContainer>
      {/* Welcome */}
      <div className="flex flex-col gap-1">
        <div className="flex items-center gap-2 text-[12px] font-medium text-muted-foreground">
          <Building2 className="h-3.5 w-3.5" />
          <span>{tenant.name}</span>
          <span aria-hidden>·</span>
          <span>21 May 2026</span>
        </div>
        <h1 className="text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
          Hoş geldin, Demo
        </h1>
        <p className="text-sm text-muted-foreground">
          İK operasyonlarının bugünkü özetini buradan takip et.
        </p>
      </div>

      {/* Metrics */}
      <section className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6" aria-label="Tenant metrikleri">
        <MetricCard label="Aktif Çalışan" value={tenant.employees} hint="3 departman" icon={Users} />
        <MetricCard label="Departman" value={tenant.departments} hint="Tanımlı" icon={Building2} />
        <MetricCard label="Pozisyon" value={tenant.positions} hint="Tanımlı" icon={Briefcase} />
        <MetricCard
          label="Yetkinlik Şablonu"
          value={tenant.competencyTemplates}
          hint="Hazır"
          icon={Layers}
        />
        <MetricCard
          label="ERP Durumu"
          value={<span className="text-[20px]">Canias</span>}
          hint={<StatusPill tone="warning">Beklemede</StatusPill>}
          icon={Plug}
          tone="warning"
        />
        <MetricCard
          label="Veri Hazırlığı"
          value={
            <span>
              {tenant.dataReadiness}
              <span className="text-base text-muted-foreground">%</span>
            </span>
          }
          hint={
            <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-muted">
              <div
                className="h-full rounded-full bg-primary"
                style={{ width: `${tenant.dataReadiness}%` }}
              />
            </div>
          }
          icon={Gauge}
        />
      </section>

      {/* Work queue + Activity */}
      <section className="mt-8 grid gap-5 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <SectionHeader
            title="İş kuyruğu"
            description="Bugün dikkat etmen gereken görevler."
            action={
              <span className="rounded-full bg-warning-soft px-2 py-0.5 text-xs font-medium text-warning">
                {queue.length} öğe
              </span>
            }
          />
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {queue.map((item) => {
              const Icon = item.icon;
              return (
                <li key={item.id}>
                  <Link
                    to={item.to}
                    search={item.search as never}
                    className="flex w-full items-center gap-3 p-4 text-left transition-colors hover:bg-accent/40"
                  >
                    <span
                      className={
                        item.tone === "warning"
                          ? "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-warning-soft text-warning"
                          : "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-info-soft text-info"
                      }
                    >
                      <Icon className="h-[18px] w-[18px]" aria-hidden />
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[14px] font-medium text-foreground">
                        {item.title}
                      </div>
                      <div className="truncate text-[12px] text-muted-foreground">{item.meta}</div>
                    </div>
                    <ArrowRight className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
                  </Link>
                </li>
              );
            })}
          </ul>

          {/* ERP card */}
          <div className="mt-5 rounded-lg border border-border bg-card p-5">
            <div className="flex items-start gap-3">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-warning-soft text-warning">
                <Plug className="h-[18px] w-[18px]" />
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="text-[15px] font-semibold text-foreground">ERP entegrasyon hazırlığı</h2>
                  <StatusPill tone="warning">{erpStatus.statusLabel}</StatusPill>
                </div>
                <p className="mt-1 text-[13px] text-muted-foreground">
                  Canias bağlantısı, müşteri tarafında API erişimi açıldığında devreye alınacak.
                </p>
                <dl className="mt-4 grid grid-cols-3 gap-3 sm:gap-5">
                  <Stat label="Alan eşleştirme" value={`${erpStatus.mappedFields} / ${erpStatus.totalFields}`} />
                  <Stat label="Veri hazırlığı" value={`%${erpStatus.readiness}`} />
                  <Stat label="Son deneme" value={erpStatus.lastAttempt} />
                </dl>
                <div className="mt-4 flex flex-wrap items-center gap-2">
                  <Link
                    to="/erp"
                    className="inline-flex h-10 items-center gap-1.5 rounded-md bg-primary px-3.5 text-[13px] font-semibold text-primary-foreground hover:bg-primary/90"
                  >
                    Alan eşleştirmeyi aç <ArrowRight className="h-3.5 w-3.5" />
                  </Link>
                  <Link
                    to="/erp"
                    className="inline-flex h-10 items-center gap-1.5 rounded-md border border-border bg-card px-3.5 text-[13px] font-medium text-foreground hover:bg-accent"
                  >
                    Sync loglarını gör
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div>
          <SectionHeader title="Son aktiviteler" description="Tenant geneli." />
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {recentActivity.map((a) => (
              <li key={a.id} className="flex items-start gap-3 p-3.5">
                <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-secondary text-[12px] font-semibold text-secondary-foreground">
                  {a.who.charAt(0)}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="text-[13.5px] text-foreground">
                    <span className="font-medium">{a.who}</span>{" "}
                    <span className="text-muted-foreground">{a.what}</span>
                  </div>
                  <div className="mt-0.5 text-[12px] text-muted-foreground">{a.when}</div>
                </div>
              </li>
            ))}
          </ul>

          {/* AI teaser */}
          <div className="mt-5 flex items-start gap-3 rounded-lg border border-ai/20 bg-ai-soft p-4">
            <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-ai/15 text-ai">
              <Sparkles className="h-[18px] w-[18px]" aria-hidden />
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-1.5">
                <span className="text-[13.5px] font-semibold text-ai">AI Coach</span>
                <span className="rounded-full bg-ai/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase text-ai">
                  Yakında
                </span>
              </div>
              <p className="mt-0.5 text-[12.5px] text-ai/90">
                Performans, izin ve politika sorularında yol gösterecek.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Quick actions */}
      <section className="mt-8" aria-label="Hızlı aksiyonlar">
        <SectionHeader title="Hızlı aksiyonlar" />
        <div className="mt-3 grid gap-3 sm:grid-cols-3">
          <QuickAction to="/izin" icon={CalendarCheck} title="İzin talebi oluştur" hint="Kalan: 14 gün" tone="primary" />
          <QuickAction to="/masraf" icon={Receipt} title="Yeni masraf bildir" hint="Aylık limit: ₺15.000" tone="info" />
          <QuickAction to="/performans" icon={Target} title="Performans dönemi" hint="2026 Q2 hazırla" tone="neutral" />
        </div>
      </section>
    </PageContainer>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-[11px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
        {label}
      </dt>
      <dd className="mt-1 text-[15px] font-semibold tabular text-foreground">{value}</dd>
    </div>
  );
}

function QuickAction({
  to,
  icon: Icon,
  title,
  hint,
  tone,
}: {
  to: string;
  icon: typeof Target;
  title: string;
  hint: string;
  tone: "primary" | "info" | "neutral";
}) {
  const toneCls =
    tone === "primary"
      ? "bg-primary/10 text-primary"
      : tone === "info"
        ? "bg-info-soft text-info"
        : "bg-secondary text-secondary-foreground";
  return (
    <Link
      to={to}
      className="flex items-center justify-between rounded-lg border border-border bg-card p-4 transition-colors hover:bg-accent/40"
    >
      <div className="flex items-center gap-3">
        <span className={`flex h-10 w-10 items-center justify-center rounded-lg ${toneCls}`}>
          <Icon className="h-[18px] w-[18px]" aria-hidden />
        </span>
        <div>
          <div className="text-[14px] font-medium text-foreground">{title}</div>
          <div className="text-[12px] text-muted-foreground">{hint}</div>
        </div>
      </div>
      <ArrowRight className="h-4 w-4 text-muted-foreground" aria-hidden />
    </Link>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const tenant = {
  name: "Mert Teknik A.Ş.",
  erp: { name: "Canias", status: "beklemede" as const },
  employees: 4,
  departments: 3,
  positions: 3,
  competencyTemplates: 3,
  dataReadiness: 72,
};

export const recentActivity = [
  { id: "a1", who: "Ayşe Kaya", what: "izin talebi oluşturdu", when: "2 saat önce" },
  { id: "a2", who: "Murat Tan", what: "masraf bildirdi · ₺840", when: "5 saat önce" },
  { id: "a3", who: "Sistem", what: "Canias bağlantısı yeniden denendi", when: "Dün" },
  { id: "a4", who: "Elif Demir", what: "profil bilgilerini güncelledi", when: "Dün" },
];

export const erpStatus = {
  system: "Canias" as const,
  status: "beklemede" as const,
  statusLabel: "API erişimi bekleniyor",
  mappedFields: 6,
  totalFields: 12,
  lastAttempt: "Dün, 18:42",
  readiness: 72,
};
```

## UI/UX Kabul Kriterleri

- Hoş geldin alanı, tenant/date bağlamı ve kişi adı korunmalı.
- Tenant metrikleri Lovable kapsamına yaklaşmalı: çalışan, departman, pozisyon, yetkinlik, ERP, veri hazırlığı.
- İş kuyruğu, ERP hazırlık kartı, son aktiviteler, AI teaser ve hızlı aksiyonlar korunmalı.
- Ana Supabase dashboard query bozulmamalı.

Genel UI/UX kuralları:

- H1 ve açıklama net olmalı.
- Her ana section `SectionHeader` ile ayrılmalı.
- Touch target minimum 44px.
- Input font-size 16px.
- Metadata text 11px altına düşmemeli.
- 390px ve 360px mobile genişlikte horizontal overflow olmamalı.
- CTA sadece toast ile geçiştirilmemeli; çalışmıyorsa disabled/teaser state kullanılmalı.
- AI Koç aktif chat gibi davranmamalı.

## Data Stratejisi

- Supabase query hali hazırda varsa onu koru.
- DB tablosu yoksa `src/lib/demo/puls-demo-data.ts` içine izole demo adapter ekle.
- Route component içine büyük statik array gömme.
- Demo adapter, ileride Supabase query ile değiştirilebilir olmalı.

## Navigation Kabul Kriteri

Mevcut `/dashboard` korunur; Lovable root `/` referans alınır.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|dashboard.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
```

Beklenen:

- Hedef route dosyasında `Hello "/_app..."` stub yok.
- Hedef route navigation’da tamamlandıysa `soon: true` yok.
- Bu prompt kapsamı dışındaki route’larda beklenmeyen değişiklik yok.

## Test

```bash
pnpm typecheck
pnpm exec eslint src
pnpm build
pnpm check-i18n
```

## PR Açıklaması

PR açıklamasında şunları yaz:

- Eklenen/güncellenen route: `/dashboard`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
