# Cursor Prompt — /ai-koc (AI Koç)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/ai-koc` ekranını Lovable prototipindeki `ai-koc.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

Ekran grubu: **Yapay Zeka**

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/ai-koc.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/ai-koc`
- Hedef dosya: `src/routes/_app/ai-koc.tsx`
- Navigation: Yapay Zeka altında gerçek route. Floating button ile çelişmemeli.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/ai-koc.tsx`
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
import { Sparkles, Shield, Check, Clock, Bell, ArrowLeft } from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { aiCoachCapabilities, aiCoachReadiness } from "@/lib/demo-data";

export const Route = createFileRoute("/ai-koc")({
  head: () => ({
    meta: [
      { title: "AI Koç — PULS" },
      { name: "description", content: "PULS AI Coach yakında performans, izin, masraf ve politika sorularında yardımcı olacak." },
    ],
  }),
  component: AiKocPage,
});

function AiKocPage() {
  return (
    <PageContainer>
      <PageHeader
        eyebrow="Yapay Zeka"
        title="AI Koç"
        description="PULS AI Coach yakında performans, izin, masraf ve politika sorularında yardımcı olacak."
      />

      {/* Hero teaser */}
      <div className="mb-6 overflow-hidden rounded-lg border border-ai/20 bg-ai-soft p-5">
        <div className="flex items-start gap-3">
          <span className="flex h-11 w-11 items-center justify-center rounded-lg bg-ai/15 text-ai">
            <Sparkles className="h-5 w-5" />
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-base font-semibold text-ai">AI Coach</h2>
              <span className="rounded-full bg-ai/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase text-ai">
                Yakında
              </span>
            </div>
            <p className="mt-1 text-sm text-ai/90">
              MVP-2'de açılacak. Aktif chat henüz yok; aşağıda neler yapacağını ve hazırlık durumunu
              görebilirsin.
            </p>
          </div>
        </div>
      </div>

      <section className="mb-6">
        <SectionHeader title="Neler yapacak" />
        <ul className="mt-3 grid gap-3 sm:grid-cols-2">
          {aiCoachCapabilities.map((c) => (
            <li key={c.id} className="rounded-lg border border-border bg-card p-4">
              <div className="flex items-start gap-3">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-ai/10 text-ai">
                  <Sparkles className="h-4 w-4" />
                </span>
                <div className="min-w-0">
                  <div className="text-sm font-semibold text-foreground">{c.title}</div>
                  <p className="mt-0.5 text-xs text-muted-foreground">{c.desc}</p>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </section>

      <section className="mb-6">
        <SectionHeader title="Gizlilik" />
        <div className="mt-3 flex items-start gap-3 rounded-lg border border-border bg-card p-4">
          <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <Shield className="h-[18px] w-[18px]" />
          </span>
          <p className="text-sm text-foreground">
            Kişisel görüşmeler yöneticilere açık olmayacak. Erişim politikası ve veri kapsamı MVP-2'de
            netleşecek.
          </p>
        </div>
      </section>

      <section className="mb-6">
        <SectionHeader title="Hazırlık" />
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {aiCoachReadiness.map((r) => (
            <li key={r.id} className="flex items-center gap-3 p-4">
              <span
                className={
                  r.status === "done"
                    ? "flex h-7 w-7 items-center justify-center rounded-full bg-success-soft text-success"
                    : "flex h-7 w-7 items-center justify-center rounded-full bg-warning-soft text-warning"
                }
              >
                {r.status === "done" ? <Check className="h-4 w-4" /> : <Clock className="h-4 w-4" />}
              </span>
              <span className="flex-1 text-sm text-foreground">{r.label}</span>
              <span className="text-xs text-muted-foreground">
                {r.status === "done" ? "Tamam" : "Bekliyor"}
              </span>
            </li>
          ))}
        </ul>
      </section>

      <div className="flex flex-col gap-2 sm:flex-row">
        <button
          type="button"
          onClick={() => toast.success("Hazır olduğunda bilgilendirileceksin")}
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md bg-ai px-4 text-sm font-semibold text-white hover:bg-ai/90"
        >
          <Bell className="h-4 w-4" /> Beni bilgilendir
        </button>
        <Link
          to="/"
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent"
        >
          <ArrowLeft className="h-4 w-4" /> Dashboard'a dön
        </Link>
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const aiCoachCapabilities = [
  { id: "a1", title: "İzin planı önerisi", desc: "Bakiyene ve takım takvimine göre optimum tarih önerir." },
  { id: "a2", title: "Masraf politika açıklaması", desc: "Bir harcamanın hangi kategoriye düştüğünü ve limitini açıklar." },
  { id: "a3", title: "Performans dönem hatırlatmaları", desc: "Açılış, ara değerlendirme ve kapanış için bildirimler." },
  { id: "a4", title: "Kariyer gelişim önerileri", desc: "Yetkinlik boşluklarına göre eğitim ve hedef önerir." },
];

export const aiCoachReadiness = [
  { id: "r1", label: "Vault şeması hazır", status: "done" as const },
  { id: "r2", label: "Tool-call katmanı MVP-2", status: "pending" as const },
  { id: "r3", label: "ERP bağlamı bekleniyor", status: "pending" as const },
];
```

## UI/UX Kabul Kriterleri

- Aktif chat veya mesaj input’u ekleme.
- Hero teaser: Yakında/MVP-2 net olmalı.
- Neler yapacak, Gizlilik, Hazırlık bölümleri korunmalı.
- Gizlilik metni kişisel görüşmelerin yöneticilere açık olmayacağını net belirtmeli.
- Beni bilgilendir CTA sadece teaser feedback vermeli.

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

Yapay Zeka altında gerçek route. Floating button ile çelişmemeli.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|ai-koc.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/ai-koc`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
