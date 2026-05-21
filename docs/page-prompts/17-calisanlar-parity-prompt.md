# Cursor Prompt — /calisanlar (Çalışanlar Parity)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/calisanlar` ekranını Lovable prototipindeki `calisanlar.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/calisanlar.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/calisanlar`
- Hedef dosya: `src/routes/_app/calisanlar.tsx`
- Navigation: Mevcut `/calisanlar` korunur; manager-only davranış korunur.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/calisanlar.tsx`
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
import { useState } from "react";
import { Users, Search, X, Mail, Building2, Briefcase, UserCheck, CalendarDays } from "lucide-react";
import { PageContainer } from "@/components/puls/AppShell";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { EmptyState } from "@/components/puls/EmptyState";
import { Sheet, SheetContent, SheetTitle, SheetDescription } from "@/components/ui/sheet";
import { VisuallyHidden } from "@radix-ui/react-visually-hidden";
import { employees, departments, positions, type EmployeeStatus } from "@/lib/demo-data";

export const Route = createFileRoute("/calisanlar")({
  head: () => ({ meta: [{ title: "Çalışanlar — PULS" }] }),
  component: CalisanlarPage,
});

const statusMap: Record<EmployeeStatus, { tone: "success" | "warning" | "neutral"; label: string }> = {
  active: { tone: "success", label: "Aktif" },
  onleave: { tone: "warning", label: "İzinli" },
  inactive: { tone: "neutral", label: "Pasif" },
};

function CalisanlarPage() {
  const [dept, setDept] = useState("");
  const [pos, setPos] = useState("");
  const [status, setStatus] = useState("");
  const [q, setQ] = useState("");
  const [selected, setSelected] = useState<(typeof employees)[number] | null>(null);

  const filtered = employees.filter((e) => {
    if (dept && e.department !== dept) return false;
    if (pos && e.position !== pos) return false;
    if (status && e.status !== status) return false;
    if (q && !`${e.name} ${e.email}`.toLowerCase().includes(q.toLowerCase())) return false;
    return true;
  });

  return (
    <PageContainer>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            İK Yönetimi
          </div>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
            Çalışanlar
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {employees.length} çalışan · {departments.length} departman.
          </p>
        </div>
      </div>

      <div className="mt-5 rounded-lg border border-border bg-card p-3">
        <div className="grid gap-2 sm:grid-cols-[1fr_160px_160px_140px]">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <label className="sr-only" htmlFor="emp-q">Çalışan ara</label>
            <input
              id="emp-q"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Çalışan ara…"
              className="h-10 w-full rounded-md border border-border bg-surface-2 pl-9 pr-3 text-[13px] outline-none focus:border-ring focus:bg-card"
            />
          </div>
          <FilterSelect label="Departman" value={dept} onChange={setDept} options={departments.map((d) => d.name)} />
          <FilterSelect label="Pozisyon" value={pos} onChange={setPos} options={positions.map((p) => p.name)} />
          <FilterSelect
            label="Durum"
            value={status}
            onChange={setStatus}
            options={[
              { value: "active", label: "Aktif" },
              { value: "onleave", label: "İzinli" },
              { value: "inactive", label: "Pasif" },
            ]}
          />
        </div>
      </div>

      <section className="mt-6">
        <SectionHeader title="Çalışan listesi" />
        {filtered.length === 0 ? (
          <div className="mt-3 rounded-lg border border-border bg-card">
            <EmptyState icon={Users} title="Eşleşen çalışan bulunamadı" description="Filtreleri sıfırlayarak yeniden dene." />
          </div>
        ) : (
          <div className="mt-3 overflow-hidden rounded-lg border border-border bg-card">
            <div className="hidden grid-cols-[1.5fr_1fr_1fr_120px] gap-3 border-b border-border bg-surface-2 px-4 py-2.5 text-[11px] font-semibold uppercase tracking-[0.04em] text-muted-foreground lg:grid">
              <div>Çalışan</div>
              <div>Departman</div>
              <div>Pozisyon</div>
              <div className="text-right">Durum</div>
            </div>
            <ul className="divide-y divide-border">
              {filtered.map((e) => {
                const s = statusMap[e.status];
                return (
                  <li key={e.id}>
                    <button
                      type="button"
                      onClick={() => setSelected(e)}
                      className="grid w-full grid-cols-[auto_1fr_auto] items-center gap-3 p-4 text-left transition-colors hover:bg-accent/40 lg:grid-cols-[1.5fr_1fr_1fr_120px]"
                    >
                      <div className="flex items-center gap-3 lg:col-span-1">
                        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-[12px] font-semibold text-primary">
                          {e.initials}
                        </span>
                        <div className="min-w-0">
                          <div className="truncate text-[14px] font-medium text-foreground">{e.name}</div>
                          <div className="truncate text-[12px] text-muted-foreground lg:hidden">
                            {e.department} · {e.position}
                          </div>
                          <div className="hidden text-[12px] text-muted-foreground lg:block">{e.email}</div>
                        </div>
                      </div>
                      <div className="hidden text-[13px] text-foreground lg:block">{e.department}</div>
                      <div className="hidden text-[13px] text-foreground lg:block">{e.position}</div>
                      <div className="justify-self-end lg:text-right">
                        <StatusPill tone={s.tone}>{s.label}</StatusPill>
                      </div>
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
        )}
      </section>

      <Sheet open={!!selected} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent side="right" className="w-full p-0 sm:max-w-md">
          <VisuallyHidden>
            <SheetTitle>{selected?.name ?? "Çalışan detayı"}</SheetTitle>
            <SheetDescription>Çalışan detayları</SheetDescription>
          </VisuallyHidden>
          {selected && (
            <div className="flex h-full flex-col">
              <div className="flex items-center gap-3 border-b border-border p-5">
                <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-[14px] font-semibold text-primary">
                  {selected.initials}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[16px] font-semibold text-foreground">{selected.name}</div>
                  <div className="truncate text-[12px] text-muted-foreground">{selected.email}</div>
                </div>
                <button
                  type="button"
                  aria-label="Kapat"
                  onClick={() => setSelected(null)}
                  className="flex h-9 w-9 items-center justify-center rounded-md hover:bg-accent"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
              <div className="flex-1 space-y-5 overflow-y-auto p-5">
                <DetailRow icon={Building2} label="Departman" value={selected.department} />
                <DetailRow icon={Briefcase} label="Pozisyon" value={selected.position} />
                <DetailRow icon={UserCheck} label="Yönetici" value={selected.manager} />
                <DetailRow icon={Mail} label="E-posta" value={selected.email} />
                <DetailRow icon={CalendarDays} label="İşe giriş" value={selected.joined} />

                <div>
                  <div className="text-[12px] font-semibold uppercase tracking-[0.04em] text-muted-foreground">
                    İzin bakiyesi
                  </div>
                  <div className="mt-2 rounded-md border border-border bg-surface-2 p-3">
                    <div className="flex items-baseline justify-between">
                      <div className="text-[14px] font-medium">Yıllık</div>
                      <div className="text-[13px] tabular text-muted-foreground">
                        <span className="font-semibold text-foreground">
                          {selected.leave.total - selected.leave.used}
                        </span>{" "}
                        / {selected.leave.total} gün
                      </div>
                    </div>
                    <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-muted">
                      <div
                        className="h-full rounded-full bg-primary"
                        style={{ width: `${(selected.leave.used / selected.leave.total) * 100}%` }}
                      />
                    </div>
                  </div>
                </div>

                <div>
                  <div className="text-[12px] font-semibold uppercase tracking-[0.04em] text-muted-foreground">
                    Performans kapsamı
                  </div>
                  <div className="mt-2 rounded-md border border-border bg-surface-2 p-3 text-[13px] text-muted-foreground">
                    2026 Q2 dönemi henüz açılmadı. Açıldığında otomatik dahil edilecek.
                  </div>
                </div>

                <div>
                  <div className="text-[12px] font-semibold uppercase tracking-[0.04em] text-muted-foreground">
                    Son aktiviteler
                  </div>
                  <ul className="mt-2 space-y-2 text-[13px] text-foreground">
                    <li className="text-muted-foreground">Henüz aktivite yok.</li>
                  </ul>
                </div>
              </div>
            </div>
          )}
        </SheetContent>
      </Sheet>
    </PageContainer>
  );
}

function DetailRow({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Mail;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-start gap-3">
      <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-neutral-soft text-muted-foreground">
        <Icon className="h-4 w-4" aria-hidden />
      </span>
      <div className="min-w-0 flex-1">
        <div className="text-[11px] font-semibold uppercase tracking-[0.04em] text-muted-foreground">
          {label}
        </div>
        <div className="text-[14px] text-foreground">{value}</div>
      </div>
    </div>
  );
}

type FilterOpt = string | { value: string; label: string };
function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: FilterOpt[];
}) {
  return (
    <label className="block">
      <span className="sr-only">{label}</span>
      <select
        aria-label={label}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-10 w-full rounded-md border border-border bg-surface-2 px-3 text-[13px] outline-none focus:border-ring focus:bg-card"
      >
        <option value="">{label}: Tümü</option>
        {options.map((o) => {
          const v = typeof o === "string" ? o : o.value;
          const l = typeof o === "string" ? o : o.label;
          return (
            <option key={v} value={v}>
              {l}
            </option>
          );
        })}
      </select>
    </label>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
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

export const departments = [
  { id: "d1", name: "Mühendislik", count: 2 },
  { id: "d2", name: "Operasyon", count: 1 },
  { id: "d3", name: "İK & Finans", count: 1 },
];

export const positions = [
  { id: "p1", name: "Saha Mühendisi" },
  { id: "p2", name: "Operasyon Uzmanı" },
  { id: "p3", name: "İK Yöneticisi" },
];
```

## UI/UX Kabul Kriterleri

- Lovable’daki arama ve filtreler eklenmeli: çalışan, departman, pozisyon, durum.
- Çalışan detay Sheet’i eklenmeli: departman, pozisyon, yönetici, e-posta, işe giriş, izin bakiyesi, performans kapsamı.
- Supabase query korunmalı; demo data sadece eksik alanlarda fallback olabilir.
- Manager-only erişim korunmalı.

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

Mevcut `/calisanlar` korunur; manager-only davranış korunur.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|calisanlar.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/calisanlar`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
