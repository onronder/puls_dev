# Cursor Prompt — /profil (Profil)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/profil` ekranını Lovable prototipindeki `profil.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/profil.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/profil`
- Hedef dosya: `src/routes/_app/profil.tsx`
- Navigation: Sistem altında gerçek route. `/menu` içinden erişilebilir.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/profil.tsx`
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
import { LogOut, Shield, Pencil, CalendarCheck, Wallet, Target } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { Sheet, SheetTrigger } from "@/components/ui/sheet";
import { SheetShell } from "@/components/puls/SheetShell";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { StatusPill } from "@/components/puls/StatusPill";
import { currentUser, tenant, leaveBalances, expenseSummary, recentActivity, formatTRY } from "@/lib/demo-data";

export const Route = createFileRoute("/profil")({
  head: () => ({
    meta: [
      { title: "Profil — PULS" },
      { name: "description", content: "Kişisel bilgiler, rol ve Self-HR özeti." },
    ],
  }),
  component: ProfilPage,
});

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[110px_1fr] items-center gap-3 px-4 py-3 sm:grid-cols-[160px_1fr]">
      <dt className="text-[12px] uppercase tracking-wider text-muted-foreground">{label}</dt>
      <dd className="text-sm text-foreground">{value}</dd>
    </div>
  );
}

function ProfilPage() {
  const [logoutOpen, setLogoutOpen] = useState(false);
  return (
    <PageContainer>
      <PageHeader
        eyebrow="Sistem"
        title="Profil"
        description="Kişisel bilgilerini, rolünü ve Self-HR özetini görüntüle."
      />

      <div className="mb-5 flex flex-col gap-3 rounded-lg border border-border bg-card p-5 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-4">
          <span className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10 text-lg font-semibold text-primary">
            {currentUser.initials}
          </span>
          <div className="min-w-0">
            <div className="text-base font-semibold text-foreground">{currentUser.name}</div>
            <div className="truncate text-sm text-muted-foreground">{currentUser.role} · {tenant.name}</div>
            <div className="mt-1.5"><StatusPill tone="success">{currentUser.status}</StatusPill></div>
          </div>
        </div>
        <button
          type="button"
          onClick={() => toast("Bilgi düzenleme formu MVP-2'de açılacak")}
          className="inline-flex h-10 items-center justify-center gap-1.5 rounded-md border border-border bg-card px-3 text-sm font-medium hover:bg-accent"
        >
          <Pencil className="h-4 w-4" /> Bilgileri düzenle
        </button>
      </div>

      <section className="mb-6">
        <dl className="divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          <Row label="E-posta" value="ik@mertteknik.com" />
          <Row label="Departman" value="İK & Finans" />
          <Row label="Pozisyon" value="İK Yöneticisi" />
          <Row label="Tenant" value={tenant.name} />
          <Row label="Persona" value="İK Admin" />
        </dl>
      </section>

      <section className="mb-6">
        <div className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
          Self-HR özeti
        </div>
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-3">
          <MetricCard
            label="İzin bakiyesi"
            value={`${leaveBalances.yillik.remaining}/${leaveBalances.yillik.total}`}
            icon={CalendarCheck}
            hint="Yıllık izin"
          />
          <MetricCard
            label="Bekleyen masraf"
            value={formatTRY(expenseSummary.pending.amount)}
            icon={Wallet}
            tone="warning"
            hint={`${expenseSummary.pending.count} kayıt`}
          />
          <MetricCard label="Performans" value="2026 Q2" icon={Target} tone="info" hint="Henüz açılmadı" />
        </div>
      </section>

      <section className="mb-6">
        <div className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
          Son aktiviteler
        </div>
        <ul className="divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {recentActivity.slice(0, 4).map((a) => (
            <li key={a.id} className="flex items-center justify-between gap-3 p-3.5">
              <div className="min-w-0">
                <div className="truncate text-sm text-foreground">
                  <span className="font-medium">{a.who}</span> {a.what}
                </div>
              </div>
              <span className="shrink-0 text-xs text-muted-foreground">{a.when}</span>
            </li>
          ))}
        </ul>
      </section>

      <div className="flex flex-col gap-2 sm:flex-row">
        <button
          type="button"
          onClick={() => toast("Güvenlik ayarları MVP-2'de açılacak")}
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent"
        >
          <Shield className="h-4 w-4" /> Güvenlik ayarları
        </button>
        <Sheet open={logoutOpen} onOpenChange={setLogoutOpen}>
          <SheetTrigger asChild>
            <button
              type="button"
              className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium text-danger hover:bg-danger-soft"
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
                  Vazgeç
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
      </div>
    </PageContainer>
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

export const leaveBalances = {
  yillik: { used: 6, total: 20, remaining: 14 },
  mazeret: { used: 3, total: 10, remaining: 7 },
  hastalik: { used: 0, total: 10, remaining: 10 },
  bekleyen: 2,
};

export const expenseSummary = {
  approvedThisMonth: 8640,
  limit: 15000,
  pending: { amount: 2340, count: 2 },
  yearTotal: 34200,
  topCategory: { name: "Seyahat", pct: 41 },
  monthlyAvg: 4900,
};

export const recentActivity = [
  { id: "a1", who: "Ayşe Kaya", what: "izin talebi oluşturdu", when: "2 saat önce" },
  { id: "a2", who: "Murat Tan", what: "masraf bildirdi · ₺840", when: "5 saat önce" },
  { id: "a3", who: "Sistem", what: "Canias bağlantısı yeniden denendi", when: "Dün" },
  { id: "a4", who: "Elif Demir", what: "profil bilgilerini güncelledi", when: "Dün" },
];

export const formatTRY = (n: number) =>
  "₺" + new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(n);
```

## UI/UX Kabul Kriterleri

- Profil kartı: avatar initials, ad, rol, tenant, aktif durum.
- Kişisel bilgiler section: e-posta, departman, pozisyon, tenant, persona.
- Self-HR özeti: izin bakiyesi, bekleyen masraf, performans.
- Son aktiviteler korunmalı.
- Logout sheet gerçek signOut ile uyumlu olmalı; demo-only toast bırakma.

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
rg -n 'Hello "/_app|profil.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/profil`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
