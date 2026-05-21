# Cursor Prompt — /izin (İzin Parity)

Bu prompt tek ekran içindir. Başka route veya modül düzenleme.

## Hedef

Ana PULS uygulamasında `/izin` ekranını Lovable prototipindeki `izin.tsx` ekranına UI/UX ve içerik olarak mümkün olduğunca yaklaştır.

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
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/izin.tsx
```

Lovable demo-data kaynağı:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu hedefe odaklan:

- Hedef route: `/izin`
- Hedef dosya: `src/routes/_app/izin.tsx`
- Navigation: Mevcut `/izin` korunur.

Gerekirse şu dosyalara dokunabilirsin:

- `src/routes/_app/izin.tsx`
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
  CalendarDays,
  CalendarPlus,
  AlertTriangle,
  Loader2,
  CheckCircle2,
  X,
  FileUp,
  Inbox,
  Check,
} from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { MetricCard } from "@/components/puls/MetricCard";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { leaveStatusPill, StatusPill } from "@/components/puls/StatusPill";
import { Segmented } from "@/components/puls/Segmented";
import { EmptyState } from "@/components/puls/EmptyState";
import { FormField, inputCls } from "@/components/puls/FormField";
import { SheetShell } from "@/components/puls/SheetShell";
import { Sheet, SheetTrigger } from "@/components/ui/sheet";
import {
  leaveBalances,
  leaveHistory,
  upcomingLeave,
  leaveTypes,
  pendingLeaveApprovals,
  employees,
} from "@/lib/demo-data";

const Search = z.object({ tab: z.enum(["mine", "approvals", "calendar"]).optional() });

export const Route = createFileRoute("/izin")({
  validateSearch: (s) => Search.parse(s),
  head: () => ({ meta: [{ title: "İzin — PULS" }] }),
  component: IzinPage,
});

function IzinPage() {
  const initial = Route.useSearch().tab ?? "mine";
  const [tab, setTab] = useState<"mine" | "approvals" | "calendar">(initial);
  const [open, setOpen] = useState(false);

  return (
    <PageContainer>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            İK Süreçleri
          </div>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
            İzin
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Bakiyeni takip et, yeni talep oluştur ve onayları yönet.
          </p>
        </div>
        <Sheet open={open} onOpenChange={setOpen}>
          <SheetTrigger asChild>
            <button
              type="button"
              className="inline-flex h-11 min-w-[44px] items-center gap-2 rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground shadow-sm hover:bg-primary/90"
            >
              <Plus className="h-4 w-4" /> Yeni izin talebi
            </button>
          </SheetTrigger>
          <LeaveFormSheet onDone={() => setOpen(false)} />
        </Sheet>
      </div>

      <section className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4" aria-label="İzin bakiyeleri">
        <BalanceCard label="Yıllık" used={leaveBalances.yillik.used} total={leaveBalances.yillik.total} />
        <BalanceCard label="Mazeret" used={leaveBalances.mazeret.used} total={leaveBalances.mazeret.total} />
        <BalanceCard label="Hastalık" used={leaveBalances.hastalik.used} total={leaveBalances.hastalik.total} />
        <MetricCard label="Bekleyen" value={leaveBalances.bekleyen} hint="onay sürecinde" tone="warning" />
      </section>

      <div className="mt-6">
        <Segmented
          ariaLabel="İzin sekmeleri"
          value={tab}
          onChange={setTab}
          options={[
            { value: "mine", label: "Benim izinlerim", count: leaveHistory.length },
            { value: "approvals", label: "Onay bekleyenler", count: pendingLeaveApprovals.length },
            { value: "calendar", label: "Takvim" },
          ]}
        />
      </div>

      {tab === "mine" && (
        <>
          <section className="mt-6">
            <SectionHeader title="Yaklaşan izinler" description="Önümüzdeki 30 gün." />
            <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
              {upcomingLeave.map((u) => (
                <li key={u.id} className="flex items-center gap-3 p-4">
                  <div className="flex h-12 w-12 shrink-0 flex-col items-center justify-center rounded-md border border-border bg-surface-2 text-center">
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                      {u.date.split(" ").slice(-1)[0]}
                    </span>
                    <span className="text-[14px] font-semibold tabular text-foreground">
                      {u.date.split(" ")[0]}
                    </span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-medium text-foreground">
                      {u.who} · {u.type}
                    </div>
                    <div className="text-[12px] text-muted-foreground">
                      {u.date} · {u.days} gün
                    </div>
                  </div>
                  {leaveStatusPill(u.status)}
                </li>
              ))}
            </ul>
          </section>

          <section className="mt-8">
            <SectionHeader title="İzin geçmişi" />
            <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
              {leaveHistory.map((l) => (
                <li key={l.id} className="flex items-center gap-3 p-4">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-secondary text-secondary-foreground">
                    <CalendarDays className="h-4 w-4" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="text-[14px] font-medium text-foreground">
                      {l.type} · <span className="tabular">{l.days} gün</span>
                    </div>
                    <div className="text-[12px] text-muted-foreground">
                      {l.start} → {l.end}
                    </div>
                  </div>
                  {leaveStatusPill(l.status)}
                </li>
              ))}
            </ul>
          </section>
        </>
      )}

      {tab === "approvals" && (
        <section className="mt-6">
          <SectionHeader
            title="Onay bekleyen talepler"
            description={`${pendingLeaveApprovals.length} talep onayını bekliyor.`}
          />
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {pendingLeaveApprovals.map((a) => (
              <li key={a.id} className="flex flex-wrap items-center gap-3 p-4">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-secondary text-[12px] font-semibold text-secondary-foreground">
                  {a.initials}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-foreground">
                    {a.who} · {a.type}
                  </div>
                  <div className="text-[12px] text-muted-foreground">
                    {a.date} · <span className="tabular">{a.days}</span> gün
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => toast.error("Reddedildi", { description: a.who })}
                    className="inline-flex h-9 items-center justify-center gap-1 rounded-md border border-border bg-card px-3 text-[13px] font-medium hover:bg-accent"
                  >
                    <X className="h-3.5 w-3.5" /> Reddet
                  </button>
                  <button
                    type="button"
                    onClick={() => toast.success("Onaylandı", { description: a.who })}
                    className="inline-flex h-9 items-center justify-center gap-1 rounded-md bg-primary px-3 text-[13px] font-semibold text-primary-foreground hover:bg-primary/90"
                  >
                    <Check className="h-3.5 w-3.5" /> Onayla
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {tab === "calendar" && (
        <section className="mt-6 rounded-lg border border-border bg-card">
          <EmptyState
            icon={Inbox}
            title="Takvim görünümü yakında"
            description="Ekip takvimi, çakışma uyarıları ve ay/hafta görünümü hazırlanıyor."
          />
        </section>
      )}
    </PageContainer>
  );
}

function BalanceCard({ label, used, total }: { label: string; used: number; total: number }) {
  const remaining = total - used;
  const pct = total > 0 ? Math.round((used / total) * 100) : 0;
  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
        {label}
      </div>
      <div className="mt-2 flex items-baseline gap-1.5">
        <span className="text-[26px] font-semibold leading-none tabular text-foreground">
          {remaining}
        </span>
        <span className="text-[12px] text-muted-foreground">/ {total} gün</span>
      </div>
      <div className="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-muted">
        <div className="h-full rounded-full bg-primary" style={{ width: `${pct}%` }} />
      </div>
      <div className="mt-1.5 text-[11px] text-muted-foreground">
        <span className="tabular">{used}</span> kullanıldı
      </div>
    </div>
  );
}

function LeaveFormSheet({ onDone }: { onDone: () => void }) {
  const [type, setType] = useState("yillik");
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [halfDay, setHalfDay] = useState(false);
  const [substitute, setSubstitute] = useState("");
  const [approver, setApprover] = useState("Demo İK Yöneticisi");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [errors, setErrors] = useState<{ start?: string; end?: string }>({});

  const days = (() => {
    if (!start || !end) return 0;
    const s = new Date(start);
    const e = new Date(end);
    const diff = Math.max(0, Math.round((e.getTime() - s.getTime()) / 86400000) + 1);
    return halfDay ? Math.max(0.5, diff - 0.5) : diff;
  })();

  const remainingAfter = leaveBalances.yillik.remaining - (type === "yillik" ? days : 0);
  const teamConflict =
    upcomingLeave.length > 0 && start && new Date(start).getMonth() === 5; // crude demo flag

  function submit(e: React.FormEvent) {
    e.preventDefault();
    const errs: typeof errors = {};
    if (!start) errs.start = "Başlangıç tarihi gerekli.";
    if (!end) errs.end = "Bitiş tarihi gerekli.";
    else if (start && new Date(end) < new Date(start))
      errs.end = "Bitiş, başlangıçtan önce olamaz.";
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setSubmitting(true);
    setTimeout(() => {
      setSubmitting(false);
      toast.success("İzin talebin yöneticine iletildi.", {
        description: `${days} gün · onay sürecinde.`,
      });
      onDone();
    }, 700);
  }

  return (
    <SheetShell
      title="Yeni izin talebi"
      description="Form gönderildiğinde yöneticine iletilir."
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
            form="leave-form"
            disabled={submitting}
            className="inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-md bg-primary text-sm font-semibold text-primary-foreground disabled:opacity-70"
          >
            {submitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" /> Gönderiliyor…
              </>
            ) : (
              <>
                <CalendarPlus className="h-4 w-4" /> Talebi gönder
              </>
            )}
          </button>
        </>
      }
    >
      <form id="leave-form" onSubmit={submit} className="space-y-5">
        <FormField label="İzin türü" required>
          {() => (
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
              {leaveTypes.map((t) => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => setType(t.id)}
                  aria-pressed={type === t.id}
                  className={
                    type === t.id
                      ? "h-11 rounded-md border border-primary bg-primary/10 text-[13px] font-medium text-primary"
                      : "h-11 rounded-md border border-border bg-card text-[13px] text-foreground hover:bg-accent"
                  }
                >
                  {t.label}
                </button>
              ))}
            </div>
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

        <div className="flex items-center justify-between rounded-md border border-border bg-surface-2 px-4 py-3">
          <div>
            <div className="text-[14px] font-medium">
              Toplam <span className="tabular">{days || 0}</span> gün
            </div>
            <div className="text-[12px] text-muted-foreground">
              Resmi tatil ve hafta sonu hariç hesaplanır.
            </div>
          </div>
          <label className="flex cursor-pointer items-center gap-2 text-[13px]">
            <input
              type="checkbox"
              checked={halfDay}
              onChange={(e) => setHalfDay(e.target.checked)}
              className="h-4 w-4 rounded border-border accent-[color:var(--primary)]"
            />
            Yarım gün
          </label>
        </div>

        <FormField label="Vekil çalışan" helper="İzin süresince işlerini yürütecek kişi.">
          {(p) => (
            <select
              {...p}
              value={substitute}
              onChange={(e) => setSubstitute(e.target.value)}
              className={inputCls(false)}
            >
              <option value="">Seçim yapın…</option>
              {employees.filter((e) => e.name !== "Demo İK Yöneticisi").map((e) => (
                <option key={e.id}>{e.name}</option>
              ))}
            </select>
          )}
        </FormField>

        <FormField label="Onaycı" helper="Talep bu kişiye iletilir.">
          {(p) => (
            <select
              {...p}
              value={approver}
              onChange={(e) => setApprover(e.target.value)}
              className={inputCls(false)}
            >
              <option>Demo İK Yöneticisi</option>
              <option>Murat Tan</option>
            </select>
          )}
        </FormField>

        <FormField label="Açıklama" helper="Yöneticinin onay sırasında göreceği not.">
          {(p) => (
            <textarea
              {...p}
              rows={3}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className={inputCls(false) + " h-auto min-h-[88px] py-2"}
              placeholder="Kısa bir açıklama yazabilirsin"
            />
          )}
        </FormField>

        <FormField label="Belge" helper="PDF veya görsel · opsiyonel">
          {() => (
            <button
              type="button"
              className="flex h-auto min-h-[80px] w-full items-center justify-center gap-2 rounded-md border border-dashed border-border bg-surface-2 px-4 py-4 text-[13px] text-muted-foreground hover:bg-accent"
            >
              <FileUp className="h-4 w-4" /> Dosya seç veya sürükle bırak
            </button>
          )}
        </FormField>

        {teamConflict ? (
          <div className="flex items-start gap-2 rounded-md border border-warning/30 bg-warning-soft p-3 text-[13px] text-warning">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            <div>
              <div className="font-medium">Ekip izin çakışması</div>
              <div className="text-[12px] opacity-90">
                Aynı tarihlerde Ayşe K. izinli. Vekil ataması yapmanı öneririz.
              </div>
            </div>
          </div>
        ) : null}

        <div
          className={
            remainingAfter < 0
              ? "flex items-start gap-2 rounded-md border border-danger/20 bg-danger-soft p-3 text-[13px] text-danger"
              : "flex items-start gap-2 rounded-md border border-info/20 bg-info-soft p-3 text-[13px] text-info"
          }
        >
          {remainingAfter < 0 ? (
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          ) : (
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
          )}
          <div className="flex-1">
            <div className="font-medium">Talep özeti</div>
            <div className="text-[12px] opacity-90">
              {days || 0} gün · {leaveTypes.find((t) => t.id === type)?.label} · Bakiye sonrası{" "}
              <span className="tabular font-semibold">{remainingAfter}</span> gün.
            </div>
          </div>
        </div>
      </form>
    </SheetShell>
  );
}

export { StatusPill };
```

## Lovable Demo Data Parçaları

Bu veri route içine gömülmemeli. Ana projede gerekiyorsa `src/lib/demo/puls-demo-data.ts` içinde izole adapter/export olarak tutulmalı.

```ts
export const leaveBalances = {
  yillik: { used: 6, total: 20, remaining: 14 },
  mazeret: { used: 3, total: 10, remaining: 7 },
  hastalik: { used: 0, total: 10, remaining: 10 },
  bekleyen: 2,
};

export const leaveHistory = [
  { id: "l1", type: "Yıllık", start: "12 May 2026", end: "14 May 2026", days: 3, status: "approved" as const },
  { id: "l2", type: "Mazeret", start: "28 Nis 2026", end: "28 Nis 2026", days: 1, status: "approved" as const },
  { id: "l3", type: "Yıllık", start: "02 Haz 2026", end: "06 Haz 2026", days: 5, status: "pending" as const },
  { id: "l4", type: "Yıllık", start: "20 Mar 2026", end: "22 Mar 2026", days: 3, status: "rejected" as const },
];

export const upcomingLeave = [
  { id: "u1", who: "Sen", type: "Yıllık izin", date: "02 – 06 Haz", days: 5, status: "pending" as const },
  { id: "u2", who: "Ayşe K.", type: "Mazeret", date: "25 May", days: 1, status: "approved" as const },
  { id: "u3", who: "Murat T.", type: "Yıllık", date: "10 – 12 Haz", days: 3, status: "approved" as const },
];

export const leaveTypes = [
  { id: "yillik", label: "Yıllık" },
  { id: "mazeret", label: "Mazeret" },
  { id: "hastalik", label: "Hastalık" },
  { id: "ucretsiz", label: "Ücretsiz" },
  { id: "idari", label: "İdari" },
  { id: "evlilik", label: "Evlilik" },
  { id: "dogum", label: "Doğum/Babalık" },
  { id: "olum", label: "Ölüm" },
];

export const pendingLeaveApprovals = [
  { id: "pl1", who: "Ayşe Kaya", initials: "AK", type: "Yıllık", date: "02 – 06 Haz", days: 5 },
  { id: "pl2", who: "Murat Tan", initials: "MT", type: "Mazeret", date: "28 May", days: 1 },
];

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

- Mevcut hotfix ile gelen gerçek ekran korunmalı; stub’a dönmemeli.
- Lovable’daki segmented tabs eklenmeli: Benim izinlerim, Onay bekleyenler, Takvim.
- Yaklaşan izinler ve izin geçmişi ayrı section olmalı.
- Onay bekleyen talepler listesi ve onay/reddet feedback’i olmalı.
- Takvim sekmesi MVP-2 EmptyState olabilir.
- countBusinessDays ve dynamic balanceAfter korunmalı.

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

Mevcut `/izin` korunur.

Route tamamlandıysa ilgili navigation item’da `soon: true` kalmamalı.

## Kaçak Önleme Kontrolleri

Şu komutları çalıştır:

```bash
rg -n 'Hello "/_app|izin.*soon: true|TODO|FIXME' src/routes src/lib/navigation.ts
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

- Eklenen/güncellenen route: `/izin`
- Kullanılan demo adapter veya Supabase query.
- Navigation değişikliği.
- UI/UX kabul kriterlerinden önemli maddeler.
- Test sonuçları.
