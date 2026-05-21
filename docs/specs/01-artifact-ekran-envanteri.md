# PULS Claude Artifact Ekran Envanteri

Tarih: 21 Mayis 2026  
Kaynak artifact: https://claude.ai/public/artifacts/a7924878-ff1e-4d69-b8c7-3ed944e87a20  
Incelenen dosya: `CodexAnalysis/extracted/puls-mobile-artifact.html`  
Mobil viewport: 390 x 844

## 1. Genel Yapi

Artifact tek sayfalik statik HTML prototipidir. Gercek route yapisi yoktur; ekran degisimi `switchTab(tabId)` ve `navTo(screenId, title)` fonksiyonlariyla client-side yapilir.

Calisan ana ekranlar:

| ID | Ekran | Tip | Navigasyon | Durum |
|---|---|---|---|---|
| `page-home` | Ana Sayfa / KPI | Ana tab | Bottom tab: Ana Sayfa | Calisiyor |
| `page-izin` | Izin / Tatil | Ana tab | Bottom tab: Izin | Calisiyor |
| `leave-sheet` | Yeni Izin Talebi | Bottom sheet | Izin > + Yeni Izin Talebi | Calisiyor, submit mock |
| `page-masraf` | Masraf / Cuzdan | Ana tab | Bottom tab: Masraf | Calisiyor |
| `expense-sheet` | Yeni Masraf Bildirimi | Bottom sheet | Masraf > + Yeni Masraf Bildir | Calisiyor, submit mock |
| `page-kok` | AI Koc | Ana tab | Bottom tab: Koc | Calisiyor, mock chat |
| `page-menu` | Menu / Profil + Modul listesi | Ana tab | Bottom tab: Menu | Calisiyor |
| `page-detail` | Generic detay placeholder | Ortak placeholder | Menu item click | Tek placeholder |

Kritik not: Ust soldaki hamburger `openDrawer()` cagiriyor, fakat kaynakta `openDrawer` fonksiyonu ve drawer markup'i yok. CSS tanimlari var, islev yok.

## 2. Global Bilesenler

| Bilesen | Icerik | Not |
|---|---|---|
| Status bar | Bos alan | Native safe-area taklidi |
| Top nav | Sol hamburger, orta baslik, sag tema butonu | Baslik tab'a gore degisir |
| Tema toggle | Light/Dark mode | `data-theme` uzerinden calisir |
| Bottom tab bar | Ana Sayfa, Izin, Masraf, Koc, Menu | Mobile-first shell |
| Generic detay | 🚧, baslik, "Bu ekran yakinda hazir olacak", Geri Don | Tum placeholder moduller ayni |

## 3. Ana Sayfa / KPI

Navigasyon: Bottom tab `Ana Sayfa`  
Baslik: `PULS`  
Ekran amaci: Kullaniciya genel performans/KPI ozeti gostermek.

Icerik bloklari:

| Blok | Alanlar / Degerler | Aksiyon |
|---|---|---|
| Hero kart | Genel Performans Skoru `93,6`; donem `01.01.2025 - 31.12.2025`; rol `Genel Mudur`; rozet `COK IYI` | Yok |
| Yatay stat kartlari | Stratejik IK `9,4/10`; Performans `9,2/10`; Baglilik `10,7/10`; Ise Alim `9,2/10`; Egitim `9,5/10`; IK Surec `4,35/5` | Yatay scroll |
| KPI Kategorileri | Stratejik IK Planlamasi; Performans Yonetimi; Calisan Bagliligi; Ise Alim ve Yetenek; Egitim ve Gelisim; IK Surecleri ve Uyum | Satirlar chevron gosteriyor, ama gercek detay yok |
| One Cikan Bulgular | KPI stratejisi %100; Egitim hedefleri tamamlandi; Ise alim suresi %20 iyilesti; Sikayet cozum suresi gelisim alani | Son satir chevron gosteriyor, ama aksiyon yok |

Alan problemleri:

- `Baglilik 10,7 / 10` skala disi bir deger.
- `KPI Kategorileri` agirliklari toplam mantigi sorunlu gorunuyor: ilk satir `%100 agirlik`, digerleri de agirlik tasiyor.
- Hero "Genel Mudur" derken menu profili "Insan Kaynaklari Direktoru"; persona tutarsiz.
- Kategoriler veri semantigi yerine renk ve emoji agirlikli.

## 4. Izin / Tatil

Navigasyon: Bottom tab `Izin`  
Baslik: `Izin · Tatil™`  
Ekran amaci: Kisisel izin bakiyesi, takim takvimi ve izin gecmisini gostermek.

Icerik bloklari:

| Blok | Alanlar / Degerler | Aksiyon |
|---|---|---|
| Hero kart | Kalan Yillik Izin `14 gun`; `6 gun kullanildi`; toplam hak `20 gun` | Yok |
| Yatay bakiye kartlari | Yillik `14/20`; Mazeret `7/10`; Hastalik `10/10`; Bekleyen `2` | Yatay scroll |
| Takvim | Temmuz 2025; gun grid'i; Ozge B., Ben, Onur O. legend | Gun secimi yok |
| Izin gecmisi | Yillik Izin 5 gun beklemede; Mazeret 1 gun onaylandi; Yillik 5 gun onaylandi; Mazeret 2 gun onaylandi | Satir detayi yok |
| CTA | `+ Yeni Izin Talebi` | Bottom sheet acar |

Yeni Izin Talebi form alanlari:

| Alan | Kontrol | Default / Secenek |
|---|---|---|
| Izin Turu | Select | Yillik Izin, Mazeret Izni, Hastalik Izni |
| Baslangic | Date input | `2025-07-14` |
| Bitis | Date input | `2025-07-18` |
| Vekil | Select | Ozge B., Onur O. |
| Iptal | Button | Sheet kapanir |
| Onaya Gonder | Button | Sheet kapanir, veri kaydi yok |

Eksikler:

- V1 dokumanlarinda beklenen 8 izin turu burada 3 secenekle sinirli.
- Canli bakiye kontrolu, cakisma uyarisi, dosya yukleme, vekil uygunluk kontrolu ve onay zinciri yok.
- Submit sonrasi toast/success state yok.

## 5. Masraf / Cuzdan

Navigasyon: Bottom tab `Masraf`  
Baslik: `Masraf · Cüzdan™`  
Ekran amaci: Kisisel masraf ozeti, son masraflar ve yeni bildirim.

Icerik bloklari:

| Blok | Alanlar / Degerler | Aksiyon |
|---|---|---|
| Hero kart | Bu Ay Onaylanan `₺8.640`; limit `₺15.000`; kullanim `%58` | Yok |
| Yatay stat kartlari | Bekleyen `₺2.340 / 2 kalem`; Yil Toplami `₺34.2K`; Seyahat `%41`; Ortalama/Ay `₺4.9K` | Yatay scroll |
| Son masraflar | Ucak, Is Yemegi, Konaklama, Yemek; durumlar Beklemede/Onaylandi | Satir detayi yok |
| CTA | `+ Yeni Masraf Bildir` | Bottom sheet acar |

Yeni Masraf Bildirimi form alanlari:

| Alan | Kontrol | Default / Secenek |
|---|---|---|
| Tur | Select | Seyahat, Konaklama, Yemek, Temsil, Egitim |
| Tutar (TL) | Number input | Placeholder `0,00` |
| Tarih | Date input | `2025-07-10` |
| Aciklama | Text input | Placeholder `Is amaci...` |
| Fis | Upload area | "Fis fotograflay veya yukle" gorsel alan, gercek upload yok |
| Iptal | Button | Sheet kapanir |
| Onaya Gonder | Button | Sheet kapanir, veri kaydi yok |

Eksikler:

- V1 kapsaminda beklenen AI fis okuma, OCR processing state, finans/onay zinciri, KDV/para birimi, masraf detayi ve muhasebe export yok.
- Kamera/fiş alanı sadece dekoratif.
- Limit asimi, policy kontrolu, belge zorunlulugu gibi is kurallari yok.

## 6. AI Koc

Navigasyon: Bottom tab `Koc™`  
Baslik: `AI Koç™`  
Ekran amaci: Kisisel AI sohbeti.

Icerik bloklari:

| Blok | Alanlar / Degerler | Aksiyon |
|---|---|---|
| Chat tarihi | `Bugun` | Yok |
| AI acilis mesaji | Mevlut'e kariyer hazirligi: `%87`; eksik alan: ekip liderligi deneyimi | Quick actions |
| Tool rozetleri | `Harita™`, `KPI`, `Harita™ güncellendi`, `Okul™ önerildi` | Sadece gorsel |
| Kullanici mesaji | "Müdürlük için ne yapmam lazım?" | Statik |
| AI yaniti | 0-30 gun, 30-90 gun, uzun vade plan | Quick actions |
| Oneri chipleri | Kariyer hedefi, Yoruldum, Izin al, Fazla mesai, KPI gozden gecir | Mock yanit uretir |
| Input | Textarea `Bir sey sor...`; send button | Local DOM'a mesaj ekler |
| Privacy footer | `Bu konusma 100% gizli · Yonetici goremez` | Yok |

Mock AI yanit tetikleyicileri:

| Anahtar kelime | Yanit temasi |
|---|---|
| kariyer | Kariyer plani guncellendi |
| izin | Izin bakiyesi ve uygun tarih |
| masraf | Masraf bildirimi yardimi |
| yoruldum | Tukenmislik/izin onerisi |
| fazla mesai | 4857 Is Kanunu Md.41 |
| kpi | Q3 KPI ozeti |
| default | Genel devam mesaji |

Urun stratejisi acisindan not:

Mevcut proje ozetinde AI Koc MVP-2 / vault ve tool-call ileride deniyor; artifact ise AI Koc'u urunun merkezine koyan aktif chat gibi gosteriyor. Bu, stakeholder beklentisi yaratir ve MVP kapsamiyla uyumsuzdur.

## 7. Menu

Navigasyon: Bottom tab `Menu`  
Baslik: `Menü`  
Ekran amaci: Profil ve modul erisimi.

Profil karti:

| Alan | Deger |
|---|---|
| Avatar | `MY` |
| Ad | Mevlut Yilmaz |
| Unvan | Insan Kaynaklari Direktoru |
| Durum | AKTIF |

Menu gruplari ve satirlari:

| Grup | Menu item | Alt bilgi | Hedef |
|---|---|---|---|
| IK Yonetimi | Performans | Mevlut Yilmaz · 4,36 / 5 · Cok Iyi | Generic detail |
| IK Yonetimi | Egitim | Ihtiyac analizi · 5 asama | Generic detail |
| IK Yonetimi | Kariyer Haritasi | Direktör · %87 mudurluk hazirligi | Generic detail |
| IK Yonetimi | Is Degerleme | 855 / 1000 · 6. Sinif · Yuksek | Generic detail |
| Calisan Surecleri | Izin · Tatil™ | 14 gun kalan · 2 bekleyen | `page-izin` |
| Calisan Surecleri | Masraf · Cuzdan™ | ₺2.340 beklemede · ₺8.640 onaylandi | `page-masraf` |
| Calisan Surecleri | Sozlesme · Belge™ | 45 gun sonra bitiyor | Generic detail |
| Tanim & Kurulum | Sirket Kurulum | - | Generic detail |
| Tanim & Kurulum | Departmanlar | 8 departman tanimli | Generic detail |
| Tanim & Kurulum | Pozisyonlar | 24 pozisyon · 3 acik | Generic detail |
| Tanim & Kurulum | Calisanlar | 104 aktif · 5 deneme | Generic detail |
| Tanim & Kurulum | Izin Tanimlari | 8 tip tanimli | Generic detail |
| Tanim & Kurulum | Masraf Kategorileri | 12 kategori · ₺85K toplam limit | Generic detail |
| Tanim & Kurulum | Performans Parametreleri | - | Generic detail |
| Tanim & Kurulum | ERP Entegrasyon | Logo Tiger bagli | Generic detail |
| Sistem | Ayarlar | - | Generic detail |
| Sistem | Gece Modu | Toggle | Tema degistirir |

Kritik uyumsuzluklar:

- Proje ozetindeki pilot ERP Canias iken artifact "Logo Tiger bagli" diyor.
- Sentetik demo Mert Teknik 4 calisan iken artifact 104 aktif calisan gosteriyor.
- Menu bilgi mimarisi V1 dokumanlarindaki "Dashboard · Performans · Kariyer · AI Koc; Yonetim: Calisanlar, Sozlesmeler, Izin, Masraf, Haklar & Uyum" yapisiyla tam ayni degil.
- AI Koc menu grubunda degil, bottom tab'da urunlesmis.

## 8. Generic Detay Placeholder

Tetikleyen menu item'lar:

Performans, Egitim, Kariyer Haritasi, Is Degerleme, Sozlesme, Sirket Kurulum, Departmanlar, Pozisyonlar, Calisanlar, Izin Tanimlari, Masraf Kategorileri, Performans Parametreleri, ERP Entegrasyon, Ayarlar.

Icerik:

| Alan | Deger |
|---|---|
| Ikon | 🚧 |
| Baslik | Tiklanan menu item basligi |
| Aciklama | `Bu ekran yakinda hazir olacak.` |
| CTA | `← Geri Dön` |

Sonuc:

Artifact disaridan cok ekranli gorunuyor, fakat gercek detay icerigi yalnizca 5 ana tab + 2 bottom sheet seviyesinde.

## 9. Mobil Screenshot Listesi

| Dosya | Icerik |
|---|---|
| `artifact-screenshots/01-home-kpi.jpg` | Ana Sayfa KPI |
| `artifact-screenshots/02-izin.jpg` | Izin ana ekran |
| `artifact-screenshots/03-izin-yeni-talep-sheet.jpg` | Yeni Izin Talebi |
| `artifact-screenshots/04-masraf.jpg` | Masraf ana ekran |
| `artifact-screenshots/05-masraf-yeni-bildirim-sheet.jpg` | Yeni Masraf Bildirimi |
| `artifact-screenshots/06-ai-koc.jpg` | AI Koc sohbet |
| `artifact-screenshots/07-menu-top.jpg` | Menu ust kisim |
| `artifact-screenshots/08-menu-middle.jpg` | Menu orta kisim |
| `artifact-screenshots/09-menu-bottom.jpg` | Menu alt kisim |
| `artifact-screenshots/10-dark-mode-menu.jpg` | Dark mode menu |
| `artifact-screenshots/11-detail-placeholder-performans.jpg` | Generic detay placeholder |
