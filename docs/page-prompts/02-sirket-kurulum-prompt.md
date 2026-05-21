# Cursor Prompt — /sirket-kurulum (Şirket Kurulum)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/sirket-kurulum` ekranını Lovable prototipindeki `sirket-kurulum.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/sirket-kurulum.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/sirket-kurulum`
- Hedef dosya: `src/routes/_app/sirket-kurulum.tsx`
- Navigation: Tanım & Kurulum altında gerçek route. `/menu` içinde tıklanabilir.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/sirket-kurulum.tsx`
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
import { Building, CheckCircle2, AlertCircle, Plug, Clock } from "lucide-react";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { companySetup } from "@/lib/demo-data";

export const Route = createFileRoute("/sirket-kurulum")({
  head: () => ({
    meta: [
      { title: "Şirket Kurulum — PULS" },
      { name: "description", content: "Tenant, şirket bilgileri ve varsayılan çalışma ayarları." },
    ],
  }),
  component: SirketKurulumPage,
});

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[140px_1fr] items-center gap-3 px-4 py-3 sm:grid-cols-[200px_1fr]">
      <dt className="text-[12px] uppercase tracking-wider text-muted-foreground">{label}</dt>
      <dd className="text-sm text-foreground">{value}</dd>
    </div>
  );
}

function SirketKurulumPage() {
  return (
    <PageContainer>
      <PageHeader
        eyebrow="Tanım & Kurulum"
        title="Şirket Kurulum"
        description="Tenant, şirket bilgileri ve varsayılan çalışma ayarlarını yönet."
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Tamamlanma" value={`%${companySetup.completion}`} icon={CheckCircle2} tone="info" />
        <MetricCard label="Eksik alan" value={companySetup.missing} icon={AlertCircle} tone="warning" />
        <MetricCard label="ERP hazırlığı" value="6 / 12" icon={Plug} />
        <MetricCard label="Dil" value="tr-TR" icon={Building} />
      </div>

      <section className="mb-6">
        <SectionHeader title="Şirket bilgileri" />
        <dl className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          <Row label="Şirket adı" value={companySetup.name} />
          <Row label="VKN" value={companySetup.vkn} />
          <Row label="Sektör" value={companySetup.sector} />
          <Row label="Çalışan bandı" value={companySetup.band} />
          <Row label="Varsayılan dil" value={companySetup.language} />
          <Row label="Timezone" value={companySetup.timezone} />
          <Row label="Paket" value={companySetup.package} />
        </dl>
      </section>

      <section>
        <SectionHeader title="Kurulum checklist" />
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {companySetup.checklist.map((c) => (
            <li key={c.id} className="flex items-center gap-3 p-4">
              <span
                className={
                  c.status === "done"
                    ? "flex h-7 w-7 items-center justify-center rounded-full bg-success-soft text-success"
                    : "flex h-7 w-7 items-center justify-center rounded-full bg-warning-soft text-warning"
                }
              >
                {c.status === "done" ? <CheckCircle2 className="h-4 w-4" /> : <Clock className="h-4 w-4" />}
              </span>
              <div className="min-w-0 flex-1 text-sm text-foreground">{c.label}</div>
              {c.status === "done" ? (
                <StatusPill tone="success">Tamam</StatusPill>
              ) : (
                <StatusPill tone="warning">Bekliyor</StatusPill>
              )}
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
export const companySetup = {
  name: "Mert Teknik A.Ş.",
  vkn: "—",
  sector: "Üretim / Teknik servis",
  band: "1-50 çalışan",
  language: "tr-TR",
  timezone: "Europe/Istanbul",
  package: "Pilot",
  completion: 72,
  missing: 3,
  checklist: [
    { id: "ck1", label: "Tenant oluşturuldu", status: "done" as const },
    { id: "ck2", label: "Demo çalışanlar eklendi", status: "done" as const },
    { id: "ck3", label: "ERP alan eşleştirme bekliyor", status: "pending" as const },
    { id: "ck4", label: "Performans dönemi bekliyor", status: "pending" as const },
  ],
};
```

## UI/UX Kabul Kriterleri

- Şirket bilgileri section: şirket adı, VKN, sektör, çalışan bandı, dil, timezone, paket.
- Kurulum checklist section: done/pending durumları ikon ve StatusPill ile gösterilmeli.
- Metrikler: Tamamlanma, Eksik alan, ERP hazırlığı, Dil.
- VKN `—` ise boş değer tasarım olarak kırık görünmemeli.

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
rg -n 'Hello "/_app|sirket-kurulum.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/sirket-kurulum`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
