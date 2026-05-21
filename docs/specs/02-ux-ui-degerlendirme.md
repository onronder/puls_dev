# PULS Artifact UX/UI Degerlendirmesi

Tarih: 21 Mayis 2026  
Kapsam: Claude artifact mobil prototip + V1 dokumanlari + mevcut proje ozeti

## 1. Kisa Sonuc

Artifact, mobilde ilk bakista akici ve guzel bir demo hissi veriyor; fakat urun tasarimi olarak henuz "production SaaS" degil. Daha cok iOS benzeri, renkli, emoji agirlikli bir konsept prototip. En buyuk sorun, ekranda gorunen vaat ile mevcut MVP kapsami arasindaki fark: artifact AI Koc'u, izin/masraf formlarini ve genis menu setini neredeyse urunlesmis gibi gosteriyor; mevcut proje ise login, dashboard, performans iskeleti ve placeholder moduller seviyesinde.

## 2. Kritik Bulgular

| Kod | Onem | Bulgu | Etki | Oneri |
|---|---|---|---|---|
| UX-C1 | Kritik | Ust hamburger bozuk: `openDrawer()` yok | Mobilde beklenen ana navigasyon calismiyor | Ya hamburgeri kaldir, ya gercek Sheet drawer uygula |
| UX-C2 | Kritik | Gorunen menu sayisi gercek ekran sayisini sisiriyor | Stakeholder "tum moduller var" sanabilir | Placeholder'lari "yakinda" net ayir; MVP badge/status kullan |
| UX-C3 | Kritik | Persona karisik: Genel Mudur, IK Direktoru, calisan izin/masraf, admin kurulum ayni profilde | Rol bazli urun vaadi bulanir | Persona toggle'a gore bilgi mimarisi ayir |
| UX-C4 | Kritik | AI Koc aktif gorunuyor, mevcut roadmap'te MVP-2 | Kapsam ve beklenti riski | V1'de AI Koc'u contextual teaser + waitlist olarak sinirla |
| DATA-C1 | Kritik | Canias pilot yerine "Logo Tiger bagli" | ERP stratejisiyle celisir | Artifact datasini Mert Teknik + Canias placeholder'a cevir |
| DATA-C2 | Kritik | Mert Teknik 4 calisan demo yerine 104 calisan | Canli DB seed'iyle celisir | Demo verisini Supabase seed ile ayni tut |
| UI-H1 | Yuksek | Emoji ve sembol kullanimi kurumsal HR icin fazla oyuncakli | Guven, ciddiyet, enterprise algisi duser | Lucide/shadcn ikon sistemine gec |
| UX-H2 | Yuksek | Izin ve masraf submit sadece sheet kapatiyor | Kullanici kayit basarili mi anlayamaz | Toast, success state, created item ekle |
| UX-H3 | Yuksek | KPI satirlari chevron gosteriyor ama detay acmiyor | Tiklanabilirlik yaniltici | Chevron varsa detay route/sheet olmali |
| UX-H4 | Yuksek | 10,7 / 10 gibi skala disi metrik var | Veri guveni zedelenir | Validasyon: max scale ve normalize skor |
| A11Y-H1 | Yuksek | Renk + emoji status'lari sistematik degil | Erişilebilirlik ve taranabilirlik dusuk | StatusPill: ikon + text + semantic token |
| IA-H1 | Yuksek | Bottom tab'da Koc var, V1 dokumaninda Bildirim/Profil bekleniyor | Navigasyon stratejisi tutarsiz | V1 mobile IA kararini sabitle |
| UI-M1 | Orta | iOS HIG hissi fazla, PULS marka dili zayif | Urun ozgunlugu azalir | Markaya ozel token, ikon, tipografi seti |
| UX-M2 | Orta | Formlar cok az alanla kurgulanmis | HR is kurali eksik | Policy, belge, onay zinciri, bakiye etkisi ekle |
| UX-M3 | Orta | Dark mode calisiyor ama tasarim sistemiyle baglantisi yok | Uygulamada yeniden is cikartir | Tailwind/shadcn tokenlariyla yeniden kur |

## 3. Ekran Bazli UX Notlari

### Ana Sayfa / KPI

Güçlü:

- Mobilde ilk gorus alaninda hero + yatay stat kartlari etkili.
- KPI kategorileri hizli taranabiliyor.
- "One Cikan Bulgular" karar destegi gibi iyi bir niyet tasiyor.

Zayıf:

- Ana sayfa bir calisan dashboard'u mu, yonetici dashboard'u mu belirsiz.
- "Genel Performans Skoru" bir insanin skoru gibi, "KPI Kategorileri" ise sirket/IK performansi gibi.
- Baglilik 10,7/10 skala hatasi profesyonel algiyi dusurur.
- "Tumu" ve chevron'lar aksiyon vadediyor ama gitmiyor.

Onerilen revizyon:

- Persona'ya gore iki varyant: `Calisan Ozeti` ve `Yonetici/IK Ozeti`.
- MVP current state ile uyumluysa dashboard'u 4 metrikle sinirla: Calisan, Departman, Yetkinlik, ERP Baglanti.
- KPI kategorilerini /performans derinligine bagla; yoksa chevron kaldir.

### Izin / Tatil

Güçlü:

- Bakiye, takvim ve gecmis ayni ekranda anlasilir.
- Bottom sheet mobil icin dogru pattern.

Zayıf:

- V1'de 8 izin turu varken formda 3 tur var.
- Onay zinciri, bakiye etkisi, cakisma kontrolu ve belge yukleme yok.
- Takvimde renkler var ama gunler tiklanabilir degil.

Onerilen revizyon:

- Formda "kac gun dusecek", "bakiye sonra", "cakisma var/yok", "onaylayacak kisi" bilgileri olmali.
- Hastalik izninde belge upload sarti gosterilmeli.
- Yonetici modunda bekleyen izin onay listesi ayrilmali.

### Masraf / Cuzdan

Güçlü:

- Para metrikleri okunakli.
- Son masraflar listesi mobilde iyi taraniyor.
- Yeni masraf sheet'i hizli.

Zayıf:

- AI fis okuma sadece gorsel olarak var, akisi yok.
- KDV, fis zorunlulugu, para birimi, policy/limit kontrolu yok.
- Bekleyen tutar ile listede gorunen bekleyen kalemler uyumsuz: listedeki bekleyenler `₺3.840 + ₺450`, stat karti `₺2.340`.

Onerilen revizyon:

- Cek > OCR > Dogrula > Onaya gonder akisini ayrica tasarla.
- Masraf detayi, onay durumu ve muhasebe export state'leri eklenmeli.
- Tutarlilik icin mock data tek kaynaktan gelsin.

### AI Koc

Güçlü:

- Tool-call rozetleri ve gizlilik metni dogru bir AI-UX niyeti tasiyor.
- Oneri chipleri sohbet baslatmayi kolaylastiriyor.

Zayıf:

- V1 kapsamiyla uyumsuz: aktif AI deneyimi gibi.
- "100% gizli" iddiasi cok kesin; KVKK/AI logging acisindan dikkatli yazilmali.
- Chat cevaplari statik keyword matching; kullanici bunu gercek AI sanabilir.

Onerilen revizyon:

- MVP'de "AI Koc yakinda" + waitlist + guvenlik ilkeleri daha dogru.
- AI aktif olacaksa her cevapta kaynak/veri baglami ve "bu bir oneridir" siniri belirtilmeli.
- Yonetici Asistan ve Calisan Sirdas ayrimi UI'da netlesmeli.

### Menu

Güçlü:

- Gruplama anlasilir: IK Yonetimi, Calisan Surecleri, Tanim & Kurulum, Sistem.
- Profil karti kullanici baglami veriyor.

Zayıf:

- V1 bilgi mimarisiyle uyum tam degil: Haklar & Uyum yok, Raporlar yok, AI menu grubu yok.
- Admin kurulum ekranlari ile calisan surecleri ayni profil icinde karisik.
- Generic placeholder kullanan 14 satir gercek modul izlenimi veriyor.

Onerilen revizyon:

- Role-based menu: Calisan, Yonetici, IK Admin, Patron icin ayri item seti.
- Placeholder modullere "Yakinda" badge'i; tiklayinca roadmap/aciklama, bos insaat ekrani degil.
- ERP satiri Canias + pasif placeholder olmalı.

## 4. UI Tasarim Degerlendirmesi

### Marka ve Dil

Artifact'in gorsel dili Apple iOS + emoji karisimi. Bu mobilde tanidik hissettiriyor ama Turkiye KOBI HR icin fazla genel ve yer yer amatör duruyor. PULS'un ozgun dili; lime accent, daha rafine ikonografi, shadcn-style component seti ve daha sakin data yogunlugu uzerinden kurulmalı.

### Renk

Renk paleti iOS sistem renklerine cok yakin: `#34C759`, `#007AFF`, `#FF9500`, `#AF52DE`. Bu hizli prototipte tamam ama markaya ait degil. V1 dokumanindaki lime/electric/violet tokenlariyla yeniden hizalanmali.

### Tipografi

DM Sans + IBM Plex Mono secimi fena degil; ancak V1 dokumaninda Familjen Grotesk + Space Mono yaziyor. Yerel app TanStack/Tailwind/shadcn hattinda hangi font setinin kalici olacagi sabitlenmeli.

### Ikonografi

Emoji ikonlar demo anlatiminda sevimli, ama enterprise HR'da guven erozyonu yaratabilir. Ozellikle finans, KVKK, sozlesme ve performans gibi ciddi alanlarda Lucide ikonlari daha uygun.

### Etkileşim

Sheet pattern dogru; fakat tum aksiyonlar local UI kapanisi seviyesinde. Basarili kayit, hata, loading, disabled, optimistic update, audit trail gibi production state'ler yok.

## 5. V1 Dokumanlariyla Uyum

Uyumlu noktalar:

- Mobile-first alt navigasyon fikri var.
- Izin, masraf, performans/kariyer/AI modulleri terminoloji olarak mevcut.
- Dark mode var.
- Koc gizlilik metni, V1 audit'te ovulen privacy sinyalini sürdürüyor.

Uyumsuz noktalar:

- V1 mobile shell bottom tab: Dashboard, Izin, Masraf, Bildirim, Profil. Artifact: Ana Sayfa, Izin, Masraf, Koc, Menu.
- V1 AI Koc: V2 placeholder. Artifact: aktif chat.
- V1 ERP pilot: Canias. Artifact: Logo Tiger bagli.
- V1 Masraf: AI OCR akisi. Artifact: sadece upload alanı.
- V1 Izin: 6 ekran ve 8 izin tipi. Artifact: tek ekran + tek bottom sheet + 3 izin tipi.
- V1 Raporlar, Haklar & Uyum, Sözleşmeler ve People detaylari artifact'ta gercek ekran degil.

## 6. Oncelikli Aksiyon Listesi

1. Artifact'i "tasarim referansi" olarak kullan, dogrudan implementasyon kaynagi yapma.
2. Bilgi mimarisini sabitle: V1'de gercek bottom tab ve sidebar gruplari ne olacak?
3. Persona kararini UI'ya indir: Calisan modu ve Yonetici/IK modu farkli ekranlar gormeli.
4. Mevcut local MVP ile uyumlu demo data seti kullan: Mert Teknik, 4 calisan, 3 departman, Canias pasif.
5. Placeholder ekranlari ayrica isaretle; gercek modül sanilmasin.
6. Hamburger/drawer bug'ini temizle.
7. Emoji ikonlari Lucide/shadcn ikon sistemine cevir.
8. Izin ve masraf formlarini domain kurallariyla yeniden tasarla.
9. AI Koc'u V1 icin teaser/waitlist veya sadece floating contextual helper olarak sinirla.
10. Tasarim tokenlarini repo ile ayni hale getir: Tailwind v4, shadcn-style UI, tr-TR default.

## 7. MVP Icin Tasarim Yon Karari

Benim onerim: Bu artifact'i "mobil konsept / moodboard" olarak tutmak, ama urun ekran haritasi olarak kabul etmemek. Ekran envanteri cikti; fakat production backlog icin V1 dokumanlari + mevcut local app daha guvenilir kaynak.

MVP-1 icin en dogru ekran seti:

- Login
- Dashboard role-aware
- Performans listesi + donem CRUD
- Izin ozet + talep
- Masraf ozet + yeni masraf placeholder
- Menu / Profil
- AI Koc floating teaser

Sonraki sprintlerde detaylar:

- People/Calisanlar
- Sözleşme/Belge
- Haklar & Uyum/Kale
- Kariyer/Harita
- AI Koc vault/tool-call
