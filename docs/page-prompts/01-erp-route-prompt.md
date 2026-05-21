# Cursor Prompt — `/erp` Ekranı

Bu prompt tek ekran içindir. Başka route ekleme, başka ekranları düzenleme.

## Hedef

Ana PULS uygulamasına `/erp` route’unu ekle ve Lovable prototipindeki ERP Entegrasyon ekranını Faz 1 design system ile birebir yakın taşı.

Amaç, menüde “Yakında” gibi görünen ERP ekranını gerçek, dolu ve demo-ready hale getirmek. Gerçek Canias API entegrasyonu bu PR’ın konusu değil.

## Repo ve Kaynaklar

Ana repo:

```text
/Users/onuronder/Documents/puls_dev
```

Lovable referans repo:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot
```

Lovable kaynak route:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/routes/erp.tsx
```

Lovable demo data:

```text
/Users/onuronder/Documents/Claude/Projects/Puls/CodexAnalysis/references/puls-hr-pilot/src/lib/demo-data.ts
```

## Kapsam

Yalnızca şu işleri yap:

1. `src/routes/_app/erp.tsx` route’unu ekle.
2. `src/lib/navigation.ts` içinde ERP item’ını gerçek `/erp` route’una bağla ve `soon` durumunu kaldır.
3. Gerekirse `src/lib/demo/puls-demo-data.ts` içine ERP için izole demo adapter/data ekle.
4. Gerekli i18n key’lerini `tr-TR.json` ve `en-US.json` içine ekle.
5. `src/routeTree.gen.ts` route generation sonucu güncellenecekse normaldir.

Şunlara dokunma:

- Auth/login.
- `/dashboard`, `/performans`, `/izin`, `/masraf`, `/calisanlar`, `/menu` davranışları.
- Supabase migration.
- Railway/API entegrasyonu.
- AI Koç aktif chat.
- Capacitor dosyaları.

## Ana Projede Kullanılacak Componentler

Mevcut Faz 1 componentlerini kullan:

```ts
import { DataList } from '#/components/puls/DataList'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
```

Gerekirse `Card`, `Progress`, `Skeleton` gibi mevcut UI componentlerini kullanabilirsin; yeni UI primitive ekleme.

## Lovable Kaynak Route Kodu

Aşağıdaki kod birebir referanstır. Ana projeye aynen kopyalama; import alias `#/...`, mevcut component API’leri ve i18n yapısına adapte et.

```tsx
import { createFileRoute } from "@tanstack/react-router";
import { Plug, RefreshCw, Link2, CheckCircle2, AlertTriangle, Info, ArrowRight } from "lucide-react";
import { toast } from "sonner";
import { PageContainer } from "@/components/puls/AppShell";
import { SectionHeader } from "@/components/puls/SectionHeader";
import { MetricCard } from "@/components/puls/MetricCard";
import { StatusPill } from "@/components/puls/StatusPill";
import { erpStatus, erpMappings, erpSyncLogs } from "@/lib/demo-data";

export const Route = createFileRoute("/erp")({
  head: () => ({ meta: [{ title: "ERP Entegrasyon — PULS" }] }),
  component: ErpPage,
});

function ErpPage() {
  return (
    <PageContainer>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            Tanım & Kurulum
          </div>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
            ERP Entegrasyon
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Sistem: {erpStatus.system} · {erpStatus.statusLabel}.
          </p>
        </div>
        <StatusPill tone="warning">Beklemede</StatusPill>
      </div>

      <section className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <MetricCard label="Sistem" value={<span className="text-[20px]">Canias</span>} icon={Plug} />
        <MetricCard
          label="Veri hazırlığı"
          value={
            <span>
              {erpStatus.readiness}
              <span className="text-base text-muted-foreground">%</span>
            </span>
          }
          hint={
            <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-muted">
              <div className="h-full rounded-full bg-primary" style={{ width: `${erpStatus.readiness}%` }} />
            </div>
          }
        />
        <MetricCard
          label="Alan eşleştirme"
          value={
            <span className="tabular">
              {erpStatus.mappedFields}
              <span className="text-base text-muted-foreground"> / {erpStatus.totalFields}</span>
            </span>
          }
          hint="Mapped / toplam"
        />
        <MetricCard label="Son deneme" value={<span className="text-[16px]">{erpStatus.lastAttempt}</span>} hint="Zaman aşımı" tone="warning" />
      </section>

      <div className="mt-6 flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() =>
            toast("Canias API erişimi bekleniyor.", {
              description:
                "Mapping editörü, müşteri tarafında API erişimi açıldığında devreye alınacak.",
            })
          }
          className="inline-flex h-11 items-center gap-2 rounded-md bg-primary px-4 text-[13px] font-semibold text-primary-foreground hover:bg-primary/90"
        >
          <Link2 className="h-4 w-4" /> Alan eşleştir <ArrowRight className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          onClick={() =>
            toast("Test bağlantısı müşteri API erişimi açılınca çalışacak.", {
              description: "Şu an Canias tarafında kimlik doğrulama bekleniyor.",
            })
          }
          className="inline-flex h-11 items-center gap-2 rounded-md border border-border bg-card px-4 text-[13px] font-medium hover:bg-accent"
        >
          <RefreshCw className="h-4 w-4" /> Test bağlantısı
        </button>
      </div>

      <section className="mt-8">
        <SectionHeader title="Alan eşleştirme" description="PULS alanı → Canias alanı." />
        <div className="mt-3 overflow-hidden rounded-lg border border-border bg-card">
          <div className="hidden grid-cols-[1fr_1fr_120px] gap-3 border-b border-border bg-surface-2 px-4 py-2.5 text-[11px] font-semibold uppercase tracking-[0.04em] text-muted-foreground sm:grid">
            <div>PULS alanı</div>
            <div>Canias alanı</div>
            <div className="text-right">Durum</div>
          </div>
          <ul className="divide-y divide-border">
            {erpMappings.map((m) => (
              <li key={m.puls} className="grid grid-cols-[1fr_auto] gap-3 px-4 py-3 sm:grid-cols-[1fr_1fr_120px]">
                <div className="text-[14px] font-medium text-foreground">{m.puls}</div>
                <div className="text-[13px] tabular text-muted-foreground sm:text-foreground">{m.erp}</div>
                <div className="text-right sm:justify-self-end">
                  {m.status === "mapped" ? (
                    <StatusPill tone="success">Eşleşti</StatusPill>
                  ) : (
                    <StatusPill tone="warning">Bekliyor</StatusPill>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="mt-8">
        <SectionHeader title="Sync logları" description="Son bağlantı denemeleri." />
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {erpSyncLogs.map((l) => {
            const Icon = l.level === "success" ? CheckCircle2 : l.level === "warning" ? AlertTriangle : Info;
            const tone =
              l.level === "success"
                ? "bg-success-soft text-success"
                : l.level === "warning"
                  ? "bg-warning-soft text-warning"
                  : "bg-info-soft text-info";
            return (
              <li key={l.id} className="flex items-start gap-3 p-4">
                <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-md ${tone}`}>
                  <Icon className="h-[16px] w-[16px]" aria-hidden />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="text-[14px] text-foreground">{l.message}</div>
                  <div className="text-[12px] text-muted-foreground">{l.at}</div>
                </div>
              </li>
            );
          })}
        </ul>
      </section>
    </PageContainer>
  );
}
```

## Lovable Demo Data

Bu veriyi route içine gömme. Ana projede `src/lib/demo/puls-demo-data.ts` içinde izole export olarak tut.

Önemli düzeltme: Lovable verisindeki `Maaş` alanını bu ekranda varsayılan göstermeyin. ERP API ve yetki modeli netleşene kadar ücret alanı hassas kabul edilir.

```ts
export const erpStatus = {
  system: "Canias" as const,
  status: "beklemede" as const,
  statusLabel: "API erişimi bekleniyor",
  mappedFields: 6,
  totalFields: 11,
  lastAttempt: "Dün, 18:42",
  readiness: 72,
};

export const erpMappings = [
  { puls: "Sicil no", erp: "PERS_NO", status: "mapped" as const },
  { puls: "Ad soyad", erp: "AD_SOYAD", status: "mapped" as const },
  { puls: "Departman", erp: "DEPT_KOD", status: "mapped" as const },
  { puls: "Pozisyon", erp: "POZ_KOD", status: "mapped" as const },
  { puls: "Yönetici", erp: "YON_PERS_NO", status: "mapped" as const },
  { puls: "İşe giriş tarihi", erp: "ISE_GIRIS", status: "mapped" as const },
  { puls: "E-posta", erp: "—", status: "pending" as const },
  { puls: "Durum", erp: "—", status: "pending" as const },
  { puls: "Telefon", erp: "—", status: "pending" as const },
  { puls: "Lokasyon", erp: "—", status: "pending" as const },
  { puls: "Vardiya", erp: "—", status: "pending" as const },
];

export const erpSyncLogs = [
  { id: "s1", at: "Dün 18:42", level: "info" as const, message: "Bağlantı denendi · zaman aşımı" },
  { id: "s2", at: "Dün 18:40", level: "warning" as const, message: "Kimlik doğrulama bekleniyor (müşteri tarafı)" },
  { id: "s3", at: "Dün 14:10", level: "success" as const, message: "Alan şeması hazırlandı · 11 alan" },
  { id: "s4", at: "16 May 09:22", level: "info" as const, message: "Mapping taslağı oluşturuldu" },
];
```

## Ana Proje İçin Önerilen Adapter API

`src/lib/demo/puls-demo-data.ts` içine şuna benzer export ekle:

```ts
export type DemoErpMappingStatus = 'mapped' | 'pending'
export type DemoErpSyncLevel = 'success' | 'warning' | 'info'

export type DemoErpOverview = {
  status: {
    system: 'Canias'
    status: 'beklemede'
    statusLabel: string
    mappedFields: number
    totalFields: number
    lastAttempt: string
    readiness: number
  }
  mappings: Array<{
    puls: string
    erp: string
    status: DemoErpMappingStatus
  }>
  syncLogs: Array<{
    id: string
    at: string
    level: DemoErpSyncLevel
    message: string
  }>
}

export async function fetchDemoErpOverview(): Promise<DemoErpOverview> {
  return demoErpOverview
}
```

## UI/UX Kabul Kriterleri

Sayfada şu bölümler eksiksiz olmalı:

1. Page header:
   - Eyebrow veya subtitle bağlamı: `Tanım & Kurulum`
   - H1: `ERP Entegrasyon`
   - Açıklama: `Sistem: Canias · API erişimi bekleniyor.`
   - Status pill: `Beklemede`

2. Metrik satırı:
   - Sistem: `Canias`
   - Veri hazırlığı: `%72`
   - Alan eşleştirme: `6 / 11`
   - Son deneme: `Dün, 18:42`

3. CTA alanı:
   - Primary: `Alan eşleştir`
   - Secondary: `Test bağlantısı`
   - İkisi de gerçek API çağırmayacak.
   - İkisi de “müşteri API erişimi bekleniyor” mesajıyla güvenli feedback verecek.
   - Sadece toast kullanılıyorsa metin açıkça “şimdilik API bekleniyor” demeli.

4. Alan eşleştirme:
   - Desktop’ta üç kolon: PULS alanı, Canias alanı, Durum.
   - Mobile’da satırlar okunabilir kalmalı.
   - `Maaş` veya ücret alanı listede olmayacak.
   - Mapped status: success pill `Eşleşti`.
   - Pending status: warning pill `Bekliyor`.

5. Sync logları:
   - En az 4 log.
   - Success, warning, info icon/tone ayrımı.
   - Zaman ve mesaj birlikte gösterilmeli.

## Mobile Kabul Kriterleri

- 390px ve 360px genişlikte horizontal overflow olmayacak.
- CTA butonları gerekirse alt alta düşecek.
- Metrik kartları mobile’da yatay scroll veya 2 kolon düzeninde okunabilir olacak.
- Bottom tab ile AI floating button çakışmayacak.
- Alan eşleştirme satırlarında text kırpılırsa anlam kaybolmayacak.

## i18n Key Önerisi

Anahtarları mevcut JSON yapısına uygun yerleştir. Türkçe değerler:

```json
{
  "erp": {
    "title": "ERP Entegrasyon",
    "subtitle": "Sistem: Canias · API erişimi bekleniyor.",
    "badge": "Beklemede",
    "metrics": {
      "system": "Sistem",
      "dataReadiness": "Veri hazırlığı",
      "fieldMapping": "Alan eşleştirme",
      "lastAttempt": "Son deneme"
    },
    "actions": {
      "mapFields": "Alan eşleştir",
      "testConnection": "Test bağlantısı"
    },
    "toast": {
      "apiPendingTitle": "Canias API erişimi bekleniyor.",
      "mapDescription": "Mapping editörü, müşteri tarafında API erişimi açıldığında devreye alınacak.",
      "testDescription": "Şu an Canias tarafında kimlik doğrulama bekleniyor."
    },
    "sections": {
      "mapping": "Alan eşleştirme",
      "mappingDescription": "PULS alanı → Canias alanı.",
      "syncLogs": "Sync logları",
      "syncLogsDescription": "Son bağlantı denemeleri."
    },
    "columns": {
      "pulsField": "PULS alanı",
      "erpField": "Canias alanı",
      "status": "Durum"
    },
    "status": {
      "mapped": "Eşleşti",
      "pending": "Bekliyor"
    }
  }
}
```

İngilizce değerleri anlamlı çevir:

- ERP Integration
- API access pending
- Field mapping
- Sync logs
- Matched
- Pending

## Navigation Kabul Kriteri

`src/lib/navigation.ts` içinde ERP item:

- `to: '/erp'`
- `soon` olmamalı.
- Sidebar’da `Tanım & Kurulum` altında görünmeli.
- Mobile `/menu` içinde ERP artık `Yakında` değil, tıklanabilir olmalı.

## Kaçak Önleme

Bu PR sonunda şu kontrolleri elle veya script ile yap:

```bash
rg -n 'Hello "/_app|soon: true.*erp|Maaş|salary|maas' src
```

Beklenen:

- `Hello "/_app` sonucu olmamalı.
- ERP navigation item’ında `soon: true` olmamalı.
- ERP mapping ekranında `Maaş`, `salary`, `maas` görünmemeli.

## Test

```bash
pnpm typecheck
pnpm exec eslint src
pnpm build
pnpm check-i18n
```

## Çıktı Beklentisi

PR açıklamasında şunları yaz:

- Eklenen route: `/erp`
- Güncellenen navigation item: ERP artık tıklanabilir.
- Demo data kaynağı: `fetchDemoErpOverview`
- Hassas ücret alanı çıkarıldı.
- Test sonuçları.

