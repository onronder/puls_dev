# Cursor Prompt — /izin-tanimlari (İzin Tanımları)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/izin-tanimlari` ekranını Lovable prototipindeki `izin-tanimlari.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/izin-tanimlari.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/izin-tanimlari`
- Hedef dosya: `src/routes/_app/izin-tanimlari.tsx`
- Navigation: Tanım & Kurulum altında gerçek route. `/menu` içinde tıklanabilir.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/izin-tanimlari.tsx`
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
import { CalendarDays, Check, FileCheck2, Workflow, Plus } from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { DataList, type DataColumn } from "@/components/puls/DataList";
import { leaveTypeRules } from "@/lib/demo-data";

export const Route = createFileRoute("/izin-tanimlari")({
  head: () => ({
    meta: [
      { title: "İzin Tanımları — PULS" },
      { name: "description", content: "İzin tipleri, haklar, belge ve onay kuralları." },
    ],
  }),
  component: IzinTanimlariPage,
});

function IzinTanimlariPage() {
  type L = (typeof leaveTypeRules)[number];
  const columns: DataColumn<L>[] = [
    { key: "label", header: "İzin tipi", render: (r) => <span className="font-medium">{r.label}</span> },
    { key: "days", header: "Gün", render: (r) => <span className="tabular">{r.days}</span> },
    {
      key: "paid",
      header: "Ücret",
      render: (r) =>
        r.paid ? (
          <StatusPill tone="success">Ücretli</StatusPill>
        ) : (
          <StatusPill tone="neutral">Ücretsiz</StatusPill>
        ),
    },
    {
      key: "doc",
      header: "Belge",
      render: (r) =>
        r.doc ? <StatusPill tone="warning">Zorunlu</StatusPill> : <span className="text-muted-foreground">—</span>,
    },
    {
      key: "carry",
      header: "Devir",
      render: (r) =>
        r.carryOver ? (
          <span className="inline-flex items-center gap-1 text-success">
            <Check className="h-3.5 w-3.5" /> Var
          </span>
        ) : (
          <span className="text-muted-foreground">—</span>
        ),
    },
  ];

  return (
    <PageContainer>
      <PageHeader
        eyebrow="Tanım & Kurulum"
        title="İzin Tanımları"
        description="İzin tiplerini, hakları, belge ve onay kurallarını tanımla."
        action={
          <button
            type="button"
            onClick={() => toast("İzin tipi ekleme formu MVP-2'de açılacak")}
            className="inline-flex h-10 items-center gap-1.5 rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            <Plus className="h-4 w-4" /> İzin tipi ekle
          </button>
        }
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="İzin tipi" value="8" icon={CalendarDays} />
        <MetricCard label="Ücretli" value="6" icon={Check} tone="info" />
        <MetricCard label="Belge zorunlu" value="2" icon={FileCheck2} tone="warning" />
        <MetricCard label="Onay akışı" value="1 seviye" icon={Workflow} />
      </div>

      <SectionHeader title="İzin tipleri" />
      <div className="mt-3">
        <DataList columns={columns} rows={leaveTypeRules} rowKey={(r) => r.id} mobileTitleKey="label" />
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const leaveTypeRules = [
  { id: "yillik", label: "Yıllık", days: 20, paid: true, doc: false, carryOver: true },
  { id: "mazeret", label: "Mazeret", days: 10, paid: true, doc: false, carryOver: false },
  { id: "hastalik", label: "Hastalık", days: 10, paid: true, doc: true, carryOver: false },
  { id: "ucretsiz", label: "Ücretsiz", days: 30, paid: false, doc: false, carryOver: false },
  { id: "idari", label: "İdari", days: 5, paid: true, doc: false, carryOver: false },
  { id: "evlilik", label: "Evlilik", days: 3, paid: true, doc: true, carryOver: false },
  { id: "dogum", label: "Doğum/Babalık", days: 16, paid: true, doc: false, carryOver: false },
  { id: "olum", label: "Ölüm", days: 3, paid: true, doc: false, carryOver: false },
];
```

## UI/UX Kabul Kriterleri

- Metrikler: İzin tipi, Ücretli, Belge zorunlu, Onay akışı.
- İzin tipleri listesi: tip, gün, ücret, belge, devir.
- Ücretli/ücretsiz, belge zorunlu ve devir durumları görsel olarak ayrışmalı.
- İzin tipi ekle CTA toast-only olmamalı.

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
rg -n 'Hello "/_app|izin-tanimlari.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/izin-tanimlari`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
