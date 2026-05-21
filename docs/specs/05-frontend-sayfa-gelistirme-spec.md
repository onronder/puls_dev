# PULS Frontend Sayfa Gelistirme Spesifikasyonu

Tarih: 21 Mayis 2026  
Amac: Cursor ile sayfa sayfa gelistirme icin net ekran, icerik, metrik, demo veri ve MVP davranis listesi.

## 1. Urun Kurgusu

PULS mobile-first Self-HR platformu olacak. Gercek ERP entegrasyonu musteri tarafinda API ile yapilacak; MVP/demo ortaminda Supabase demo verisi ile ekranlar dolu gorunecek.

Teknik hedef:

- Frontend: TanStack Start + React 19 + Tailwind v4 + shadcn-style UI.
- Backend veri kaynagi: Supabase Auth + PostgREST + RLS.
- Demo data: Supabase seed/migration ile.
- ERP: Sprint sonrasinda Railway `erp-connector` ile Canias API adaptorleri.
- AI: V1'de UI teaser/contextual assistant; tool-call/vault MVP-2.

Bu dokuman artifact ekranlarini V1 dokumanlari ve mevcut proje ozetiyle hizalayarak production'a daha yakin bir sayfa haritasi verir.

## 2. Bilgi Mimarisi

### 2.1 Desktop Sidebar

| Grup | Sayfalar | Not |
|---|---|---|
| Ana | Dashboard | Role-aware ana giris |
| IK Yonetimi | Performans, Kariyer, Calisanlar | V1 MVP icin Performans oncelikli |
| Calisan Surecleri | Izin, Masraf, Sozlesmeler | Izin/Masraf mobile-first |
| Uyum & Haklar | Haklar & Uyum | Kale kapsaminda Sprint+ |
| AI | AI Koc | V1 teaser/contextual; V2 aktif chat |
| Tanim & Kurulum | Sirket, Departmanlar, Pozisyonlar, Izin Tanimlari, Masraf Kategorileri, Performans Parametreleri, ERP Entegrasyon | IK Admin |
| Sistem | Ayarlar, Profil, Cikis | Her rol kendi scope'u |

### 2.2 Mobile Bottom Tab

Artifact'taki tab yapisi iyi bir baslangic ama persona'ya gore degismeli.

| Persona | Tab 1 | Tab 2 | Tab 3 | Tab 4 | Tab 5 |
|---|---|---|---|---|---|
| Calisan | Ana Sayfa | Izin | Masraf | Koc | Profil |
| Yonetici | Dashboard | Performans | Onaylar | Koc | Menu |
| IK Admin | Dashboard | Calisanlar | Performans | Onaylar | Menu |
| Patron | Dashboard | Raporlar | Performans | Koc | Menu |

V1 icin basitlestirme: `Dashboard`, `Performans`, `Izin`, `Masraf`, `Menu`. `AI Koc` floating button olarak tum ekranlarda kalabilir.

## 3. Route Listesi

### 3.1 MVP-1 / Sprint-3 Oncelikli

| Route | Sayfa | Persona | Durum | Amac |
|---|---|---|---|---|
| `/login` | Login | Tum roller | Mevcut | Supabase Auth |
| `/dashboard` | Dashboard | Tum roller | Mevcut/genisletilecek | Role-aware ana ozet |
| `/performans` | Performans Dashboard | IK/Yonetici/Patron | Mevcut/genisletilecek | Donem, yetkinlik, KPI ozet |
| `/performans/donemler` | Donem Yonetimi | IK Admin | PR #6 | Donem CRUD |
| `/performans/calisan/$id` | Calisan Performans Detay | IK/Yonetici/Calisan | Yeni | KPI + yetkinlik + rapor |
| `/izin` | Izin Ozet | Calisan/Yonetici/IK | Yeni | Bakiye, takvim, gecmis |
| `/izin/bekleyen` | Izin Onaylari | Yonetici/IK | Yeni | Onay kuyrugu |
| `/masraf` | Masraf Ozet | Calisan/Yonetici/Finans/IK | Yeni | Masraf listesi ve ozet |
| `/masraf/bekleyen` | Masraf Onaylari | Yonetici/Finans | Yeni | Onay ve odeme |
| `/menu` | Mobile Menu/Profile | Tum roller | Yeni | Profil + rol bazli modul listesi |

### 3.2 MVP-2 / Sonraki Sprint

| Route | Sayfa | Persona | Amac |
|---|---|---|---|
| `/calisanlar` | Calisan Listesi | IK/Yonetici | People master data |
| `/calisanlar/$id` | Calisan Detay | IK/Yonetici/Calisan | Multi-tab profil |
| `/kariyer` | Kariyer Haritasi | Calisan/Yonetici/IK | Ladder + gelisim plani |
| `/sozlesmeler` | Sozlesme Listesi | IK/Hukuk/Calisan | Belge takibi |
| `/haklar-uyum` | Haklar & Uyum | IK/Hukuk/Patron | Kale dashboard |
| `/raporlar` | Raporlar | IK/Patron | Export ve analitik |
| `/ayarlar` | Ayarlar | IK Admin | Tenant/system settings |
| `/ai-koc` | AI Koc | Tum roller | Aktif chat, vault MVP-2 |

## 4. Sayfa Detaylari

## 4.1 Login

Route: `/login`  
Kaynak: mevcut uygulama  
Roller: tum roller

Gosterilecek alanlar:

- PULS logo.
- E-posta.
- Sifre.
- Beni hatirla.
- Giris yap.
- Sifremi unuttum.
- Magic link gonder.
- Demo login shortcut, sadece dev/demo ortaminda.

State'ler:

- Loading.
- Invalid credentials.
- MFA gerekli.
- Tenant/role bulunamadi.

Basari:

- Supabase session acilir.
- Persona ve tenant cozulur.
- `/dashboard` route'una gider.

## 4.2 Dashboard

Route: `/dashboard`  
Roller: Calisan, Yonetici, IK Admin, Patron  
Mevcut durum: canli DB sayilari var; genisletilecek.

### Ortak alanlar

| Alan | Kaynak | Not |
|---|---|---|
| Hos geldin mesaji | `profiles`, `employees` | Ad + rol |
| Tenant adi | `tenants` | Mert Teknik A.S. |
| Persona switch | local/app state + role | Yonetici/Calisan modu |
| AI Koc floating button | UI only | V1 teaser |

### IK Admin Dashboard

Hero / metrikler:

| Metrik | Gosterim | Kaynak | Formul |
|---|---|---|---|
| Aktif Calisan | `4` | `employees` | active employee count |
| Departman | `3` | `departments` | active department count |
| Pozisyon | `3` | `positions` | active position count |
| Yetkinlik Sablonu | `3` | `performans_competency_templates` | active template count |
| ERP Durumu | `Canias pasif` | `erp_connections` | latest connection status |
| Veri Hazirligi | `%72` | demo computed | ERP mapping + employee completeness |

Kartlar:

- "Canias Baglantisi": pasif, son senkron yok, CTA `Alan eslestirme`.
- "Performans": aktif donem varsa donem adi; yoksa `Donem ac`.
- "Onaylar": bekleyen izin/masraf sayisi.
- "AI Koc": `MVP-2 icin hazirlik`.

Listeler:

- Son aktiviteler: calisan eklendi, ERP baglantisi olusturuldu, yetkinlik sablonu eklendi.
- Eksik kurulum adimlari: ERP mapping, performans donemi, izin politikasi, masraf kategorileri.

### Calisan Dashboard

Metrikler:

| Metrik | Gosterim | Kaynak |
|---|---|---|
| Izin Bakiyesi | `14 gun` | `leave_balances` veya demo view |
| Bekleyen Masraf | `₺2.340` | `expense_claims` |
| Performans Skoru | `93,6` veya `--` | `performance_scores` / demo |
| Kariyer Hazirligi | `%87` veya teaser | future/demo |

Hizli aksiyonlar:

- Izin talep et.
- Masraf bildir.
- KPI gir.
- AI Koc'a sor.

### Yonetici Dashboard

Metrikler:

- Ekip calisan sayisi.
- Bekleyen izin onayi.
- Bekleyen masraf onayi.
- Eksik KPI girisi.
- Riskli performans/bağlilik sinyali.

Listeler:

- Bekleyen onaylar.
- Ekip performans siralamasi.
- Bu hafta izinli ekip uyeleri.

### Patron Dashboard

Metrikler:

- Toplam calisan.
- Departman sayisi.
- Genel performans ortalamasi.
- Devir riski / baglilik.
- Aylik masraf toplam.
- Yaklasan sozlesme riski.

## 4.3 Performans Dashboard

Route: `/performans`  
Roller: IK Admin, Patron, Yonetici; Calisan readonly varyant  
Artifact referansi: Ana Sayfa KPI kartlari, Menu > Performans

### Ust metrikler

| Metrik | Gosterim | Kaynak | Formul |
|---|---|---|---|
| Aktif Donem | `2026 H1` | `performans_cycles` | active cycle |
| Ortalama Puan | `82,4` veya demo | performance view | avg overall_score |
| Bekleyen Degerlendirme | `12` | evaluations | pending count |
| Yetkinlik Sablonu | `3` | `performans_competency_templates` | count |
| Terfi Adayi | `5` | future/demo | eligible count |

### Ana icerik

- Donem secici.
- Calisan performans tablosu.
- Departman karsilastirma karti.
- Yetkinlik sablonlari listesi.
- Donem yoksa empty state: `Aktif performans donemi yok`.

### Tablo kolonlari

| Kolon | Kaynak | Not |
|---|---|---|
| Calisan | `employees` | avatar + ad |
| Departman | `departments` | badge |
| Pozisyon | `positions` | text |
| KPI Puani | performance scores | progress bar |
| Yetkinlik | evaluations | `4.3/5` |
| Genel Skor | computed | renkli status |
| Durum | computed | Cok iyi/Iyi/Plan gerekli |
| Aksiyon | route | Detay |

### Aksiyonlar

- Yeni donem ac.
- Calisana git.
- Yetkinlik sablonu ekle.
- Excel export.

## 4.4 Donem Yonetimi

Route: `/performans/donemler`  
Roller: IK Admin

Alanlar:

| Alan | Kontrol | Kaynak |
|---|---|---|
| Donem adi | Input | `performans_cycles.name` |
| Baslangic | DatePicker | `start_date` |
| Bitis | DatePicker | `end_date` |
| Durum | Select/Badge | draft/active/closed |
| Kapsam | Multi-select | departments |
| KPI giris sikligi | Select | monthly/quarterly/end |

State'ler:

- Active donem var.
- Active donem yok.
- Cakisan donem uyarisi.
- Kapali donem readonly.

## 4.5 Calisan Performans Detay

Route: `/performans/calisan/$id`  
Roller: IK Admin, Yonetici, Calisan kendisi readonly

Header:

- Calisan avatar/ad.
- Departman.
- Pozisyon.
- Yonetici.
- Aktif donem.
- Genel skor.

Tablar:

| Tab | Icerik |
|---|---|
| KPI | KPI listesi, hedef, gerceklesen, agirlik, skor |
| Yetkinlik | Yetkinlik maddeleri, puan, yorum |
| Rapor | Donem ozeti, tavsiye, PDF export |
| Audit | Degisiklik gecmisi |

KPI alanlari:

- KPI adi.
- Kategori.
- Hedef deger.
- Gerceklesen deger.
- Birim.
- Agirlik.
- Donem.
- Veri kaynagi: manuel/ERP.
- Son guncelleme.

## 4.6 Izin Ozet

Route: `/izin`  
Roller: Calisan, Yonetici, IK Admin  
Artifact referansi: `page-izin`

### Calisan varyanti

Hero:

- Kalan Yillik Izin: `14 gun`.
- Kullanilan: `6 gun`.
- Toplam hak: `20 gun`.

Stat kartlari:

| Metrik | Demo | Kaynak |
|---|---|---|
| Yillik | `14 / 20 gun` | `leave_balances` |
| Mazeret | `7 / 10 gun` | `leave_balances` |
| Hastalik | `10 / 10 gun` | `leave_balances` |
| Bekleyen | `2` | `leave_requests.status=pending` |

Takvim:

- Aylik takvim.
- Renkler: onayli yesil, bekleyen amber, resmi tatil mavi, reddedilen kirmizi.
- Legend.

Izin gecmisi kolonlari:

- Izin turu.
- Tarih araligi.
- Gun sayisi.
- Vekil.
- Durum.
- Onaylayan.

### Yeni Izin Talebi Sheet

Alanlar:

| Alan | Kontrol | Kural |
|---|---|---|
| Izin turu | Select | 8 izin tipi |
| Baslangic | Date | zorunlu |
| Bitis | Date | baslangictan once olamaz |
| Toplam gun | Computed | hafta sonu/tatil kurali |
| Yarim gun | Switch | opsiyonel |
| Vekil | Select | ayni departmandan aktif calisan |
| Aciklama | Textarea | opsiyonel/zorunlu policy |
| Belge | FileUpload | hastalik vb. icin |
| Bakiye sonrasi | Readonly | negatifse uyar |

Aksiyonlar:

- Iptal.
- Taslak kaydet.
- Onaya gonder.

Submit sonrasi:

- Toast.
- Gecmise bekleyen satir eklenir.
- Audit log.

### Yonetici / IK varyanti

Ek blok:

- Bekleyen onaylar.
- Ekip takvimi.
- Cakisma uyarilari.

## 4.7 Izin Onaylari

Route: `/izin/bekleyen`  
Roller: Yonetici, IK Admin

Liste kolonlari:

- Calisan.
- Departman.
- Izin turu.
- Tarih araligi.
- Gun.
- Bakiye etkisi.
- Cakisma durumu.
- Vekil.
- Durum.
- Aksiyon.

Aksiyonlar:

- Onayla.
- Reddet.
- Detay.
- Toplu onay.

## 4.8 Masraf Ozet

Route: `/masraf`  
Roller: Calisan, Yonetici, Finans, IK Admin  
Artifact referansi: `page-masraf`

Hero:

- Bu ay onaylanan: `₺8.640`.
- Limit: `₺15.000`.
- Kullanım: `%58`.

Stat kartlari:

| Metrik | Demo | Kaynak |
|---|---|---|
| Bekleyen | `₺2.340 / 2 kalem` | `expense_claims` |
| Yil toplami | `₺34.2K` | yearly sum |
| En buyuk kategori | `Seyahat %41` | category share |
| Ortalama/Ay | `₺4.9K` | yearly/month count |

Son masraflar listesi:

- Kategori ikonu.
- Baslik.
- Tarih.
- Kategori.
- Tutar.
- Durum.

### Yeni Masraf Sheet

Alanlar:

| Alan | Kontrol | Kural |
|---|---|---|
| Kategori | Select | Masraf kategorileri |
| Tutar | Money input | > 0 |
| Para birimi | Select | TRY default |
| KDV dahil mi | Switch | finance |
| KDV orani | Select | opsiyonel |
| Tarih | Date | gelecek tarih olamaz |
| Aciklama | Textarea | policy |
| Fis/Belge | FileUpload/Camera | tutara gore zorunlu |
| Proje/Masraf merkezi | Select | opsiyonel |
| Policy uyarisi | Readonly | limit asimi, belge eksigi |

Aksiyonlar:

- Fis yukle.
- Taslak kaydet.
- Onaya gonder.

V1'de OCR:

- UI placeholder olabilir.
- Gercek OCR/AI fis okuma sonraki sprint.

## 4.9 Masraf Onaylari

Route: `/masraf/bekleyen`  
Roller: Yonetici, Finans

Liste kolonlari:

- Calisan.
- Kategori.
- Tutar.
- Tarih.
- Belge var/yok.
- Policy durumu.
- Onay seviyesi.
- Aksiyon.

Aksiyonlar:

- Onayla.
- Reddet.
- Detay.
- Odendi isaretle, sadece finans.

## 4.10 Calisanlar

Route: `/calisanlar`  
Roller: IK Admin, Yonetici scope  
Artifact referansi: Menu > Calisanlar placeholder

Ust metrikler:

| Metrik | Demo | Kaynak |
|---|---|---|
| Aktif calisan | `4` | `employees` |
| Deneme suresi | `0/5` demo opsiyon | employees |
| Departman | `3` | departments |
| Pozisyon | `3` | positions |

Tablo kolonlari:

- Avatar/ad.
- E-posta.
- Departman.
- Pozisyon.
- Yonetici.
- Ise baslama.
- Calisma durumu.
- Persona role.
- Aksiyon.

Filtreler:

- Departman.
- Pozisyon.
- Status.
- Persona.

Aksiyonlar:

- Yeni calisan.
- Toplu ice aktar.
- Detay.

## 4.11 Calisan Detay

Route: `/calisanlar/$id`

Header:

- Avatar/ad.
- Pozisyon.
- Departman.
- Yonetici.
- Status.
- KVKK/tenant badges.

Tablar:

- Genel.
- Izin.
- Masraf.
- Performans.
- Kariyer.
- Sozlesmeler.
- Dosyalar.
- Audit.

## 4.12 Kariyer Haritasi

Route: `/kariyer`  
Roller: Calisan, Yonetici, IK  
Artifact referansi: Menu > Kariyer Haritasi placeholder

Metrikler:

- Mevcut seviye.
- Hedef seviye.
- Hazirlik yuzdesi.
- Eksik yetkinlik sayisi.
- Onerilen egitim.

Ana icerik:

- 5 basamakli ladder.
- Gap analysis.
- Bireysel gelisim plani.
- AI Koc tavsiye teaser.

## 4.13 Sozlesmeler

Route: `/sozlesmeler`

Metrikler:

- Aktif sozlesme.
- Yakinda bitecek.
- Imza bekleyen.
- KVKK bildirim bekleyen.

Liste kolonlari:

- Calisan.
- Sozlesme tipi.
- Baslangic.
- Bitis.
- Durum.
- Imza durumu.
- Aksiyon.

## 4.14 Haklar & Uyum

Route: `/haklar-uyum`

Metrikler:

- Fazla mesai riski.
- Acik sikayet.
- KVKK riza eksigi.
- VERBIS durumu.
- Mevzuat uyarisi.

Ana icerik:

- Risk listesi.
- Sikayet/olay kayitlari.
- Fazla mesai 270 saat takip.
- KVKK consent listesi.

## 4.15 Tanim & Kurulum

### Sirket Kurulum

Route: `/ayarlar/sirket` veya `/kurulum/sirket`

Alanlar:

- Sirket adi.
- VKN.
- Sektor.
- Calisan sayisi bandi.
- Paket.
- Varsayilan dil.
- Varsayilan timezone.

### Departmanlar

Route: `/ayarlar/departmanlar`

Alanlar:

- Departman adi.
- Kod.
- Ust departman.
- Yonetici.
- Aktif/pasif.
- Calisan sayisi.

### Pozisyonlar

Route: `/ayarlar/pozisyonlar`

Alanlar:

- Pozisyon adi.
- Departman.
- Seviye.
- Is degerleme puani.
- Aktif/pasif.

### Izin Tanimlari

Route: `/ayarlar/izin-tipleri`

Alanlar:

- Izin tipi.
- Yillik hak.
- Ucretli/ucretsiz.
- Belge zorunlu mu.
- Onay akisi.
- Devreden izin kuralı.

### Masraf Kategorileri

Route: `/ayarlar/masraf-kategorileri`

Alanlar:

- Kategori.
- Aylik limit.
- Belge zorunlu limit.
- Onay seviyesi.
- Muhasebe kodu.

### Performans Parametreleri

Route: `/ayarlar/performans`

Alanlar:

- Yetkinlik sablonlari.
- KPI kategorileri.
- Agirliklar.
- Skor bandlari.
- Prim katsayilari.

### ERP Entegrasyon

Route: `/ayarlar/erp`

Demo durum:

- Provider: Canias.
- Status: Pasif / Beklemede.
- Son senkron: Yok.
- Alan eslestirme: placeholder.

Alanlar:

- ERP tipi.
- Base URL.
- Tenant/company code.
- Auth method.
- Mapping status.
- Last sync.
- Sync log.

## 4.16 Menu / Profil

Route: `/menu` veya layout icinde sheet  
Roller: tum roller

Profil karti:

- Avatar.
- Ad soyad.
- Unvan.
- Departman.
- Status.
- Tenant.

Menu itemlari role-based olmali:

- Calisan: Profil, Izin, Masraf, Sozlesmelerim, Kariyerim, AI Koc, Ayarlar.
- Yonetici: Ekip, Performans, Onaylar, Izin, Masraf, AI Koc, Ayarlar.
- IK Admin: Calisanlar, Performans, Izin, Masraf, Sozlesmeler, Kurulum, ERP, Ayarlar.
- Patron: Dashboard, Raporlar, Performans, Uyum, Ayarlar.

## 4.17 AI Koc

V1 karar:

- Aktif chat route'u production MVP'ye alinmayacaksa `AI Koc yakinda` sayfasi.
- Floating button her ekranda teaser acabilir.

V1 teaser alanlari:

- "Kisisel AI Koc yakinda".
- Neler yapacak: izin, masraf, kariyer, IK haklari, performans.
- Gizlilik notu.
- Waitlist / beni bilgilendir.

MVP-2 aktif chat:

- Chat history.
- Suggested prompts.
- Tool-call badges.
- Source/citation panel.
- Privacy/access policy.
- Conversation vault.

## 5. Demo Data Gereksinimi

Minimum demo set:

- 1 tenant: Mert Teknik A.S.
- 3 departman.
- 3 pozisyon.
- 4 calisan.
- 1 IK Admin kullanici.
- 1 ERP connection: Canias, inactive.
- 3 performans yetkinlik sablonu.
- 1 aktif performans donemi.
- 4 calisan performans skor kaydi.
- 8 izin tipi.
- 4 izin bakiyesi.
- 6 izin talebi.
- 5 masraf kategorisi.
- 8 masraf kaydi.
- 3 sozlesme kaydi.
- 5 audit/activity kaydi.

## 6. Cursor Icin Gelistirme Sirasi

1. Layout IA: role-aware sidebar + mobile bottom tabs.
2. Demo data hooks: Supabase query helper + mock fallback.
3. Dashboard role variants.
4. Performans genisletme.
5. Izin list + new request sheet.
6. Masraf list + new claim sheet.
7. Menu/profile.
8. Tanim ekranlari readonly/list seviyesinde.
9. Placeholder cleanup: her yakinda ekran net badge + aciklama.
10. AI Koc teaser.

## 7. Kabul Kriterleri

Her sayfa icin:

- Loading state var.
- Empty state var.
- Error state var.
- Demo data ile dolu gorunuyor.
- Role/persona farki uygulanmis.
- Mobile 390px genislikte tasma yok.
- Desktop sidebar ile calisiyor.
- Aksiyon varsa toast veya state degisimi var.
- Placeholder ise `Yakinda` olarak net isaretli.
- Hard-coded ERP/employee sayisi yok; Supabase verisi veya demo seed kaynagi kullaniliyor.
