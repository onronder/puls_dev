# Cursor Prompt — /sozlesmeler (Sözleşmeler)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/sozlesmeler` ekranını Lovable prototipindeki `sozlesmeler.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

Ekran grubu: **Çalışan Süreçleri**

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/sozlesmeler.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/sozlesmeler`
- Hedef dosya: `src/routes/_app/sozlesmeler.tsx`
- Navigation: Çalışan Süreçleri altında gerçek route. `soon` kaldırılmalı.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/sozlesmeler.tsx`
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
import { FileText, AlertTriangle, FileSignature, ShieldCheck, Bell, Eye, Upload } from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { DataList, type DataColumn } from "@/components/puls/DataList";
import { contracts } from "@/lib/demo-data";

export const Route = createFileRoute("/sozlesmeler")({
  head: () => ({
    meta: [
      { title: "Sözleşmeler — PULS" },
      { name: "description", content: "Çalışan sözleşmeleri, bitiş tarihleri ve imza durumları." },
    ],
  }),
  component: SozlesmelerPage,
});

function SozlesmelerPage() {
  type C = (typeof contracts)[number];
  const columns: DataColumn<C>[] = [
    {
      key: "employee",
      header: "Çalışan",
      render: (r) => (
        <span className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary/10 text-[11px] font-semibold text-primary">
            {r.initials}
          </span>
          <span className="font-medium">{r.employee}</span>
        </span>
      ),
    },
    { key: "type", header: "Tip", render: (r) => r.type },
    { key: "start", header: "Başlangıç", render: (r) => <span className="tabular">{r.start}</span> },
    { key: "end", header: "Bitiş", render: (r) => <span className="tabular">{r.end}</span> },
    {
      key: "signed",
      header: "İmza",
      render: (r) =>
        r.signed === "signed" ? (
          <StatusPill tone="success">İmzalı</StatusPill>
        ) : (
          <StatusPill tone="warning">Bekliyor</StatusPill>
        ),
    },
    {
      key: "risk",
      header: "Risk",
      render: (r) =>
        r.risk === "ok" ? (
          <StatusPill tone="success">Aktif</StatusPill>
        ) : r.risk === "expiring" ? (
          <StatusPill tone="warning">Yakında bitiyor</StatusPill>
        ) : (
          <StatusPill tone="info">İmza bekliyor</StatusPill>
        ),
    },
  ];

  return (
    <PageContainer>
      <PageHeader
        eyebrow="Çalışan Süreçleri"
        title="Sözleşmeler"
        description="Çalışan sözleşmelerini, bitiş tarihlerini ve imza durumlarını takip et."
        action={
          <button
            type="button"
            onClick={() => toast("Sözleşme yükleme akışı MVP-2'de açılacak")}
            className="inline-flex h-10 items-center gap-1.5 rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            <Upload className="h-4 w-4" /> Belge yükle
          </button>
        }
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Aktif sözleşme" value="4" icon={FileText} />
        <MetricCard label="Yakında bitecek" value="1" icon={AlertTriangle} tone="warning" />
        <MetricCard label="İmza bekleyen" value="1" icon={FileSignature} tone="info" />
        <MetricCard label="KVKK eksik" value="0" icon={ShieldCheck} />
      </div>

      <section className="mb-6">
        <SectionHeader title="Sözleşme listesi" />
        <div className="mt-3">
          <DataList columns={columns} rows={contracts} rowKey={(r) => r.id} mobileTitleKey="employee" />
        </div>
      </section>

      <div className="flex flex-col gap-2 sm:flex-row">
        <button
          type="button"
          onClick={() => toast.success("Sözleşme detayı açıldı")}
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent"
        >
          <Eye className="h-4 w-4" /> Detayı görüntüle
        </button>
        <button
          type="button"
          onClick={() => toast.success("Hatırlatıcı 7 gün önce kuruldu")}
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent"
        >
          <Bell className="h-4 w-4" /> Hatırlatıcı kur
        </button>
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const contracts = [
  {
    id: "c1",
    employee: "Ayşe Kaya",
    initials: "AK",
    type: "Belirsiz süreli",
    start: "04 Mar 2024",
    end: "—",
    signed: "signed" as const,
    risk: "ok" as const,
  },
  {
    id: "c2",
    employee: "Murat Tan",
    initials: "MT",
    type: "Belirli süreli",
    start: "18 Eyl 2022",
    end: "05 Tem 2026",
    signed: "signed" as const,
    risk: "expiring" as const,
  },
  {
    id: "c3",
    employee: "Elif Demir",
    initials: "ED",
    type: "Deneme süresi",
    start: "01 Şub 2025",
    end: "01 May 2025",
    signed: "pending" as const,
    risk: "pending" as const,
  },
];
```

## UI/UX Kabul Kriterleri

- Metrikler: Aktif sözleşme, Yakında bitecek, İmza bekleyen, KVKK eksik.
- Sözleşme listesi: çalışan, tip, başlangıç, bitiş, imza, risk.
- Lovable verisindeki metrik/list count tutarsızlığını düzelt: 3 kayıt varsa aktif sözleşme 3 olmalı veya demo data 4 kayda çıkarılmalı.
- Elif Demir bitiş tarihi 2025 ise güncel demo tarihiyle değiştir; 21 Mayıs 2026 itibarıyla bayat tarih bırakma.
- Belge yükle CTA toast-only olmamalı: disabled/teaser veya SheetShell.

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

Çalışan Süreçleri altında gerçek route. `soon` kaldırılmalı.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|sozlesmeler.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/sozlesmeler`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
