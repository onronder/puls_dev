# Cursor Prompt — /menu (Menü Parity)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/menu` ekranını Lovable prototipindeki `menu.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

Ekran grubu: **Mobil Menü**

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/menu.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/menu`
- Hedef dosya: `src/routes/_app/menu.tsx`
- Navigation: Mobile bottom tab’daki `/menu` korunur.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/menu.tsx`
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
import { useState } from "react";
import { ChevronRight, LogOut, Sparkles, X } from "lucide-react";
import { toast } from "sonner";
import { Sheet, SheetTrigger } from "@/components/ui/sheet";
import { SheetShell } from "@/components/puls/SheetShell";
import { PageContainer } from "@/components/puls/AppShell";
import { menuGroups } from "@/components/puls/nav-items";
import { currentUser, tenant } from "@/lib/demo-data";
import { StatusPill } from "@/components/puls/StatusPill";

export const Route = createFileRoute("/menu")({
  head: () => ({ meta: [{ title: "Menü — PULS" }] }),
  component: MenuPage,
});

function MenuPage() {
  const [logoutOpen, setLogoutOpen] = useState(false);
  return (
    <PageContainer>
      <div className="mb-5">
        <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
          Hesabım
        </div>
        <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
          Menü
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Profil, tercihler ve modül erişimi tek yerde.
        </p>
      </div>
      {/* Profile card */}
      <div className="overflow-hidden rounded-2xl border border-border bg-card">
        <div className="flex items-center gap-4 p-5">
          <span className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10 text-lg font-semibold text-primary">
            {currentUser.initials}
          </span>
          <div className="min-w-0 flex-1">
            <div className="truncate text-base font-semibold">{currentUser.name}</div>
            <div className="truncate text-sm text-muted-foreground">{tenant.name}</div>
            <div className="mt-1.5">
              <StatusPill tone="success">{currentUser.status}</StatusPill>
            </div>
          </div>
        </div>
        <div className="grid grid-cols-3 divide-x divide-border border-t border-border bg-surface-2 text-center">
          <Stat label="Çalışan" value={tenant.employees} />
          <Stat label="Departman" value={tenant.departments} />
          <Stat label="Pozisyon" value={tenant.positions} />
        </div>
      </div>

      {/* AI teaser */}
      <div className="mt-5 flex items-start gap-3 rounded-xl border border-ai/20 bg-ai-soft p-4">
        <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-ai/15 text-ai">
          <Sparkles className="h-[18px] w-[18px]" />
        </span>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <div className="text-sm font-semibold text-ai">AI Coach</div>
            <span className="rounded-full bg-ai/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase text-ai">
              Yakında
            </span>
          </div>
          <p className="mt-0.5 text-xs text-ai/90">
            Performans değerlendirmesi, izin planlaması ve politika sorularında yardımcı olacak.
          </p>
        </div>
      </div>

      {/* Menu groups */}
      <div className="mt-6 space-y-6">
        {menuGroups.map((group) => (
          <section key={group.label}>
            <div className="mb-2 px-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              {group.label}
            </div>
            <ul className="divide-y divide-border overflow-hidden rounded-xl border border-border bg-card">
              {group.items.map((item) => {
                const inner = (
                  <>
                    <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-secondary text-secondary-foreground">
                      <item.icon className="h-[18px] w-[18px]" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[15px] font-medium text-foreground">
                        {item.label}
                      </div>
                    </div>
                    {item.comingSoon ? (
                      <StatusPill tone="neutral">Yakında</StatusPill>
                    ) : (
                      <ChevronRight className="h-4 w-4 text-muted-foreground" />
                    )}
                  </>
                );
                return (
                  <li key={item.label}>
                    {item.comingSoon ? (
                      <div className="flex min-h-[56px] cursor-not-allowed items-center gap-3 p-3.5 opacity-80">
                        {inner}
                      </div>
                    ) : (
                      <Link
                        to={item.to}
                        className="flex min-h-[56px] items-center gap-3 p-3.5 transition-colors hover:bg-accent/40"
                      >
                        {inner}
                      </Link>
                    )}
                  </li>
                );
              })}
            </ul>
          </section>
        ))}
      </div>

      <Sheet open={logoutOpen} onOpenChange={setLogoutOpen}>
        <SheetTrigger asChild>
          <button
            type="button"
            className="mt-8 flex min-h-11 w-full items-center justify-center gap-2 rounded-lg border border-border bg-card py-3 text-sm font-medium text-danger hover:bg-danger-soft"
          >
            <LogOut className="h-4 w-4" /> Oturumu kapat
          </button>
        </SheetTrigger>
        <SheetShell
          title="Oturumu kapat?"
          description="Aktif oturumun sonlandırılacak."
          footer={
            <>
              <button
                type="button"
                onClick={() => setLogoutOpen(false)}
                className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent"
              >
                <X className="h-4 w-4" /> Vazgeç
              </button>
              <button
                type="button"
                onClick={() => {
                  setLogoutOpen(false);
                  toast("Oturum kapatıldı", { description: "Demo modunda yönlendirme atlandı." });
                }}
                className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md bg-danger text-sm font-semibold text-white hover:bg-danger/90"
              >
                <LogOut className="h-4 w-4" /> Oturumu kapat
              </button>
            </>
          }
        >
          <p className="text-sm text-muted-foreground">
            Devam etmeden önce bekleyen taslakların kaydedildiğinden emin ol.
          </p>
        </SheetShell>
      </Sheet>


      <p className="mt-6 text-center text-xs text-muted-foreground">PULS · v0.1 prototip</p>
    </PageContainer>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="px-3 py-3">
      <div className="tabular text-base font-semibold text-foreground">{value}</div>
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</div>
    </div>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const currentUser = {
  name: "Demo İK Yöneticisi",
  role: "İK Yöneticisi",
  tenant: tenant.name,
  status: "Aktif" as const,
  initials: "DY",
};

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

- Profil kartı, tenant metrikleri, AI teaser ve tüm menu group’ları korunmalı.
- Route’u tamamlanan ekranlarda `Yakında` pill’i kaldırılmalı.
- Çalışan/manager persona görünürlüğü korunmalı.
- Logout gerçek signOut ile uyumlu olmalı.

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

Mobile bottom tab’daki `/menu` korunur.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|menu.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/menu`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
