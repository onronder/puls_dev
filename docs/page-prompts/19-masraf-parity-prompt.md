# Cursor Prompt — /masraf (Masraf Parity)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/masraf` ekranını Lovable prototipindeki `masraf.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/masraf.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/masraf`
- Hedef dosya: `src/routes/_app/masraf.tsx`
- Navigation: Mevcut `/masraf` korunur.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/masraf.tsx`
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
import { z } from "zod";
import {
  Plus,
  AlertTriangle,
  Loader2,
  CheckCircle2,
  Sparkles,
  FileUp,
  X,
  Receipt,
  Check,
  Info,
} from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { StatusPill } from "@/components/puls/StatusPill";
import { Segmented } from "@/components/puls/Segmented";
import { FormField, inputCls } from "@/components/puls/FormField";
import { SheetShell } from "@/components/puls/SheetShell";
import { Sheet, SheetTrigger } from "@/components/ui/sheet";
import {
  expenseHistory,
  expenseSummary,
  formatTRY,
  expenseCategories,
  pendingExpenseApprovals,
} from "@/lib/demo-data";

const Search = z.object({ tab: z.enum(["mine", "approvals", "cats"]).optional() });

export const Route = createFileRoute("/masraf")({
  validateSearch: (s) => Search.parse(s),
  head: () => ({ meta: [{ title: "Masraf — PULS" }] }),
  component: MasrafPage,
});

function MasrafPage() {
  const initial = Route.useSearch().tab ?? "mine";
  const [tab, setTab] = useState<"mine" | "approvals" | "cats">(initial);
  const [open, setOpen] = useState(false);
  const usedPct = Math.round((expenseSummary.approvedThisMonth / expenseSummary.limit) * 100);

  return (
    <PageContainer>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            İK Süreçleri
          </div>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
            Masraf
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Aylık limit, bekleyen kalemler ve kategoriler tek ekranda.
          </p>
        </div>
        <Sheet open={open} onOpenChange={setOpen}>
          <SheetTrigger asChild>
            <button
              type="button"
              className="inline-flex h-11 items-center gap-2 rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground shadow-sm hover:bg-primary/90"
            >
              <Plus className="h-4 w-4" /> Yeni masraf
            </button>
          </SheetTrigger>
          <ExpenseFormSheet onDone={() => setOpen(false)} />
        </Sheet>
      </div>

      {/* Limit card */}
      <div className="mt-5 rounded-lg border border-border bg-card p-5">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <div>
            <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
              Bu ay onaylanan
            </div>
            <div className="mt-1 flex items-baseline gap-2">
              <span className="text-[30px] font-semibold tracking-tight tabular text-foreground sm:text-[34px]">
                {formatTRY(expenseSummary.approvedThisMonth)}
              </span>
              <span className="text-[14px] text-muted-foreground">
                / {formatTRY(expenseSummary.limit)}
              </span>
            </div>
          </div>
          <StatusPill tone={usedPct > 80 ? "warning" : "success"}>
            %{usedPct} kullanıldı
          </StatusPill>
        </div>
        <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-muted">
          <div
            className={usedPct > 80 ? "h-full rounded-full bg-warning" : "h-full rounded-full bg-primary"}
            style={{ width: `${usedPct}%` }}
          />
        </div>
      </div>

      <section className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4" aria-label="Masraf özet">
        <MetricCard
          label="Bekleyen"
          value={formatTRY(expenseSummary.pending.amount)}
          hint={`${expenseSummary.pending.count} kalem`}
          tone="warning"
        />
        <MetricCard label="Yıl toplamı" value={formatTRY(expenseSummary.yearTotal)} hint="Onaylanan" />
        <MetricCard
          label="En büyük kategori"
          value={<span className="text-[18px]">{expenseSummary.topCategory.name}</span>}
          hint={`%${expenseSummary.topCategory.pct} pay`}
        />
        <MetricCard label="Ortalama / ay" value={formatTRY(expenseSummary.monthlyAvg)} hint="Son 6 ay" />
      </section>

      <div className="mt-6">
        <Segmented
          ariaLabel="Masraf sekmeleri"
          value={tab}
          onChange={setTab}
          options={[
            { value: "mine", label: "Benim masraflarım", count: expenseHistory.length },
            { value: "approvals", label: "Onay bekleyenler", count: pendingExpenseApprovals.length },
            { value: "cats", label: "Kategoriler" },
          ]}
        />
      </div>

      {tab === "mine" && (
        <section className="mt-6">
          <SectionHeader title="Son masraflar" />
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {expenseHistory.map((e) => (
              <li key={e.id} className="flex items-center gap-3 p-4">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-secondary text-secondary-foreground">
                  <Receipt className="h-[18px] w-[18px]" />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-foreground">{e.title}</div>
                  <div className="text-[12px] text-muted-foreground">
                    {e.category} · {e.date}
                  </div>
                </div>
                <div className="flex w-[110px] shrink-0 flex-col items-end gap-1">
                  <div className="text-[14px] font-semibold tabular text-foreground">
                    {formatTRY(e.amount)}
                  </div>
                  {e.status === "approved" ? (
                    <StatusPill tone="success">Onaylandı</StatusPill>
                  ) : (
                    <StatusPill tone="warning">Bekliyor</StatusPill>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {tab === "approvals" && (
        <section className="mt-6">
          <SectionHeader title="Onay bekleyen masraflar" />
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {pendingExpenseApprovals.map((p) => (
              <li key={p.id} className="flex flex-wrap items-center gap-3 p-4">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-secondary text-[12px] font-semibold text-secondary-foreground">
                  {p.initials}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-foreground">
                    {p.who} · {p.title}
                  </div>
                  <div className="text-[12px] text-muted-foreground">
                    {p.category} · {p.date}
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-[14px] font-semibold tabular text-foreground">
                    {formatTRY(p.amount)}
                  </div>
                </div>
                <div className="flex w-full items-center gap-2 sm:w-auto">
                  <button
                    type="button"
                    onClick={() => toast.error("Reddedildi", { description: p.title })}
                    className="inline-flex h-9 flex-1 items-center justify-center gap-1 rounded-md border border-border bg-card px-3 text-[13px] font-medium hover:bg-accent sm:flex-none"
                  >
                    <X className="h-3.5 w-3.5" /> Reddet
                  </button>
                  <button
                    type="button"
                    onClick={() => toast.success("Onaylandı", { description: p.title })}
                    className="inline-flex h-9 flex-1 items-center justify-center gap-1 rounded-md bg-primary px-3 text-[13px] font-semibold text-primary-foreground hover:bg-primary/90 sm:flex-none"
                  >
                    <Check className="h-3.5 w-3.5" /> Onayla
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {tab === "cats" && (
        <section className="mt-6">
          <SectionHeader title="Kategori limitleri" description="Bu ay kullanım oranı." />
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {expenseCategories.map((c) => {
              const pct = c.limit ? Math.round((c.monthSpent / c.limit) * 100) : 0;
              return (
                <li key={c.name} className="p-4">
                  <div className="flex items-baseline justify-between gap-3">
                    <div className="text-[14px] font-medium text-foreground">{c.name}</div>
                    <div className="text-[13px] tabular text-muted-foreground">
                      <span className="font-semibold text-foreground">{formatTRY(c.monthSpent)}</span> /{" "}
                      {formatTRY(c.limit)}
                    </div>
                  </div>
                  <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-muted">
                    <div
                      className={
                        pct > 80
                          ? "h-full rounded-full bg-warning"
                          : "h-full rounded-full bg-primary"
                      }
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        </section>
      )}
    </PageContainer>
  );
}

function ExpenseFormSheet({ onDone }: { onDone: () => void }) {
  const [category, setCategory] = useState("");
  const [amount, setAmount] = useState("");
  const [currency, setCurrency] = useState("TRY");
  const [vatIncluded, setVatIncluded] = useState(true);
  const [date, setDate] = useState("");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [errors, setErrors] = useState<{ category?: string; amount?: string; date?: string }>({});

  const amountNum = Number(amount) || 0;
  const overPolicy = amountNum > 2000;
  const requiredOk = !!category && amountNum > 0 && !!date;

  function submit(e: React.FormEvent) {
    e.preventDefault();
    const errs: typeof errors = {};
    if (!category) errs.category = "Kategori seçilmeli.";
    if (!amount) errs.amount = "Tutar gerekli.";
    else if (amountNum <= 0) errs.amount = "Tutar 0'dan büyük olmalı.";
    if (!date) errs.date = "Tarih gerekli.";
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setSubmitting(true);
    setTimeout(() => {
      setSubmitting(false);
      toast.success("Masraf bildirimin onaya gönderildi.", {
        description: `${formatTRY(amountNum)} · ${category}.`,
      });
      onDone();
    }, 700);
  }

  return (
    <SheetShell
      title="Yeni masraf bildir"
      description="Kalem onaya gönderildiğinde yöneticine iletilir."
      footer={
        <>
          <button
            type="button"
            onClick={onDone}
            className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md border border-border bg-card text-sm font-medium hover:bg-accent"
          >
            <X className="h-4 w-4" /> İptal
          </button>
          <button
            type="submit"
            form="expense-form"
            disabled={submitting}
            className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md bg-primary text-sm font-semibold text-primary-foreground disabled:opacity-70"
          >
            {submitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" /> Gönderiliyor…
              </>
            ) : (
              <>
                <Receipt className="h-4 w-4" /> Bildir
              </>
            )}
          </button>
        </>
      }
    >
      <form id="expense-form" onSubmit={submit} className="space-y-5">
        <div className="rounded-md border border-ai/20 bg-ai-soft p-3">
          <div className="flex items-start gap-2">
            <span className="flex h-7 w-7 items-center justify-center rounded-md bg-ai/15 text-ai">
              <Sparkles className="h-3.5 w-3.5" />
            </span>
            <div className="flex-1">
              <div className="flex items-center gap-1.5 text-[13.5px] font-medium text-ai">
                Fiş okuma (OCR)
                <span className="rounded-full bg-ai/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase">
                  Yakında
                </span>
              </div>
              <p className="mt-0.5 text-[12px] text-ai/80">
                Fişin fotoğrafından kategori ve tutarı otomatik dolduracağız.
              </p>
            </div>
          </div>
        </div>

        <FormField label="Kategori" required error={errors.category}>
          {(p) => (
            <select
              {...p}
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className={inputCls(!!errors.category)}
            >
              <option value="">Seçim yapın…</option>
              {expenseCategories.map((c) => (
                <option key={c.name}>{c.name}</option>
              ))}
            </select>
          )}
        </FormField>

        <div className="grid grid-cols-[1fr_110px] gap-3">
          <FormField label="Tutar" required error={errors.amount}>
            {(p) => (
              <input
                {...p}
                type="number"
                inputMode="decimal"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className={inputCls(!!errors.amount) + " tabular"}
                placeholder="0,00"
              />
            )}
          </FormField>
          <FormField label="Para birimi">
            {(p) => (
              <select
                {...p}
                value={currency}
                onChange={(e) => setCurrency(e.target.value)}
                className={inputCls(false)}
              >
                <option>TRY</option>
                <option>USD</option>
                <option>EUR</option>
              </select>
            )}
          </FormField>
        </div>

        <label className="flex cursor-pointer items-center justify-between rounded-md border border-border bg-surface-2 px-4 py-3">
          <div>
            <div className="text-[14px] font-medium">KDV dahil</div>
            <div className="text-[12px] text-muted-foreground">
              Tutar KDV'yi içeriyorsa açık bırak.
            </div>
          </div>
          <input
            type="checkbox"
            checked={vatIncluded}
            onChange={(e) => setVatIncluded(e.target.checked)}
            className="h-5 w-5 rounded border-border accent-[color:var(--primary)]"
          />
        </label>

        <FormField label="Tarih" required error={errors.date}>
          {(p) => (
            <input
              {...p}
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className={inputCls(!!errors.date)}
            />
          )}
        </FormField>

        <FormField label="Açıklama">
          {(p) => (
            <textarea
              {...p}
              rows={2}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className={inputCls(false) + " h-auto min-h-[72px] py-2"}
              placeholder="Örn. Ankara müşteri ziyareti"
            />
          )}
        </FormField>

        <FormField label="Fiş / belge" helper="JPG, PNG veya PDF · opsiyonel">
          {() => (
            <button
              type="button"
              className="flex h-auto min-h-[80px] w-full items-center justify-center gap-2 rounded-md border border-dashed border-border bg-surface-2 px-4 py-4 text-[13px] text-muted-foreground hover:bg-accent"
            >
              <FileUp className="h-4 w-4" /> Belge yükle
            </button>
          )}
        </FormField>

        {requiredOk && (
          <div className="rounded-md border border-border bg-surface-2 p-3">
            <div className="text-[12px] font-semibold uppercase tracking-[0.04em] text-muted-foreground">
              Politika kontrolü
            </div>
            <ul className="mt-2 space-y-1.5 text-[13px]">
              <PolicyLine ok={!overPolicy} label={`Kategori limiti · ${category}`} />
              <PolicyLine ok={!overPolicy} label="Fiş zorunluluğu (₺2.000 üzeri)" />
              <PolicyLine ok={currency === "TRY"} label="Para birimi · TRY tercih edilir" />
              <PolicyLine ok={true} label={`Tarih · ${date}`} />
            </ul>
          </div>
        )}

        {!requiredOk ? (
          <div className="flex items-start gap-2 rounded-md border border-border bg-surface-2 p-3 text-[13px] text-muted-foreground">
            <Info className="mt-0.5 h-4 w-4 shrink-0" />
            <div className="text-[12px]">
              Zorunlu alanları doldurduktan sonra politika kontrolü görüntülenecek.
            </div>
          </div>
        ) : overPolicy ? (
          <div className="flex items-start gap-2 rounded-md border border-warning/30 bg-warning-soft p-3 text-[13px] text-warning">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            <div>
              <div className="font-medium">Politika uyarısı</div>
              <div className="text-[12px] opacity-90">
                ₺2.000 üzeri kalemler için fiş zorunlu ve ek onay gerekir.
              </div>
            </div>
          </div>
        ) : (
          <div className="flex items-start gap-2 rounded-md border border-info/20 bg-info-soft p-3 text-[13px] text-info">
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
            <div className="text-[12px]">Kalem mevcut harcama politikasıyla uyumlu görünüyor.</div>
          </div>
        )}
      </form>
    </SheetShell>
  );
}

function PolicyLine({ ok, label }: { ok: boolean; label: string }) {
  return (
    <li className="flex items-center gap-2 text-foreground">
      {ok ? (
        <CheckCircle2 className="h-3.5 w-3.5 text-success" aria-hidden />
      ) : (
        <AlertTriangle className="h-3.5 w-3.5 text-warning" aria-hidden />
      )}
      <span className={ok ? "text-foreground" : "text-warning"}>{label}</span>
    </li>
  );
}
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const expenseHistory = [
  { id: "e1", category: "Seyahat", title: "Ankara müşteri ziyareti", amount: 1840, date: "08 May", status: "approved" as const },
  { id: "e2", category: "Yemek", title: "Ekip akşam yemeği", amount: 620, date: "06 May", status: "approved" as const },
  { id: "e3", category: "Yazılım", title: "Figma yıllık", amount: 1500, date: "03 May", status: "pending" as const },
  { id: "e4", category: "Ulaşım", title: "Taksi · havaalanı", amount: 240, date: "01 May", status: "pending" as const },
  { id: "e5", category: "Konaklama", title: "Otel · İzmir", amount: 3200, date: "28 Nis", status: "approved" as const },
];

export const expenseSummary = {
  approvedThisMonth: 8640,
  limit: 15000,
  pending: { amount: 2340, count: 2 },
  yearTotal: 34200,
  topCategory: { name: "Seyahat", pct: 41 },
  monthlyAvg: 4900,
};

export const formatTRY = (n: number) =>
  "₺" + new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(n);

export const expenseCategories = [
  { name: "Seyahat", limit: 5000, monthSpent: 3400 },
  { name: "Yemek", limit: 2000, monthSpent: 820 },
  { name: "Konaklama", limit: 6000, monthSpent: 3200 },
  { name: "Yazılım", limit: 3000, monthSpent: 1500 },
  { name: "Ulaşım", limit: 1500, monthSpent: 720 },
  { name: "Diğer", limit: 1000, monthSpent: 0 },
];

export const pendingExpenseApprovals = [
  { id: "pe1", who: "Ayşe Kaya", initials: "AK", title: "Figma yıllık", category: "Yazılım", amount: 1500, date: "03 May" },
  { id: "pe2", who: "Murat Tan", initials: "MT", title: "Taksi · havaalanı", category: "Ulaşım", amount: 240, date: "01 May" },
];
```

## UI/UX Kabul Kriterleri

- Lovable’daki segmented tabs eklenmeli: Benim masraflarım, Onay bekleyenler, Kategoriler.
- Limit kartı, metrikler, son masraflar, onay bekleyen masraflar, kategori limitleri korunmalı.
- Masraf formu ve comma decimal parse korunmalı.
- Locale-aware currency format korunmalı.
- Receipt upload alanı placeholder/teaser kalabilir.

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

Mevcut `/masraf` korunur.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|masraf.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/masraf`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
