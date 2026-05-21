# Cursor Prompt — /masraf-kategorileri (Masraf Kategorileri)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/masraf-kategorileri` ekranını Lovable prototipindeki `masraf-kategorileri.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/masraf-kategorileri.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/masraf-kategorileri`
- Hedef dosya: `src/routes/_app/masraf-kategorileri.tsx`
- Navigation: Tanım & Kurulum altında gerçek route. `/menu` içinde tıklanabilir.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/masraf-kategorileri.tsx`
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
import { Receipt, FileCheck2, Workflow, Wallet, Plus } from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { DataList, type DataColumn } from "@/components/puls/DataList";
import { expenseCategoryRules, formatTRY } from "@/lib/demo-data";

export const Route = createFileRoute("/masraf-kategorileri")({
  head: () => ({
    meta: [
      { title: "Masraf Kategorileri — PULS" },
      { name: "description", content: "Harcama kategorileri, limitler ve belge zorunlulukları." },
    ],
  }),
  component: MasrafKategorileriPage,
});

function MasrafKategorileriPage() {
  type E = (typeof expenseCategoryRules)[number];
  const totalLimit = expenseCategoryRules.reduce((s, c) => s + c.monthly, 0);
  const columns: DataColumn<E>[] = [
    { key: "name", header: "Kategori", render: (r) => <span className="font-medium">{r.name}</span> },
    {
      key: "monthly",
      header: "Aylık limit",
      render: (r) => <span className="tabular">{formatTRY(r.monthly)}</span>,
    },
    {
      key: "doc",
      header: "Belge eşiği",
      render: (r) => <span className="tabular">{formatTRY(r.docThreshold)} üzeri</span>,
    },
    { key: "code", header: "Muhasebe kodu", render: (r) => <span className="tabular">{r.code}</span> },
  ];

  return (
    <PageContainer>
      <PageHeader
        eyebrow="Tanım & Kurulum"
        title="Masraf Kategorileri"
        description="Harcama kategorilerini, limitleri ve belge zorunluluklarını yönet."
        action={
          <button
            type="button"
            onClick={() => toast("Kategori ekleme formu MVP-2'de açılacak")}
            className="inline-flex h-10 items-center gap-1.5 rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            <Plus className="h-4 w-4" /> Kategori ekle
          </button>
        }
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Kategori" value="6" icon={Receipt} />
        <MetricCard label="Aylık toplam limit" value={formatTRY(totalLimit)} icon={Wallet} tone="info" />
        <MetricCard label="Belge eşiği" value={formatTRY(2000)} icon={FileCheck2} tone="warning" />
        <MetricCard label="Onay seviyesi" value="2" icon={Workflow} />
      </div>

      <SectionHeader title="Kategori listesi" />
      <div className="mt-3">
        <DataList
          columns={columns}
          rows={expenseCategoryRules}
          rowKey={(r) => r.id}
          mobileTitleKey="name"
        />
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const expenseCategoryRules = [
  { id: "ec1", name: "Seyahat", monthly: 15000, docThreshold: 2000, code: "770.01" },
  { id: "ec2", name: "Yemek", monthly: 5000, docThreshold: 500, code: "770.02" },
  { id: "ec3", name: "Konaklama", monthly: 20000, docThreshold: 2000, code: "770.03" },
  { id: "ec4", name: "Yazılım", monthly: 10000, docThreshold: 1000, code: "770.04" },
  { id: "ec5", name: "Ulaşım", monthly: 3000, docThreshold: 500, code: "770.05" },
  { id: "ec6", name: "Diğer", monthly: 2000, docThreshold: 500, code: "770.99" },
];

export const formatTRY = (n: number) =>
  "₺" + new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(n);
```

## UI/UX Kabul Kriterleri

- Metrikler: Kategori, Aylık toplam limit, Belge eşiği, Onay seviyesi.
- Kategori listesi: kategori, aylık limit, belge eşiği, muhasebe kodu.
- Toplam limit ürün kararıyla tutarlı olmalı; Lovable toplamı ₺55.000 ise bunu açıkça koru veya doc’a göre güncelle.
- Kategori ekle CTA toast-only olmamalı.

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
rg -n 'Hello "/_app|masraf-kategorileri.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/masraf-kategorileri`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
