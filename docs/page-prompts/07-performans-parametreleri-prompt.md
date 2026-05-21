# Cursor Prompt — /performans-parametreleri (Performans Parametreleri)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/performans-parametreleri` ekranını Lovable prototipindeki `performans-parametreleri.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

Ekran grubu: **Tanım & Kurulum**

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/performans-parametreleri.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/performans-parametreleri`
- Hedef dosya: `src/routes/_app/performans-parametreleri.tsx`
- Navigation: Tanım & Kurulum altında gerçek route. `/menu` içinde tıklanabilir.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/performans-parametreleri.tsx`
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
import { createFileRoute } from "@tanstack/react-router";
import { SlidersHorizontal, Target, Layers, AlertCircle } from "lucide-react";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { competencyTemplates, kpiCategories, scoreBands } from "@/lib/demo-data";

export const Route = createFileRoute("/performans-parametreleri")({
  head: () => ({
    meta: [
      { title: "Performans Parametreleri — PULS" },
      { name: "description", content: "Yetkinlik şablonları, KPI ağırlıkları ve skor bandları." },
    ],
  }),
  component: PerformansParametreleriPage,
});

function PerformansParametreleriPage() {
  return (
    <PageContainer>
      <PageHeader
        eyebrow="Tanım & Kurulum"
        title="Performans Parametreleri"
        description="Yetkinlik şablonları, KPI ağırlıkları ve skor bandlarını yönet."
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Yetkinlik şablonu" value="3" icon={Layers} />
        <MetricCard label="KPI kategorisi" value="4" icon={Target} tone="info" />
        <MetricCard label="Skor bandı" value="5" icon={SlidersHorizontal} />
        <MetricCard label="Aktif dönem" value="Yok" icon={AlertCircle} tone="warning" />
      </div>

      <section className="mb-6">
        <SectionHeader title="Yetkinlik şablonları" />
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {competencyTemplates.map((t) => (
            <li key={t.id} className="flex items-center justify-between gap-3 p-4">
              <div className="min-w-0">
                <div className="text-sm font-medium text-foreground">{t.name}</div>
                <div className="text-xs text-muted-foreground">
                  {t.areas} yetkinlik alanı · son güncelleme {t.updated}
                </div>
              </div>
              <button
                type="button"
                className="rounded-md border border-border bg-card px-3 py-1.5 text-xs font-medium hover:bg-accent"
              >
                Düzenle
              </button>
            </li>
          ))}
        </ul>
      </section>

      <section className="mb-6">
        <SectionHeader title="KPI ağırlıkları" description="Toplam 100%" />
        <div className="mt-3 space-y-2 rounded-lg border border-border bg-card p-4">
          {kpiCategories.map((k) => (
            <div key={k.id} className="grid grid-cols-[120px_1fr_44px] items-center gap-3 sm:grid-cols-[180px_1fr_56px]">
              <div className="text-sm text-foreground">{k.name}</div>
              <div className="h-1.5 overflow-hidden rounded-full bg-neutral-soft">
                <div className="h-full rounded-full bg-primary" style={{ width: `${k.weight}%` }} />
              </div>
              <div className="text-right text-sm font-medium tabular">%{k.weight}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <SectionHeader title="Skor bandları" />
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {scoreBands.map((b) => (
            <li key={b.id} className="flex items-center justify-between gap-3 p-4">
              <div className="flex items-center gap-3">
                <StatusPill tone={b.tone}>{b.label}</StatusPill>
                <span className="text-xs text-muted-foreground tabular">
                  {b.min} – {b.max}
                </span>
              </div>
              <div className="text-xs text-muted-foreground">Prim katsayısı —</div>
            </li>
          ))}
        </ul>
      </section>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const competencyTemplates = [
  { id: "t1", name: "Saha Mühendisi", areas: 6, updated: "12 Nis 2026" },
  { id: "t2", name: "Ofis & Operasyon", areas: 5, updated: "08 Nis 2026" },
  { id: "t3", name: "Yönetici", areas: 7, updated: "01 Mar 2026" },
];

export const kpiCategories = [
  { id: "k1", name: "Operasyonel", weight: 35 },
  { id: "k2", name: "Müşteri", weight: 25 },
  { id: "k3", name: "Finansal", weight: 20 },
  { id: "k4", name: "Gelişim", weight: 20 },
];

export const scoreBands = [
  { id: "sb1", label: "Çok iyi", min: 90, max: 100, tone: "success" as const },
  { id: "sb2", label: "İyi", min: 75, max: 89, tone: "info" as const },
  { id: "sb3", label: "Beklenen", min: 60, max: 74, tone: "neutral" as const },
  { id: "sb4", label: "Gelişim", min: 45, max: 59, tone: "warning" as const },
  { id: "sb5", label: "Risk", min: 0, max: 44, tone: "danger" as const },
];
```

## UI/UX Kabul Kriterleri

- Metrikler: Yetkinlik şablonu, KPI kategorisi, Skor bandı, Aktif dönem.
- Yetkinlik şablonları listesi korunmalı.
- KPI ağırlıkları toplam 100% olarak barlarla gösterilmeli.
- Skor bandları StatusPill ile gösterilmeli.

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

Tanım & Kurulum altında gerçek route. `/menu` içinde tıklanabilir.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|performans-parametreleri.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/performans-parametreleri`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
