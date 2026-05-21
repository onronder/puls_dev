# Cursor Prompt — /egitim (Eğitim)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/egitim` ekranını Lovable prototipindeki `egitim.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/egitim.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/egitim`
- Hedef dosya: `src/routes/_app/egitim.tsx`
- Navigation: İK Yönetimi altında gerçek route. `soon` kaldırılmalı.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/egitim.tsx`
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
import { BookOpen, GraduationCap, CheckCircle2, Sparkles } from "lucide-react";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { DataList, type DataColumn } from "@/components/puls/DataList";
import { trainings, type TrainingStatus } from "@/lib/demo-data";

export const Route = createFileRoute("/egitim")({
  head: () => ({
    meta: [
      { title: "Eğitim — PULS" },
      { name: "description", content: "Yetkinlik boşluklarına göre eğitim ihtiyaçları ve öneriler." },
    ],
  }),
  component: EgitimPage,
});

function statusPill(s: TrainingStatus) {
  if (s === "completed") return <StatusPill tone="success">Tamamlandı</StatusPill>;
  if (s === "planned") return <StatusPill tone="info">Planlandı</StatusPill>;
  return <StatusPill tone="warning">Önerildi</StatusPill>;
}

function EgitimPage() {
  const columns: DataColumn<(typeof trainings)[number]>[] = [
    { key: "title", header: "Eğitim", render: (r) => <span className="font-medium">{r.title}</span> },
    { key: "who", header: "Çalışan", render: (r) => r.who },
    { key: "competency", header: "Yetkinlik", render: (r) => r.competency },
    { key: "hours", header: "Süre", render: (r) => <span className="tabular">{r.hours} saat</span> },
    { key: "status", header: "Durum", render: (r) => statusPill(r.status) },
  ];

  return (
    <PageContainer>
      <PageHeader
        eyebrow="İK Yönetimi"
        title="Eğitim"
        description="Yetkinlik boşluklarına göre eğitim ihtiyaçlarını ve önerileri takip et."
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Açık eğitim ihtiyacı" value="5" icon={BookOpen} tone="warning" />
        <MetricCard label="Tamamlanan eğitim" value="8" icon={CheckCircle2} tone="info" />
        <MetricCard label="Önerilen eğitim" value="4" icon={Sparkles} tone="ai" />
        <MetricCard label="Ortalama tamamlama" value="%76" icon={GraduationCap} />
      </div>

      <section className="mb-6">
        <SectionHeader title="Eğitim listesi" description="Çalışan bazlı ihtiyaç ve öneriler" />
        <div className="mt-3">
          <DataList
            columns={columns}
            rows={trainings}
            rowKey={(r) => r.id}
            mobileTitleKey="title"
          />
        </div>
      </section>

      <div className="rounded-lg border border-ai/20 bg-ai-soft p-4">
        <div className="flex items-start gap-3">
          <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-ai/15 text-ai">
            <Sparkles className="h-[18px] w-[18px]" />
          </span>
          <div>
            <div className="flex items-center gap-2">
              <div className="text-sm font-semibold text-ai">Okul™ önerisi</div>
              <span className="rounded-full bg-ai/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase text-ai">
                Yakında
              </span>
            </div>
            <p className="mt-0.5 text-xs text-ai/90">
              Yetkinlik boşluklarına ve performans verisine göre öğrenme yolu önerileri MVP-2'de gelecek.
            </p>
          </div>
        </div>
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const trainings = [
  { id: "tr1", title: "Liderlik 101", who: "Ayşe Kaya", competency: "Liderlik", status: "suggested" as TrainingStatus, hours: 6 },
  { id: "tr2", title: "Raporlama & KPI", who: "Ayşe Kaya", competency: "Raporlama", status: "planned" as TrainingStatus, hours: 4 },
  { id: "tr3", title: "İSG yenileme", who: "Murat Tan", competency: "İSG", status: "completed" as TrainingStatus, hours: 8 },
  { id: "tr4", title: "Excel ileri seviye", who: "Elif Demir", competency: "Analiz", status: "completed" as TrainingStatus, hours: 10 },
  { id: "tr5", title: "İletişim becerileri", who: "Murat Tan", competency: "İletişim", status: "suggested" as TrainingStatus, hours: 4 },
];
```

## UI/UX Kabul Kriterleri

- Metrikler: Açık eğitim ihtiyacı, Tamamlanan eğitim, Önerilen eğitim, Ortalama tamamlama.
- Eğitim listesi: eğitim, çalışan, yetkinlik, süre, durum.
- Önerildi/Planlandı/Tamamlandı pill’leri korunmalı.
- Okul/AI öneri teaser aktif modül gibi davranmamalı.

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
rg -n 'Hello "/_app|egitim.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/egitim`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
