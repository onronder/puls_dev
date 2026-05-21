# Cursor Prompt — /pozisyonlar (Pozisyonlar)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/pozisyonlar` ekranını Lovable prototipindeki `pozisyonlar.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/pozisyonlar.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/pozisyonlar`
- Hedef dosya: `src/routes/_app/pozisyonlar.tsx`
- Navigation: Tanım & Kurulum altında gerçek route. `/menu` içinde tıklanabilir.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/pozisyonlar.tsx`
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
import { Briefcase, FileCheck2, Scale, Plus } from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { DataList, type DataColumn } from "@/components/puls/DataList";
import { positionsFull, tenant } from "@/lib/demo-data";

export const Route = createFileRoute("/pozisyonlar")({
  head: () => ({
    meta: [
      { title: "Pozisyonlar — PULS" },
      { name: "description", content: "Pozisyonlar, departman bağlantıları ve yetkinlik şablonları." },
    ],
  }),
  component: PozisyonlarPage,
});

function PozisyonlarPage() {
  type P = (typeof positionsFull)[number];
  const columns: DataColumn<P>[] = [
    { key: "name", header: "Pozisyon", render: (r) => <span className="font-medium">{r.name}</span> },
    { key: "department", header: "Departman", render: (r) => r.department },
    { key: "template", header: "Şablon", render: (r) => r.template },
    {
      key: "evaluation",
      header: "İş değerleme",
      render: (r) => <span className="tabular font-medium">{r.evaluation}</span>,
    },
  ];

  return (
    <PageContainer>
      <PageHeader
        eyebrow="Tanım & Kurulum"
        title="Pozisyonlar"
        description="Pozisyonları, departman bağlantılarını ve yetkinlik şablonlarını takip et."
        action={
          <button
            type="button"
            onClick={() => toast("Pozisyon ekleme formu MVP-2'de açılacak")}
            className="inline-flex h-10 items-center gap-1.5 rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            <Plus className="h-4 w-4" /> Pozisyon ekle
          </button>
        }
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Pozisyon" value={tenant.positions} icon={Briefcase} />
        <MetricCard label="Açık pozisyon" value="0" icon={Briefcase} tone="info" />
        <MetricCard label="Şablon bağlı" value="3" icon={FileCheck2} />
        <MetricCard label="İş değerleme tamam" value="3" icon={Scale} />
      </div>

      <SectionHeader title="Pozisyon listesi" />
      <div className="mt-3">
        <DataList columns={columns} rows={positionsFull} rowKey={(r) => r.id} mobileTitleKey="name" />
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const positionsFull = [
  { id: "p1", name: "İK Yöneticisi", department: "İK & Finans", template: "Yönetici", evaluation: 855, open: 0 },
  { id: "p2", name: "Saha Mühendisi", department: "Mühendislik", template: "Saha Mühendisi", evaluation: 720, open: 0 },
  { id: "p3", name: "Operasyon Uzmanı", department: "Operasyon", template: "Ofis & Operasyon", evaluation: 645, open: 0 },
];

export const tenant = {
  name: "Mert Teknik A.Ş.",
  erp: { name: "Canias", status: "beklemede" as const },
  employees: 4,
  departments: 3,
  positions: 3,
  competencyTemplates: 3,
  dataReadiness: 72,
};
```

## UI/UX Kabul Kriterleri

- Metrikler: Pozisyon, Açık pozisyon, Şablon bağlı, İş değerleme tamam.
- Pozisyon listesi: Pozisyon, Departman, Şablon, İş değerleme.
- Pozisyon ekle CTA toast-only olmamalı: SheetShell veya disabled/teaser.
- İş değerleme puanları tabular ve hizalı gösterilmeli.

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
rg -n 'Hello "/_app|pozisyonlar.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/pozisyonlar`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
