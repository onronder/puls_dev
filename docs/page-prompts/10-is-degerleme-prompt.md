# Cursor Prompt — /is-degerleme (İş Değerleme)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/is-degerleme` ekranını Lovable prototipindeki `is-degerleme.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

Ekran grubu: **İK Yönetimi**

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/is-degerleme.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/is-degerleme`
- Hedef dosya: `src/routes/_app/is-degerleme.tsx`
- Navigation: İK Yönetimi altında gerçek route. `soon` kaldırılmalı.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/is-degerleme.tsx`
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
import { Scale, Award, BarChart3, AlertCircle } from "lucide-react";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { jobEvaluations, evaluationFactors } from "@/lib/demo-data";

export const Route = createFileRoute("/is-degerleme")({
  head: () => ({
    meta: [
      { title: "İş Değerleme — PULS" },
      { name: "description", content: "Pozisyonların seviye, puan ve sorumluluk bandı." },
    ],
  }),
  component: IsDegerlemePage,
});

function IsDegerlemePage() {
  return (
    <PageContainer>
      <PageHeader
        eyebrow="İK Yönetimi"
        title="İş Değerleme"
        description="Pozisyonların seviye, puan ve sorumluluk bandını takip et."
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Değerlendirilen pozisyon" value="3" icon={Scale} />
        <MetricCard label="Ortalama puan" value="740" hint="/ 1000" icon={BarChart3} tone="info" />
        <MetricCard label="Yüksek seviye" value="1" icon={Award} />
        <MetricCard label="Eksik değerlendirme" value="0" icon={AlertCircle} tone="info" />
      </div>

      <section className="mb-6">
        <SectionHeader title="Pozisyon puanları" description="Faktör bazlı kırılım" />
        <div className="mt-3 space-y-3">
          {jobEvaluations.map((je) => (
            <article key={je.id} className="rounded-lg border border-border bg-card p-4">
              <header className="mb-3 flex items-center justify-between gap-3">
                <div>
                  <div className="text-[15px] font-semibold text-foreground">{je.position}</div>
                  <div className="text-xs text-muted-foreground">{je.band}</div>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-semibold tabular text-foreground">{je.total}</div>
                  <div className="text-[11px] uppercase tracking-wider text-muted-foreground">/ 1000</div>
                </div>
              </header>
              <dl className="space-y-2">
                {evaluationFactors.map((f) => {
                  const v = je.factors[f.key as keyof typeof je.factors];
                  const pct = (v / 250) * 100;
                  return (
                    <div
                      key={f.key}
                      className="grid grid-cols-[110px_1fr_42px] items-center gap-3 sm:grid-cols-[160px_1fr_56px]"
                    >
                      <dt className="text-[12px] text-muted-foreground">{f.label}</dt>
                      <dd className="h-1.5 overflow-hidden rounded-full bg-neutral-soft">
                        <div className="h-full rounded-full bg-primary" style={{ width: `${pct}%` }} />
                      </dd>
                      <dd className="text-right text-[12px] tabular text-foreground">{v}</dd>
                    </div>
                  );
                })}
              </dl>
            </article>
          ))}
        </div>
      </section>

      <section>
        <SectionHeader title="Seviye bandları" />
        <div className="mt-3 grid gap-2 sm:grid-cols-3">
          {[
            { label: "Seviye 5", range: "800–1000", note: "Yönetim", tone: "bg-primary/10 text-primary" },
            { label: "Seviye 4", range: "650–799", note: "Kıdemli uzman", tone: "bg-info-soft text-info" },
            { label: "Seviye 3", range: "500–649", note: "Uzman", tone: "bg-neutral-soft text-foreground" },
          ].map((b) => (
            <div key={b.label} className="rounded-lg border border-border bg-card p-4">
              <span className={`inline-flex rounded-full px-2 py-0.5 text-[11px] font-semibold ${b.tone}`}>
                {b.label}
              </span>
              <div className="mt-2 text-sm font-medium text-foreground">{b.range}</div>
              <div className="text-xs text-muted-foreground">{b.note}</div>
            </div>
          ))}
        </div>
      </section>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const jobEvaluations = [
  {
    id: "je1",
    position: "İK Yöneticisi",
    total: 855,
    band: "Seviye 5",
    factors: { knowledge: 220, problem: 200, responsibility: 240, impact: 195 },
  },
  {
    id: "je2",
    position: "Saha Mühendisi",
    total: 720,
    band: "Seviye 4",
    factors: { knowledge: 200, problem: 190, responsibility: 170, impact: 160 },
  },
  {
    id: "je3",
    position: "Operasyon Uzmanı",
    total: 645,
    band: "Seviye 3",
    factors: { knowledge: 170, problem: 160, responsibility: 160, impact: 155 },
  },
];

export const evaluationFactors = [
  { key: "knowledge", label: "Bilgi" },
  { key: "problem", label: "Problem çözme" },
  { key: "responsibility", label: "Sorumluluk" },
  { key: "impact", label: "Etki" },
] as const;
```

## UI/UX Kabul Kriterleri

- Metrikler: Değerlendirilen pozisyon, Ortalama puan, Yüksek seviye, Eksik değerlendirme.
- Pozisyon puanları faktör bazlı barlarla gösterilmeli.
- Seviye bandları ayrı kartlarda gösterilmeli.
- Metodoloji kesinleşmediği için edit/create akışı ekleme.

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

İK Yönetimi altında gerçek route. `soon` kaldırılmalı.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|is-degerleme.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/is-degerleme`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
