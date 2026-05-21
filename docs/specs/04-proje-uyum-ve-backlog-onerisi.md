# Proje Uyumu ve Backlog Onerisi

## 1. Artifact'i Nasil Konumlandirmali?

Bu artifact'i dogrudan urun ekran haritasi olarak degil, "mobil konsept prototip" olarak konumlandirmak daha dogru. Cunku:

- Tek statik HTML; route, auth, tenant, Supabase, RLS, i18n yok.
- Veriler hard-coded ve mevcut Mert Teknik seed'iyle uyumsuz.
- Menu genis gorunuyor ama 14 item generic placeholder'a gidiyor.
- AI Koc aktif gorunuyor, oysa mevcut mimaride MVP-2.
- Top hamburger bozuk.

## 2. Mevcut Local Proje Ozetiyle Uyum Matrisi

| Konu | Mevcut local/proje ozeti | Artifact | Karar |
|---|---|---|---|
| Framework | TanStack Start, React 19, Tailwind v4, shadcn-style | Inline HTML/CSS/JS | Artifact kodu alinmamali |
| Backend | Supabase Auth/PostgREST/RLS | Yok | Sadece gorsel referans |
| Tenant | Mert Teknik A.S. | Mert Teknik footer var ama 104 calisan | Demo veri duzeltilmeli |
| ERP | Canias pasif placeholder | Logo Tiger bagli | Canias'a cekilmeli |
| AI Koc | Floating UI, vault/tool-call ileride | Aktif chat tab | V1'de teaser veya limited assistant |
| Bottom nav | Persona'ya gore degisir | Sabit 5 tab: Ana/Izin/Masraf/Koc/Menu | Persona bazli IA karari gerekli |
| Calisan sayisi | 4 | 104 | Seed ile uyumlu olmali |
| Departman | 3 | 8 | Seed ile uyumlu olmali |
| Pozisyon | 3 | 24 | Seed ile uyumlu olmali |
| Performans | Yetkinlik listesi + donem CRUD PR #6 | KPI dashboard mock | /performans ile hizalanmali |

## 3. V1 Ekran Haritasi ile Artifact Arasindaki Buyuk Fark

V1 dokumanlari 75+ ekranlik ciddi bir SaaS haritasi tarif ediyor. Artifact ise calisan mobil deneyimi gibi baslayip IK admin menusu gibi bitiyor. Bu yüzden ekran kararini artifact'tan degil, V1 haritasi + mevcut repo sprint durumundan vermek gerekir.

En kritik farklar:

- V1: AI Koc placeholder. Artifact: aktif chat.
- V1: Haklar & Uyum/Kale V1 kapsaminda. Artifact menu'de yok.
- V1: Raporlar ve Ayarlar detaylari var. Artifact'ta sadece Ayarlar placeholder.
- V1: Sözleşmeler 8 ekran. Artifact'ta tek placeholder.
- V1: Izin 6 ekran. Artifact'ta 1 ekran + sheet.
- V1: Masraf 7 ekran. Artifact'ta 1 ekran + sheet.

## 4. Onerilen Sprint-3 Ekran Kapsami

MVP foundation zaten login/dashboard/performans hattinda baslamis. Siradaki sprintte "artifact'i toparlamak" yerine "gercek MVP ekranlarini urunlestirmek" daha saglikli.

### Sprint-3A: Navigation + IA Temizligi

Amaç: Kullanici artifact'taki gibi kaybolmasin; gercek MVP modulleri net gorunsun.

Isler:

- Mobile bottom tab kararini sabitle:
  - Calisan: Dashboard, Izin, Masraf, Koc, Profil/Menu
  - Yonetici/IK: Dashboard, Performans, Calisanlar, Onaylar, Menu
- Desktop sidebar gruplarini V1 ile hizala.
- Placeholder modullere `Yakinda` badge'i koy.
- AI Koc'u floating teaser olarak tut; aktif chat izlenimi verme.
- Header hamburger mobile Sheet drawer olarak calisir hale gelsin.

### Sprint-3B: Demo Data Alignment

Amaç: Uygulama, dokuman ve demo ayni hikayeyi anlatsin.

Isler:

- Mert Teknik A.S. tenant datasini tek mock source'dan besle.
- 4 calisan, 3 departman, 3 pozisyon, 3 yetkinlik ile ekran textlerini hizala.
- ERP satiri: Canias, pasif/beklemede.
- Logo Tiger, 104 calisan, 8 departman, 24 pozisyon gibi artifact kalintilarini kaldir.

### Sprint-3C: Izin ve Masraf Minimal Vertical Slice

Amaç: Mobilde gercek deger gosteren iki self-service akisi.

Izin:

- /izin ozet: bakiye, gecmis, bekleyen.
- Yeni izin sheet:
  - izin_turu
  - baslangic_tarihi
  - bitis_tarihi
  - toplam_gun
  - vekil
  - aciklama
  - belge opsiyonel/zorunlu
  - bakiye sonrası
  - onaya gonder
- Success toast ve listede optimistic item.

Masraf:

- /masraf ozet: bekleyen, onaylanan, limit, son masraflar.
- Yeni masraf sheet:
  - kategori
  - tutar
  - para_birimi
  - KDV
  - tarih
  - aciklama
  - fis upload placeholder
  - policy/limit uyarisi
  - onaya gonder
- OCR ileride; V1'de "fis yukle" yeterli.

### Sprint-3D: Performans MVP ile Hizalama

Amaç: PR #6 sonrasinda /performans gercek deger gostersin.

Isler:

- Yetkinlik listesi + performans_cycles CRUD mobile responsive.
- Artifact'taki KPI skoru ve stat kartlari sadece future concept olarak kalsin.
- Donem olusturma yonetici/IK modunda gorunsun.
- Calisan modunda readonly KPI/yetkinlik ozet gorunsun.

## 5. Tasarim Sistemi Kararlari

Onerilen net kararlar:

- shadcn-style component kaynak: repo.
- Icon sistemi: Lucide.
- Emoji sadece chat microcopy veya empty-state icinde, ana navigasyon ve finans/uyum ekranlarinda kullanilmaz.
- Kart radius: 8-12px; nested card yok.
- Status renkleri:
  - Success: green/lime
  - Warning: amber
  - Danger: red
  - AI/context: violet
  - Neutral: slate/gray
- AI Koc gizlilik metni: "Bu sohbet calisan mahremiyeti icin sinirlandirilmis erisimle saklanir" gibi daha hukuken dikkatli microcopy.

## 6. Production'a Tasinmamasi Gereken Artifact Ogeleri

- Inline HTML/CSS/JS yapisi.
- `openDrawer()` bug'i.
- Emoji ikon sistemi.
- `10,7/10` skor.
- Logo Tiger ERP metni.
- 104 calisan / 8 departman / 24 pozisyon hard-coded verileri.
- "100% gizli" kesin iddiasi.
- Generic insaat placeholder'inin her menu item icin ayni kullanimi.
- Form submit'in yalnizca modal kapatmasi.

## 7. Kullanilabilir Artifact Ogeleri

Alinabilir fikirler:

- Mobil bottom tab prototipi.
- Izin ve masraf icin bottom sheet pattern'i.
- KPI hero + horizontal metric card yapisi.
- AI Koc suggestion chipleri.
- Privacy footer fikri, microcopy duzeltilerek.
- Dark mode toggle fikri.

## 8. Karar Onerisi

PULS icin tasarim kaynagi sirasini su sekilde belirlemek iyi olur:

1. Mevcut repo ve Supabase gercekleri.
2. V1 ekran haritasi ve veri sozlugu.
3. Bu artifact'tan sadece mobil pattern ve moodboard.
4. Eski b527cc16 UX audit bulgulari, ama yeni artifact'a tekrar uyarlanarak.

Bu siralama korunursa, urun sahibi tarafindan gelen amatör ekranlar projeyi dagitmaz; aksine iyi fikirler ayiklanip dogru mimariye yerlestirilir.
