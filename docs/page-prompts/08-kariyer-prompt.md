# Cursor Prompt — /kariyer (Kariyer)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/kariyer` ekranını Lovable prototipindeki `kariyer.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/kariyer.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/kariyer`
- Hedef dosya: `src/routes/_app/kariyer.tsx`
- Navigation: İK Yönetimi altında gerçek route. `soon` kaldırılmalı.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/kariyer.tsx`
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
import { GraduationCap, Sparkles, Target, TrendingUp, BookOpen, ArrowRight, Check } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { PageHeader } from "@/components/puls/PageHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { careerLadder, careerGaps, developmentPlan, employees } from "@/lib/demo-data";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/kariyer")({
  head: () => ({
    meta: [
      { title: "Kariyer — PULS" },
      { name: "description", content: "Çalışan gelişim yolu, seviye hedefleri ve yetkinlik boşlukları." },
    ],
  }),
  component: KariyerPage,
});

function KariyerPage() {
  const employee = employees.find((e) => e.name === "Ayşe Kaya")!;
  const [tab, setTab] = useState<"d30" | "d90" | "d180">("d30");

  return (
    <PageContainer>
      <PageHeader
        eyebrow="İK Yönetimi"
        title="Kariyer"
        description="Çalışan gelişim yolunu, seviye hedeflerini ve yetkinlik boşluklarını takip et."
      />

      {/* Employee card */}
      <div className="mb-5 flex flex-col gap-3 rounded-lg border border-border bg-card p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-base font-semibold text-primary">
            {employee.initials}
          </span>
          <div>
            <div className="text-[15px] font-semibold text-foreground">{employee.name}</div>
            <div className="text-xs text-muted-foreground">
              {employee.position} · {employee.department}
            </div>
          </div>
        </div>
        <StatusPill tone="info" icon={Target}>
          Hedef: Takım Lideri
        </StatusPill>
      </div>

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Hazırlık" value="%87" icon={TrendingUp} hint="Hedef role yakınlık" />
        <MetricCard label="Hedef rol" value="Takım Lideri" icon={Target} tone="info" />
        <MetricCard label="Eksik yetkinlik" value="3" icon={GraduationCap} tone="warning" />
        <MetricCard label="Önerilen eğitim" value="2" icon={BookOpen} tone="ai" />
      </div>

      <section className="mb-6">
        <SectionHeader title="Kariyer ladder" description="Saha Mühendisi → Operasyon Müdürü" />
        <div className="mt-3 overflow-hidden rounded-lg border border-border bg-card">
          <ol className="divide-y divide-border">
            {careerLadder.map((step) => (
              <li
                key={step.level}
                className={cn(
                  "flex items-center gap-3 p-4",
                  step.current && "bg-primary/5",
                )}
              >
                <span
                  className={cn(
                    "flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-xs font-semibold tabular",
                    step.achieved && "border-success bg-success-soft text-success",
                    step.current && "border-primary bg-primary text-primary-foreground",
                    !step.achieved && !step.current && "border-border bg-surface-2 text-muted-foreground",
                  )}
                >
                  {step.achieved ? <Check className="h-4 w-4" /> : step.level}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium text-foreground">{step.title}</div>
                  <div className="text-xs text-muted-foreground">
                    {step.achieved
                      ? "Tamamlandı"
                      : step.current
                        ? "Mevcut seviye"
                        : step.target
                          ? "Hedef seviye"
                          : "Sonraki adım"}
                  </div>
                </div>
                {step.target && <StatusPill tone="info">Hedef</StatusPill>}
                {step.current && <StatusPill tone="success">Sen</StatusPill>}
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="mb-6">
        <SectionHeader title="Yetkinlik boşlukları" description="Hedef seviyeye göre eksik alanlar" />
        <div className="mt-3 grid gap-3 sm:grid-cols-3">
          {careerGaps.map((g) => {
            const pct = Math.round((g.current / g.target) * 100);
            return (
              <div key={g.id} className="rounded-lg border border-border bg-card p-4">
                <div className="flex items-baseline justify-between">
                  <div className="text-sm font-medium text-foreground">{g.name}</div>
                  <div className="text-xs tabular text-muted-foreground">
                    {g.current}/{g.target}
                  </div>
                </div>
                <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-neutral-soft">
                  <div
                    className="h-full rounded-full bg-warning"
                    style={{ width: `${pct}%` }}
                    aria-hidden
                  />
                </div>
                <div className="mt-2 text-[11px] text-muted-foreground">Gelişim alanı</div>
              </div>
            );
          })}
        </div>
      </section>

      <section className="mb-6">
        <SectionHeader title="Gelişim planı" description="Zaman ufukları" />
        <div className="mt-3 rounded-lg border border-border bg-card">
          <div className="flex border-b border-border">
            {([
              { id: "d30", label: "30 gün" },
              { id: "d90", label: "90 gün" },
              { id: "d180", label: "6 ay" },
            ] as const).map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => setTab(t.id)}
                className={cn(
                  "min-w-0 flex-1 truncate px-3 py-2.5 text-sm font-medium transition-colors",
                  tab === t.id
                    ? "border-b-2 border-primary text-primary"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {t.label}
              </button>
            ))}
          </div>
          <ul className="divide-y divide-border">
            {developmentPlan[tab].map((item) => (
              <li key={item} className="flex items-center gap-3 px-4 py-3 text-sm">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                  <ArrowRight className="h-3.5 w-3.5" />
                </span>
                <span className="text-foreground">{item}</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <div className="flex flex-col gap-2 sm:flex-row">
        <button
          type="button"
          onClick={() => toast.success("Gelişim planı taslağı oluşturuldu")}
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
        >
          Gelişim planı oluştur
        </button>
        <button
          type="button"
          onClick={() => toast("Eğitim sayfasına yönlendiriliyorsun")}
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card px-4 text-sm font-medium hover:bg-accent"
        >
          Eğitim önerilerini gör
        </button>
        <button
          type="button"
          disabled
          className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-ai/30 bg-ai-soft px-4 text-sm font-medium text-ai opacity-90"
        >
          <Sparkles className="h-4 w-4" /> AI Coach'a sor · Yakında
        </button>
      </div>
    </PageContainer>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const careerLadder = [
  { level: 1, title: "Saha Mühendisi", current: false, achieved: true },
  { level: 2, title: "Kıdemli Saha Mühendisi", current: true, achieved: false },
  { level: 3, title: "Takım Lideri", current: false, achieved: false, target: true },
  { level: 4, title: "Operasyon Müdürü", current: false, achieved: false },
];

export const careerGaps = [
  { id: "g1", name: "Liderlik", current: 2, target: 4 },
  { id: "g2", name: "Raporlama", current: 3, target: 4 },
  { id: "g3", name: "Ekip koordinasyonu", current: 2, target: 4 },
];

export const developmentPlan = {
  d30: [
    "Liderlik temelleri e-eğitimi",
    "Haftalık 1:1'lere katılım",
  ],
  d90: [
    "İlk pilot saha ekibini koordine et",
    "Aylık operasyon raporunu hazırla",
  ],
  d180: [
    "Mentorluk programı tamamla",
    "Takım Lideri yetkinlik değerlendirmesi",
  ],
};

export const employees = [
  {
    id: "u1",
    name: "Demo İK Yöneticisi",
    initials: "DY",
    department: "İK & Finans",
    position: "İK Yöneticisi",
    manager: "—",
    email: "ik@mertteknik.com",
    joined: "12 Oca 2023",
    status: "active" as EmployeeStatus,
    leave: { used: 6, total: 20 },
  },
  {
    id: "u2",
    name: "Ayşe Kaya",
    initials: "AK",
    department: "Mühendislik",
    position: "Saha Mühendisi",
    manager: "Murat Tan",
    email: "ayse.kaya@mertteknik.com",
    joined: "04 Mar 2024",
    status: "onleave" as EmployeeStatus,
    leave: { used: 8, total: 14 },
  },
  {
    id: "u3",
    name: "Murat Tan",
    initials: "MT",
    department: "Mühendislik",
    position: "Saha Mühendisi",
    manager: "Demo İK Yöneticisi",
    email: "murat.tan@mertteknik.com",
    joined: "18 Eyl 2022",
    status: "active" as EmployeeStatus,
    leave: { used: 4, total: 18 },
  },
  {
    id: "u4",
    name: "Elif Demir",
    initials: "ED",
    department: "Operasyon",
    position: "Operasyon Uzmanı",
    manager: "Demo İK Yöneticisi",
    email: "elif.demir@mertteknik.com",
    joined: "01 Şub 2025",
    status: "active" as EmployeeStatus,
    leave: { used: 2, total: 14 },
  },
];
```

## UI/UX Kabul Kriterleri

- Ayşe Kaya odaklı çalışan kartı, hedef rol pill’i ve metrikler korunmalı.
- Kariyer ladder: achieved/current/target durumları görsel olarak ayrışmalı.
- Yetkinlik boşlukları progress bar ile gösterilmeli.
- 30/90/180 gün gelişim planı sekmeleri çalışmalı.
- AI Coach CTA aktif chat açmamalı; Yakında/disabled kalmalı.

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
rg -n 'Hello "/_app|kariyer.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/kariyer`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
