# Cursor Prompt — /performans (Performans Parity)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/performans` ekranını Lovable prototipindeki `performans.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/performans.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/performans`
- Hedef dosya: `src/routes/_app/performans.tsx`
- Navigation: Mevcut `/performans` korunur.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/performans.tsx`
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
import { useEffect, useState } from "react";
import { z } from "zod";
import {
  Target,
  Calendar,
  Loader2,
  CheckCircle2,
  X,
  Save,
  Play,
  Users,
  ChevronRight,
} from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { StatusPill } from "@/components/puls/StatusPill";
import { Sheet, SheetTrigger } from "@/components/ui/sheet";
import { SheetShell } from "@/components/puls/SheetShell";
import { FormField, inputCls } from "@/components/puls/FormField";
import { competencyTemplates, tenant } from "@/lib/demo-data";

const SearchSchema = z.object({ configure: z.string().optional() });

export const Route = createFileRoute("/performans")({
  validateSearch: (s) => SearchSchema.parse(s),
  head: () => ({ meta: [{ title: "Performans — PULS" }] }),
  component: PerformansPage,
});

function PerformansPage() {
  const { configure } = Route.useSearch();
  const [open, setOpen] = useState(false);
  const [period, setPeriod] = useState<null | {
    name: string;
    start: string;
    end: string;
    template: string;
  }>(null);

  useEffect(() => {
    if (configure) setOpen(true);
  }, [configure]);

  return (
    <PageContainer>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            Performans
          </div>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
            {period ? `Aktif dönem: ${period.name}` : "Performans"}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {period
              ? `${period.start} → ${period.end} · ${period.template}`
              : "2026 Q2 değerlendirme dönemi henüz açılmadı."}
          </p>
        </div>
        {period ? (
          <StatusPill tone="success">Aktif</StatusPill>
        ) : (
          <StatusPill tone="warning">Dönem açılmadı</StatusPill>
        )}
      </div>

      {period ? (
        <section className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <MetricCard label="Kapsam" value={`${tenant.employees}`} hint="Çalışan" icon={Users} />
          <MetricCard label="Bekleyen" value={tenant.employees} hint="Değerlendirme" />
          <MetricCard label="Tamamlanan" value={0} hint="Bu hafta" />
          <MetricCard label="Geciken" value={0} hint="Son tarih sonrası" />
        </section>
      ) : (
        <section className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <MetricCard label="Aktif dönem" value="—" hint="Henüz başlatılmadı" icon={Calendar} />
          <MetricCard label="Yetkinlik şablonu" value={3} hint="Tanımlı" icon={Target} />
          <MetricCard label="Değerlendiren" value={3} hint="Yönetici" />
          <MetricCard label="Kapsam" value={4} hint="Çalışan" icon={Users} />
        </section>
      )}

      {!period && (
        <div className="mt-8 rounded-lg border border-dashed border-border bg-card p-8 text-center">
          <span className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-primary">
            <Target className="h-6 w-6" aria-hidden />
          </span>
          <h2 className="mt-3 text-base font-semibold text-foreground">Performans dönemi başlat</h2>
          <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
            Şablon, periyot ve değerlendirici akışını seçerek 2026 Q2 dönemini açabilirsin.
            Başlatıldığında çalışanlar otomatik bilgilendirilir.
          </p>
          <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger asChild>
              <button
                type="button"
                className="mt-4 inline-flex h-11 items-center justify-center gap-2 rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              >
                <Play className="h-4 w-4" /> Dönemi yapılandır
              </button>
            </SheetTrigger>
            <PeriodSheet
              onCancel={() => setOpen(false)}
              onLaunch={(p) => {
                setPeriod(p);
                setOpen(false);
                toast.success("Performans dönemi başlatıldı.", {
                  description: `${p.name} · ${tenant.employees} çalışan kapsamda.`,
                });
              }}
            />
          </Sheet>
        </div>
      )}

      <div className="mt-8">
        <SectionHeader title="Yetkinlik şablonları" description="Tanımlı şablonlar." />
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {competencyTemplates.map((t) => (
            <li key={t.id} className="flex items-center gap-3 p-4">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md bg-secondary text-secondary-foreground">
                <Target className="h-[16px] w-[16px]" />
              </span>
              <div className="min-w-0 flex-1">
                <div className="text-[14px] font-medium text-foreground">{t.name}</div>
                <div className="text-[12px] text-muted-foreground">
                  {t.areas} yetkinlik · Güncellenme {t.updated}
                </div>
              </div>
              <StatusPill tone="success">Hazır</StatusPill>
              <ChevronRight className="ml-1 h-4 w-4 text-muted-foreground" aria-hidden />
            </li>
          ))}
        </ul>
      </div>
    </PageContainer>
  );
}

function PeriodSheet({
  onCancel,
  onLaunch,
}: {
  onCancel: () => void;
  onLaunch: (p: { name: string; start: string; end: string; template: string }) => void;
}) {
  const [name, setName] = useState("2026 Q2");
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [template, setTemplate] = useState("Saha Mühendisi");
  const [scope, setScope] = useState("all");
  const [method, setMethod] = useState<string[]>(["yonetici"]);
  const [reminders, setReminders] = useState<string[]>(["baslangic", "son3", "songun"]);
  const [busy, setBusy] = useState<"draft" | "launch" | null>(null);
  const [errors, setErrors] = useState<{ name?: string; start?: string; end?: string }>({});

  function validate() {
    const errs: typeof errors = {};
    if (!name.trim()) errs.name = "Dönem adı gerekli.";
    if (!start) errs.start = "Başlangıç tarihi gerekli.";
    if (!end) errs.end = "Bitiş tarihi gerekli.";
    else if (start && new Date(end) <= new Date(start))
      errs.end = "Bitiş tarihi başlangıçtan sonra olmalı.";
    setErrors(errs);
    return Object.keys(errs).length === 0;
  }

  function handleLaunch(e: React.FormEvent) {
    e.preventDefault();
    if (!validate()) return;
    setBusy("launch");
    setTimeout(() => {
      setBusy(null);
      onLaunch({ name, start, end, template });
    }, 800);
  }

  function handleDraft() {
    if (!validate()) return;
    setBusy("draft");
    setTimeout(() => {
      setBusy(null);
      toast("Taslak kaydedildi", { description: `${name} taslak olarak saklandı.` });
      onCancel();
    }, 600);
  }

  function toggle(list: string[], setList: (v: string[]) => void, v: string) {
    setList(list.includes(v) ? list.filter((x) => x !== v) : [...list, v]);
  }

  return (
    <SheetShell
      title="Performans dönemi oluştur"
      description="Dönem ayarlarını gözden geçir ve başlat."
      footer={
        <>
          <button
            type="button"
            onClick={onCancel}
            className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent"
          >
            <X className="h-4 w-4" /> Vazgeç
          </button>
          <button
            type="button"
            onClick={handleDraft}
            disabled={busy !== null}
            className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent disabled:opacity-60"
          >
            {busy === "draft" ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
            Taslak kaydet
          </button>
          <button
            type="submit"
            form="period-form"
            disabled={busy !== null}
            className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md bg-primary text-sm font-semibold text-primary-foreground disabled:opacity-70"
          >
            {busy === "launch" ? <Loader2 className="h-4 w-4 animate-spin" /> : <Play className="h-4 w-4" />}
            Dönemi başlat
          </button>
        </>
      }
    >
      <form id="period-form" onSubmit={handleLaunch} className="space-y-5">
        <FormField label="Dönem adı" required error={errors.name}>
          {(p) => (
            <input
              {...p}
              value={name}
              onChange={(e) => setName(e.target.value)}
              className={inputCls(!!errors.name)}
              placeholder="Örn. 2026 Q2"
            />
          )}
        </FormField>

        <div className="grid grid-cols-2 gap-3">
          <FormField label="Başlangıç" required error={errors.start}>
            {(p) => (
              <input
                {...p}
                type="date"
                value={start}
                onChange={(e) => setStart(e.target.value)}
                className={inputCls(!!errors.start)}
              />
            )}
          </FormField>
          <FormField label="Bitiş" required error={errors.end}>
            {(p) => (
              <input
                {...p}
                type="date"
                value={end}
                onChange={(e) => setEnd(e.target.value)}
                className={inputCls(!!errors.end)}
              />
            )}
          </FormField>
        </div>

        <FormField label="Yetkinlik şablonu" required>
          {(p) => (
            <select
              {...p}
              value={template}
              onChange={(e) => setTemplate(e.target.value)}
              className={inputCls(false)}
            >
              {competencyTemplates.map((t) => (
                <option key={t.id}>{t.name}</option>
              ))}
            </select>
          )}
        </FormField>

        <FormField label="Kapsam">
          {() => (
            <div className="grid grid-cols-3 gap-2">
              {[
                { id: "all", label: "Tüm çalışanlar" },
                { id: "dept", label: "Departman" },
                { id: "pos", label: "Pozisyon" },
              ].map((o) => (
                <button
                  key={o.id}
                  type="button"
                  onClick={() => setScope(o.id)}
                  aria-pressed={scope === o.id}
                  className={
                    scope === o.id
                      ? "h-11 rounded-md border border-primary bg-primary/10 text-[13px] font-medium text-primary"
                      : "h-11 rounded-md border border-border bg-card text-[13px] text-foreground hover:bg-accent"
                  }
                >
                  {o.label}
                </button>
              ))}
            </div>
          )}
        </FormField>

        <FormField label="Değerlendirme yöntemi" helper="Birden fazla seçilebilir.">
          {() => (
            <div className="space-y-2">
              {[
                { id: "yonetici", label: "Yönetici değerlendirmesi" },
                { id: "oz", label: "Öz değerlendirme" },
                { id: "kalibrasyon", label: "İK kalibrasyonu" },
              ].map((o) => {
                const checked = method.includes(o.id);
                return (
                  <label
                    key={o.id}
                    className="flex cursor-pointer items-center justify-between rounded-md border border-border bg-card px-3 py-2.5 text-[14px] hover:bg-accent/40"
                  >
                    <span>{o.label}</span>
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggle(method, setMethod, o.id)}
                      className="h-4 w-4 rounded border-border accent-[color:var(--primary)]"
                    />
                  </label>
                );
              })}
            </div>
          )}
        </FormField>

        <FormField label="Hatırlatma planı">
          {() => (
            <div className="grid gap-2 sm:grid-cols-3">
              {[
                { id: "baslangic", label: "Başlangıçta" },
                { id: "son3", label: "Son 3 gün" },
                { id: "songun", label: "Son gün" },
              ].map((o) => {
                const checked = reminders.includes(o.id);
                return (
                  <button
                    key={o.id}
                    type="button"
                    aria-pressed={checked}
                    onClick={() => toggle(reminders, setReminders, o.id)}
                    className={
                      checked
                        ? "h-10 rounded-md border border-primary bg-primary/10 text-[13px] font-medium text-primary"
                        : "h-10 rounded-md border border-border bg-card text-[13px] text-foreground hover:bg-accent"
                    }
                  >
                    {o.label}
                  </button>
                );
              })}
            </div>
          )}
        </FormField>

        <div className="rounded-md border border-info/20 bg-info-soft p-3 text-[13px] text-info">
          <div className="flex items-start gap-2">
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
            <div>
              <div className="font-medium">Önizleme</div>
              <div className="opacity-90">
                4 çalışan · 3 yönetici değerlendirici · 1 şablon ({template}).
              </div>
            </div>
          </div>
        </div>
      </form>
    </SheetShell>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const competencyTemplates = [
  { id: "t1", name: "Saha Mühendisi", areas: 6, updated: "12 Nis 2026" },
  { id: "t2", name: "Ofis & Operasyon", areas: 5, updated: "08 Nis 2026" },
  { id: "t3", name: "Yönetici", areas: 7, updated: "01 Mar 2026" },
];

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

- PR #6 performans cycles CRUD korunmalı.
- Lovable’daki dönem oluşturma UX’i SheetShell veya mevcut form akışıyla uyumlu hale getirilmeli.
- Yetkinlik şablonları ve dönem metrikleri eksiksiz olmalı.
- Çalışan modunda create/activate aksiyonları gizlenmeli veya disabled olmalı.

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

Mevcut `/performans` korunur.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|performans.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/performans`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
