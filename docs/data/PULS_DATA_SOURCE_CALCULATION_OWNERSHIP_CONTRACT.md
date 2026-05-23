# PULS Data Source & Calculation Ownership Contract

Tarih: 23 Mayis 2026  
Durum: Planning / Architecture Contract  
Kapsam: V1 UI tamamlandiktan sonra Supabase + Railway entegrasyon fazi icin veri sahipligi, hesaplama sahipligi ve production-grade entegrasyon kararlari.

## 1. Urun Konumlandirmasi

PULS, ERP veya mevcut HR sisteminin yerine gecen bir sistem olarak tasarlanmamalidir.

PULS'un hedef rolu:

- ERP / HR / bordro sistemlerinin uzerine oturan AI tabanli calisan ve yonetici asistani.
- Sirketin gunluk insan yonetimi reflekslerini hizlandiran operational intelligence katmani.
- Calisan, yonetici, IK ve patron icin aksiyon, yorum, risk, hatirlatma ve karar destek arayuzu.
- Kaynak sistemlerde duran resmi kayitlari anlamlandiran, is akisi ve karar ureten self-HR platformu.

Bu nedenle PULS, "source of record" olmaya calismamalidir. PULS, secili alanlarda "system of engagement", "system of intelligence" ve bazi self-HR sureclerinde "system of workflow" olmalidir.

## 2. Temel Mimari Ilke

Ana kural:

> Resmi kayit ERP / HR sisteminde kalir. PULS, minimum canonical fact'leri alir, kullanici deneyimi ve AI destekli karar icin gerekli metrikleri kendi hesaplar.

Bu kural su anlama gelir:

- PULS ham ERP veri golu degildir.
- PULS bordro, ozluk arsivi veya muhasebe sistemi degildir.
- PULS tum ERP tablolariyla birebir senkron tutmaz.
- PULS sadece ekranlari, is akislari, AI baglami ve raporlama icin gereken minimum veri setini tutar.
- PULS hesapladigi metrikleri acik formulle, audit edilebilir ve tenant bazli versionlanmis sekilde uretir.

## 3. Veri Katmanlari

Production-grade veri akisi dort katmanli olmalidir.

```text
ERP / HR / Bordro / Excel / Manuel Kaynak
        ↓
Railway Integration Connector
        ↓
Staging + Mapping + Validation
        ↓
PULS Canonical DB
        ↓
Calculation / Summary / AI Context Layer
        ↓
Frontend + AI Assistant
```

### 3.1 Kaynak Sistemler

Kaynak sistemler resmi operasyonel kaydin sahibidir:

- Canias ERP
- diger ERP sistemleri
- mevcut HR sistemi
- bordro sistemi
- muhasebe sistemi
- Excel / CSV import
- PULS admin manuel konfigurasyonu

### 3.2 Integration Connector

Railway `erp-connector` kaynak sistemi PULS domain modeline ceviren anti-corruption layer'dir.

Sorumluluklari:

- Kaynak API'dan veri cekmek veya webhook almak.
- External ID eslestirmesi yapmak.
- Field mapping uygulamak.
- Veri validasyonu yapmak.
- Hassas alanlari filtrelemek veya maskelemek.
- Degisen kayitlari tespit etmek.
- Sync log ve hata raporu uretmek.

Connector is mantigi yerine entegrasyon mantigi tasimalidir. Ornegin "izin hakki kac gun olmali" domain kuralidir; "Canias'taki PERSONEL_NO hangi PULS alanina denk geliyor" entegrasyon kuralidir.

### 3.3 Staging

Staging kalici data warehouse degildir. Kisa omurlu, izlenebilir, temizleme ve hata cozme alani olmalidir.

Tutulabilecek minimum alanlar:

- `sync_batch_id`
- `source_system`
- `source_endpoint`
- `external_id`
- `source_updated_at`
- `payload_hash`
- `mapping_status`
- `validation_status`
- `validation_errors`
- `last_seen_at`

Raw payload opsiyoneldir. Tutulursa:

- maskelenmis olmalidir,
- hassas alan icermemelidir,
- TTL ile silinmelidir,
- varsayilan 7-30 gun arasi saklanmalidir,
- urun ekranlarinda dogrudan kullanilmamalidir.

### 3.4 PULS Canonical DB

PULS uygulamasinin okudugu ve RLS ile korunan asil tablo katmanidir.

Bu katman ERP tablosu kopyasi degildir. PULS domain modelidir.

Ornek canonical alanlar:

- employees
- departments
- positions
- leave_types
- leave_balances
- leave_requests
- expense_categories
- expense_claims
- performance_cycles
- performance_scores
- career_profiles
- training_needs
- contracts
- erp_connections
- erp_field_mappings
- erp_sync_logs
- audit_logs

### 3.5 Calculation / Summary Layer

PULS ekranlarinin hizli, tutarli ve acik hesaplama ile beslenmesini saglar.

Uygun teknikler:

- PostgreSQL view
- materialized view
- summary table
- scheduled Railway worker
- Supabase cron / Edge Function
- frontend-only preview calculation

Kural:

- Kalici karar metrikleri backend'de hesaplanir.
- Form onizlemeleri frontend'de hesaplanabilir.
- AI tarafindan uretilecek yorumlar kaynak chips + hesaplama aciklamasi ile desteklenir.

## 4. Source-of-Truth Siniflari

Her alan asagidaki siniflardan birine atanmalidir.

| Sinif | Sahibi | Ornek | PULS Davranisi |
|---|---|---|---|
| External Master | ERP / HR | calisan sicil no, departman, pozisyon, ise giris | PULS mirror/cache tutar; manuel override kontrollu |
| PULS Configuration | PULS Admin | izin tipleri, masraf limitleri, skor bandlari | PULS source-of-truth |
| PULS Transaction | PULS Workflow | izin talebi, masraf bildirimi, onay karari | PULS source-of-truth; gerekirse ERP'ye write-back |
| External Transaction | ERP / Muhasebe | odeme durumu, resmi izin bakiyesi, bordro bilgisi | PULS okur ve gosterir; edit etmez |
| Computed Metric | PULS | dashboard skor, readiness, policy status | PULS hesaplar |
| AI Output | PULS AI Layer | kariyer onerisi, risk yorumu, ozet | Kaynak ve guven seviyesi ile gosterilir |
| User Input | Kullanici | izin aciklamasi, masraf aciklamasi, KPI girisi | PULS kaydeder; audit log zorunlu |

## 5. Hassas Veri Ilkesi

MVP ve V1 entegrasyonunda PULS'e alinmamasi gereken alanlar:

- TCKN
- IBAN
- banka hesap bilgisi
- dogum tarihi
- aile bilgileri
- saglik raporu icerigi
- engellilik / ozel nitelikli saglik bilgisi
- brut/ucret/maas bilgisi
- bordro detaylari
- prim/kesinti bordro satirlari

Bu alanlar ileride gerekirse ayri bir security design ile degerlendirilir:

- kolon bazli sifreleme,
- ABAC/RLS,
- role-gated UI,
- audit,
- retention,
- explicit customer DPA.

Varsayilan V1 karar:

> PULS operasyonel self-HR icin gereken minimum alanlari alir; bordro ve ozel nitelikli ozluk verisini almaz.

## 6. Ekran Bazli Veri Sahipligi

### 6.1 Dashboard

| Alan | Kaynak | Hesaplama Sahibi | Not |
|---|---|---|---|
| Tenant adi | PULS / auth tenant | PULS | tenant context |
| Aktif calisan sayisi | employees | PULS SQL | status active count |
| Departman sayisi | departments | PULS SQL | active count |
| Pozisyon sayisi | positions | PULS SQL | active count |
| ERP durumu | erp_connections | PULS | latest status |
| Veri hazirligi | mappings + employees + configs | PULS summary | product metric |
| Bekleyen onaylar | leave + expense | PULS SQL | scope'a gore |
| Son aktiviteler | audit/events | PULS | append-only source |

Dashboard metrikleri ERP'den hesaplanmis gelmemelidir. ERP sadece temel kayit ve sync durumu verir; dashboard yorumu PULS tarafinda uretilir.

### 6.2 Calisanlar

| Alan | Kaynak | Sahiplik |
|---|---|---|
| Sicil / external employee id | ERP / HR | external master |
| Ad soyad | ERP / HR veya PULS manuel | external master cache |
| E-posta | ERP / HR / Auth | canonical cache |
| Departman | ERP / HR / PULS setup | canonical master |
| Pozisyon | ERP / HR / PULS setup | canonical master |
| Yonetici | ERP / HR / PULS setup | canonical relation |
| Ise giris | ERP / HR | external master |
| Durum | ERP / HR | external master |
| Izin bakiyesi ozet | leave_balances | PULS veya external transaction |
| Performans kapsami | performance_cycles/scope | PULS configuration |

Ucret, maas, IBAN, TCKN varsayilan liste alanlari olmamalidir.

### 6.3 Departmanlar ve Pozisyonlar

Departman ve pozisyonlar PULS icin core reference data'dir. Kaynak ERP olabilir, ama PULS icinde canonical olarak tutulmalidir.

| Alan | Kaynak | Hesaplama |
|---|---|---|
| Departman adi/kodu | ERP veya PULS admin | yok |
| Ust departman | ERP veya PULS admin | org tree PULS |
| Departman yoneticisi | employee relation | PULS join |
| Calisan sayisi | employees | PULS computed |
| Pozisyon adi/kodu | ERP veya PULS admin | yok |
| Norm kadro | PULS admin | yok |
| Dolu/acik pozisyon | employees + norm | PULS computed |
| Is degerleme puani | PULS job-eval | PULS computed |

Pozisyonlarda ucret bandi default UI ve DB MVP kapsaminda olmamalidir. Is degerleme puani ve seviye gosterilebilir; maas/ucret bandi ayri yetki ve faz ister.

### 6.4 Izin

Izin, PULS'un self-HR workflow alanlarindan biridir.

| Alan | Kaynak | Hesaplama Sahibi |
|---|---|---|
| Izin tipleri | PULS config | PULS |
| Kidem bazli hak kural | PULS config / mevzuat | PULS |
| Resmi izin bakiyesi | ERP varsa ERP, yoksa PULS | source kararli |
| Yeni izin talebi | PULS transaction | PULS |
| Is gunu hesabi | PULS | frontend preview + backend final |
| Bakiye sonrasi | PULS | preview + backend final |
| Takvim cakismasi | PULS | backend/query |
| Onay zinciri | PULS config/workflow | PULS |
| Onay sonucu | PULS transaction | PULS; gerekiyorsa ERP write-back |

Kural:

- ERP izin bakiyesi resmi kaynaksa PULS onu okur.
- PULS uzerinden izin talebi alinacaksa, backend final hesaplama PULS'te yapilir.
- Onaylanan izin ERP'ye yazilacaksa write-back ayrica tasarlanir.

### 6.5 Masraf

Masraf Cuzdan modulu PULS workflow alanidir; muhasebe/ERP resmi odeme ve fis kayit kaynagi olabilir.

| Alan | Kaynak | Hesaplama Sahibi |
|---|---|---|
| Masraf kategorileri | PULS config | PULS |
| Muhasebe hesap kodu | ERP/muhasebe mapping | PULS config + ERP |
| Masraf bildirimi | PULS transaction | PULS |
| OCR ciktilari | OCR worker | AI/sensor output |
| Policy status | PULS | backend final |
| Limit kullanimi | expense_claims + config | PULS computed |
| Onay zinciri | PULS config | PULS |
| Odeme durumu | muhasebe/ERP veya PULS finance | source kararli |
| ERP sync status | erp_sync_logs | PULS |

Masraf onayi PULS'te olusabilir; muhasebe kaydi ERP'ye aktarilabilir. Bu durumda PULS workflow source, ERP accounting source olur.

### 6.6 Performans

Performans PULS'un ana zeka katmanlarindan biridir. ERP sadece bazi KPI gerceklesenlerini besleyebilir.

| Alan | Kaynak | Hesaplama Sahibi |
|---|---|---|
| Donem | PULS config | PULS |
| Yetkinlik sablonlari | PULS config | PULS |
| KPI tanimi | PULS config / manager input | PULS |
| KPI gerceklesen | ERP/API/manual | kaynak bazli |
| KPI score | PULS | PULS formula |
| Yetkinlik puani | manager/HR input | PULS transaction |
| Overall score | PULS | PULS formula |
| Score band | PULS config | PULS |
| Terfi/gelisim sinyali | PULS | PULS/AI assisted |

ERP'den "performans skoru" almak ana model olmamalidir. PULS, KPI gerceklesenlerini alabilir ama puanlama metodolojisini kendi konfigurasyonu ile hesaplamalidir.

### 6.7 Kariyer

Kariyer, PULS'un yorum ve karar destek katmanidir.

| Alan | Kaynak | Hesaplama Sahibi |
|---|---|---|
| Career ladder | PULS config | PULS |
| Current step | PULS / HR input | PULS |
| Target role | employee/manager/HR input | PULS |
| Missing competencies | performance + ladder | PULS computed |
| Readiness score | performance + career rules | PULS computed |
| Development plan | PULS workflow | PULS |
| AI onerileri | PULS AI | AI with source chips |

Kariyer readiness ERP'den gelmemelidir. Bu PULS'un fark yaratan metrigidir.

### 6.8 Egitim

Egitim V1.5'e daha yakin dursa da, V1'de sinyal toplama ve ihtiyac gorunumu olabilir.

| Alan | Kaynak | Hesaplama Sahibi |
|---|---|---|
| Egitim ihtiyaci | performance + career gaps | PULS computed |
| Oncelik | PULS | PULS/AI assisted |
| Egitim katalogu | PULS admin / external LMS | source kararli |
| Enrollment | PULS/LMS | source kararli |
| Kirkpatrick skor | PULS/LMS | PULS |

Egitim onerileri PULS'un AI destekli intelligence katmanidir; ERP'den beklenmemelidir.

### 6.9 Is Degerleme

Is degerleme PULS metodoloji alanidir.

| Alan | Kaynak | Hesaplama Sahibi |
|---|---|---|
| Metodoloji | PULS config | PULS |
| Faktor agirliklari | PULS config | PULS |
| Faktor puanlari | HR/admin input | PULS transaction |
| Toplam puan | PULS | PULS formula |
| Seviye/band | PULS config | PULS |

Ucret bandi hassas oldugu icin MVP UI ve canonical data kapsaminda varsayilan olmamalidir.

### 6.10 Sozlesmeler

| Alan | Kaynak | Hesaplama Sahibi |
|---|---|---|
| Sozlesme metadata | PULS / HR system | source kararli |
| Sozlesme dosyasi | storage/e-sign provider | source kararli |
| Imza durumu | e-sign provider / PULS | source kararli |
| Bitişe kalan gun | PULS | computed |
| Risk etiketi | PULS | computed |
| Hatirlaticilar | PULS scheduler | PULS |

Sozlesme icerigi ve ucret maddeleri role-gated ve opsiyonel faz olmalidir. V1 ekranlari metadata ve risk uyarisi seviyesinde kalabilir.

### 6.11 AI Koc

AI Koc V1'de aktif production chat degilse, veri modeli de bunu yansitmalidir.

V1:

- feature flag kapali veya teaser.
- vault schema hazir olabilir.
- aktif tool-call yok.
- AI output gercek karar uretmez.

V2:

- conversation vault.
- source chips.
- confidence.
- min cohort privacy.
- tool-call audit.
- PII redaction.

## 7. Hesaplama Sahipligi Kurallari

### 7.1 Frontend'de Hesaplanabilecekler

Sadece gecici onizleme ve kullanici yardimi:

- izin formunda secili tarih araligina gore tahmini gun sayisi
- izin sonrasi tahmini bakiye
- masraf formunda KDV dahil/dahil degil onizleme
- progress bar yuzdesi gorsel hesaplari
- client-side filtreleme/siralama

Frontend sonucu final karar olmamalidir. Submit sonrasi backend ayni hesabi tekrar yapmalidir.

### 7.2 Supabase SQL / View'da Hesaplanacaklar

Deterministik, query bazli, hizli metrikler:

- aktif calisan sayisi
- departman/pozisyon sayisi
- pending approval count
- aylik masraf toplami
- sozlesme bitise kalan gun
- ERP match percentage
- setup completion percentage
- liste aggregate'leri

### 7.3 Railway Worker'da Hesaplanacaklar

Daha agir, batch veya external servis gerektiren hesaplar:

- ERP sync normalization
- OCR processing
- policy recalculation batch
- materialized summary refresh
- performance/career/training cross-module refresh
- notification scheduling
- e-sign callback processing
- future AI enrichment

### 7.4 AI Layer'da Uretilecekler

AI sadece yorum, ozet, onerme ve dogal dil yardimci katmani olmalidir. Deterministik HR kararlarini tek basina vermemelidir.

AI output icin zorunlu UX:

- kaynak moduller
- kullanilan tarih araligi
- confidence seviyesi
- "hesaplama nasil yapildi" aciklamasi
- user feedback
- audit trace

## 8. Sync ve Write-Back Karari

V1 icin varsayilan sync yonu:

> ERP -> PULS read-oriented sync.

PULS -> ERP write-back sadece kontrollu moduller icin ayrica acilmalidir:

- onaylanmis izin talebi ERP'ye yazilsin mi?
- onaylanmis masraf muhasebe sistemine aktarilsin mi?
- employee master PULS'te editlenirse ERP'ye gider mi?

Varsayilan cevap:

- Employee master write-back: hayir.
- Departman/pozisyon write-back: hayir, pilotta manual karar.
- Izin write-back: opsiyonel, musteri ERP API yetenegine bagli.
- Masraf write-back: muhasebe entegrasyonu fazinda opsiyonel.
- Performans write-back: hayir.

## 9. Demo Fallback Politikasi

Production-grade UI demo veriden koparilmalidir ama bos ekran da vermemelidir.

Kural:

- Gercek query basarili ve kayit varsa gercek veri.
- Gercek query basarili ama bos ise empty state.
- Query permission/schema hatasi varsa controlled error state.
- Sadece development/demo modda demo fallback.
- Production'da demo fallback feature flag'e bagli olmalidir.

Demo data urun gercegi gibi davranmamalidir. CTA'lar "onizleme", "API bekleniyor", "yakinda" veya "read-only" olarak acik ayrilmalidir.

## 10. Audit ve Izlenebilirlik

Her entegrasyon ve hesaplama izlenebilir olmalidir.

Minimum audit:

- kim tetikledi
- hangi tenant
- hangi kaynak sistem
- hangi entity
- onceki/deger sonrasi
- hesaplama versiyonu
- field mapping versiyonu
- sync batch id
- hata varsa hata kodu

Her computed metric icin:

- formula name
- formula version
- input snapshot timestamp
- calculated_at

Bu, PULS'u "AI tahmin etti" seviyesinden "denetlenebilir karar destek sistemi" seviyesine tasir.

## 11. MVP Icin Net Kararlar

1. PULS ERP/HR replacement degildir.
2. PULS raw ERP data lake kurmaz.
3. PULS minimum canonical HR facts tutar.
4. Hassas bordro/ozluk verisi MVP'de alinmaz.
5. UI metrikleri PULS tarafinda hesaplanir.
6. ERP resmi kayit ve external master kaynagi olarak kalir.
7. Izin ve masraf PULS workflow'u olabilir; ERP write-back opsiyoneldir.
8. Performans, kariyer, egitim ve is degerleme PULS intelligence katmanidir.
9. AI output final karar degil; kaynakli, aciklanabilir yardimci katmandir.
10. Her alan icin source-of-truth ve calculation owner migration oncesi sabitlenmelidir.

## 12. Sonraki Cikti

Bu kontratin ardindan uretilmesi gereken dosya:

`PULS_FIELD_OWNERSHIP_MATRIX.csv`

Kolonlar:

- route
- screen_block
- ui_label
- technical_field
- data_class
- source_of_truth
- canonical_table
- external_source
- calculation_owner
- calculation_formula
- persistence_strategy
- sensitivity_level
- rls_scope
- demo_fallback
- write_back_required
- notes

Bu CSV tamamlanmadan production DB migration yazilmamalidir.

