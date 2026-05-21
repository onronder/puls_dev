# Cursor Implementation Prompt

Asagidaki prompt, Cursor'a parca parca verilebilir. Mevcut uygulama koduna gecmeden once `CodexAnalysis/reports/05-frontend-sayfa-gelistirme-spec.md`, `06-metrik-ve-demo-data-katalogu.csv` ve `07-supabase-demo-data-ihtiyaclari.md` dosyalarini referans al.

## Prompt 1 — IA ve Layout

PULS uygulamasinda mevcut layout'u role-aware hale getir.

Stack:
- TanStack Start
- React 19
- Tailwind v4
- shadcn-style UI
- Supabase Auth/PostgREST

Kurallar:
- Mevcut proje pattern'lerini koru.
- Desktop'ta sidebar gruplari: Ana, IK Yonetimi, Calisan Surecleri, Uyum & Haklar, AI, Tanim & Kurulum, Sistem.
- Mobile'da bottom tab persona'ya gore degissin; ilk etapta Dashboard, Performans, Izin, Masraf, Menu kullan.
- AI Koc aktif chat olarak degil, floating teaser button olarak dursun.
- Placeholder moduller `Yakinda` badge'i ve roadmap copy'si gostersin; generic insaat ekrani kullanma.
- Hamburger mobile Sheet drawer acsin.
- Hard-coded demo sayi kullanma; Supabase query veya demo hook kullan.

Kabul kriterleri:
- 390px mobile'da tasma yok.
- Desktop sidebar calisiyor.
- Persona/role bazli menu filtreleniyor.
- Loading, empty, error state var.

## Prompt 2 — Dashboard Metrics

`/dashboard` sayfasini role-aware metriklerle genislet.

IK Admin icin:
- Aktif Calisan
- Departman
- Pozisyon
- Yetkinlik Sablonu
- ERP Durumu
- Veri Hazirligi
- Bekleyen Onaylar
- Son Aktiviteler
- Eksik Kurulum Adimlari

Calisan icin:
- Izin Bakiyesi
- Bekleyen Masraf
- Performans Skoru
- Kariyer Hazirligi
- Hizli aksiyonlar: Izin Talep, Masraf Bildir, KPI Gir, AI Koc

Yonetici icin:
- Ekip Calisan Sayisi
- Bekleyen Izin
- Bekleyen Masraf
- Eksik KPI Girisi
- Ekip Performans Ozeti

Veri kaynaklari ve formuller icin `06-metrik-ve-demo-data-katalogu.csv` kullan.

Kabul kriterleri:
- Demo Mert Teknik datasiyla dolu gorunur.
- Canias ERP pasif gosterilir.
- Logo Tiger veya 104 calisan gibi artifact kalintisi yoktur.

## Prompt 3 — Izin Module

`/izin` ve `/izin/bekleyen` sayfalarini gelistir.

`/izin`:
- Hero: kalan yillik izin.
- Stat kartlari: Yillik, Mazeret, Hastalik, Bekleyen.
- Aylik takvim veya mobile list.
- Izin gecmisi.
- Yeni Izin Talebi bottom sheet.

Yeni Izin Talebi alanlari:
- Izin turu, 8 izin tipi.
- Baslangic.
- Bitis.
- Toplam gun computed.
- Yarim gun switch.
- Vekil.
- Aciklama.
- Belge upload.
- Bakiye sonrasi.

`/izin/bekleyen`:
- Yonetici/IK onay kuyrugu.
- Calisan, departman, izin turu, tarih, gun, bakiye etkisi, cakisma, vekil, durum.
- Onayla/Reddet/Detay.

Kabul kriterleri:
- Submit sadece modal kapatmaz; toast + optimistic list update yapar.
- Empty/loading/error state var.
- Role scope uygulanir.

## Prompt 4 — Masraf Module

`/masraf` ve `/masraf/bekleyen` sayfalarini gelistir.

`/masraf`:
- Hero: bu ay onaylanan, limit, kullanim.
- Stat kartlari: bekleyen, yil toplami, en buyuk kategori, ortalama/ay.
- Son masraflar listesi.
- Yeni Masraf bottom sheet.

Yeni Masraf alanlari:
- Kategori.
- Tutar.
- Para birimi.
- KDV dahil mi.
- KDV orani.
- Tarih.
- Aciklama.
- Fis/belge upload placeholder.
- Proje/Masraf merkezi opsiyonel.
- Policy uyarisi.

`/masraf/bekleyen`:
- Yonetici/Finans onay kuyrugu.
- Calisan, kategori, tutar, tarih, belge, policy, onay seviyesi, aksiyon.
- Finans rolunde odendi isaretle.

Kabul kriterleri:
- Bekleyen tutar listedeki pending claim toplamiyla ayni.
- OCR gercek degilse "yakinda" veya placeholder olarak net.
- Policy status hesaplanir.

## Prompt 5 — Performance Module

`/performans`, `/performans/donemler`, `/performans/calisan/$id` ekranlarini tamamla.

`/performans`:
- Aktif donem.
- Ortalama puan.
- Bekleyen degerlendirme.
- Yetkinlik sablonu.
- Calisan performans tablosu.
- Departman karsilastirma.

`/performans/donemler`:
- Donem listesi.
- Yeni donem modal/sheet.
- Active/draft/closed status.
- Cakisan donem validasyonu.

`/performans/calisan/$id`:
- Calisan header.
- KPI tab.
- Yetkinlik tab.
- Rapor tab.
- Audit tab.

Kabul kriterleri:
- PR #6 performans_cycles varsa onu kullan.
- Yoksa graceful empty state.
- Calisan rolunde readonly.

## Prompt 6 — Demo Seed

Supabase demo seed'i genislet.

Referans:
- `07-supabase-demo-data-ihtiyaclari.md`

Eklenmesi gereken demo tablolar:
- leave_types
- leave_balances
- leave_requests
- expense_categories
- expense_claims
- performance_scores
- performance_kpis
- contracts

Seed kurallari:
- Mert Teknik A.S.
- 3 departman.
- 3 pozisyon.
- 4 calisan.
- Canias inactive ERP connection.
- 8 izin tipi.
- 5+ masraf kategorisi.
- Tekrar calistirilabilir SQL.

Kabul kriterleri:
- Dashboard, Izin, Masraf, Performans sayfalari seed sonrasi dolu gorunur.
- Hard-coded artifact verisi kalmaz.
