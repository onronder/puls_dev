# Cursor Prompt — /ayarlar (Ayarlar)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/ayarlar` ekranını Lovable prototipindeki `ayarlar.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

Ekran grubu: **Sistem**

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/ayarlar.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/ayarlar`
- Hedef dosya: `src/routes/_app/ayarlar.tsx`
- Navigation: Sistem altında gerçek route. `/menu` içinden erişilebilir.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/ayarlar.tsx`
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
import { ChevronRight } from "lucide-react";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { settingsSections } from "@/lib/demo-data";

export const Route = createFileRoute("/ayarlar")({
  head: () => ({
    meta: [
      { title: "Ayarlar — PULS" },
      { name: "description", content: "Güvenlik, bildirim, dil ve sistem tercihleri." },
    ],
  }),
  component: AyarlarPage,
});

function AyarlarPage() {
  return (
    <PageContainer>
      <PageHeader
        eyebrow="Sistem"
        title="Ayarlar"
        description="Güvenlik, bildirim, dil ve sistem tercihlerini yönet."
      />

      <ul className="divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
        {settingsSections.map((s) => (
          <li key={s.id}>
            <button
              type="button"
              className="flex w-full min-h-[64px] items-center gap-3 p-4 text-left transition-colors hover:bg-accent/40"
            >
              <div className="min-w-0 flex-1">
                <div className="text-[15px] font-medium text-foreground">{s.title}</div>
                <div className="truncate text-xs text-muted-foreground">{s.summary}</div>
              </div>
              <span className="hidden text-xs font-medium text-primary sm:inline">{s.action}</span>
              <ChevronRight className="h-4 w-4 text-muted-foreground" />
            </button>
          </li>
        ))}
      </ul>

      <div className="mt-6 rounded-lg border border-border bg-card p-4">
        <div className="text-sm font-medium text-foreground">Audit log</div>
        <p className="mt-1 text-xs text-muted-foreground">
          Son 30 günde 14 hassas işlem kaydı bulunuyor. Detaylı log MVP-2'de görüntülenecek.
        </p>
        <Link
          to="/menu"
          className="mt-3 inline-flex h-10 items-center justify-center rounded-md border border-border bg-card px-3 text-sm font-medium hover:bg-accent"
        >
          Geçici olarak menüye dön
        </Link>
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const settingsSections = [
  { id: "s1", title: "Hesap & güvenlik", summary: "Şifre, 2FA, oturum geçmişi", action: "Yönet" },
  { id: "s2", title: "Tenant ayarları", summary: "Mert Teknik A.Ş. · Pilot paket", action: "Aç" },
  { id: "s3", title: "Bildirim tercihleri", summary: "E-posta · Uygulama içi", action: "Düzenle" },
  { id: "s4", title: "Dil ve bölge", summary: "tr-TR · Europe/Istanbul", action: "Değiştir" },
  { id: "s5", title: "Tema", summary: "Sistem · Açık · Koyu", action: "Seç" },
  { id: "s6", title: "Rol & erişim", summary: "İK Admin · 3 modül tam yetki", action: "İncele" },
];
```

## UI/UX Kabul Kriterleri

- Ayar bölümleri listesi korunmalı: hesap/güvenlik, tenant, bildirim, dil, tema, rol/erişim.
- Ayar satırları gerçek link gibi görünmemeli; çalışmıyorsa disabled/teaser veya SheetShell olmalı.
- Audit log teaser korunmalı ama “MVP-2” metni net olmalı.
- Bu ekran Lovable’da zayıf; UI polish yap ama kapsamı büyütme.

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

Sistem altında gerçek route. `/menu` içinden erişilebilir.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|ayarlar.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/ayarlar`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
