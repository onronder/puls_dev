# PULS Lovable Page Prompt Pack

Bu klasör Lovable prototipindeki ekranları ana PULS uygulamasına sayfa sayfa taşımak için hazırlanmış prompt paketidir.

Genel kurallar:

- Önce `00-page-migration-rules.md` okunmalı.
- Her prompt tek route içindir.
- Büyük Faz prompt’u kullanılmamalı.
- PR sonunda route smoke + typecheck/lint/build/i18n çalıştırılmalı.

## Prompt Sırası

- `00-page-migration-rules.md` — genel migration kuralları
- `01-erp-route-prompt.md` — /erp
- `02-sirket-kurulum-prompt.md` — /sirket-kurulum
- `03-departmanlar-prompt.md` — /departmanlar
- `04-pozisyonlar-prompt.md` — /pozisyonlar
- `05-izin-tanimlari-prompt.md` — /izin-tanimlari
- `06-masraf-kategorileri-prompt.md` — /masraf-kategorileri
- `07-performans-parametreleri-prompt.md` — /performans-parametreleri
- `08-kariyer-prompt.md` — /kariyer
- `09-egitim-prompt.md` — /egitim
- `10-is-degerleme-prompt.md` — /is-degerleme
- `11-sozlesmeler-prompt.md` — /sozlesmeler
- `12-ai-koc-prompt.md` — /ai-koc
- `13-profil-prompt.md` — /profil
- `14-ayarlar-prompt.md` — /ayarlar
- `15-dashboard-parity-prompt.md` — /dashboard
- `16-performans-parity-prompt.md` — /performans
- `17-calisanlar-parity-prompt.md` — /calisanlar
- `18-izin-parity-prompt.md` — /izin
- `19-masraf-parity-prompt.md` — /masraf
- `20-menu-parity-prompt.md` — /menu

## Önerilen Uygulama Sırası

1. Tanım & Kurulum ekranları: /erp, /sirket-kurulum, /departmanlar, /pozisyonlar, /izin-tanimlari, /masraf-kategorileri, /performans-parametreleri
2. Derin HR ekranları: /kariyer, /egitim, /is-degerleme, /sozlesmeler
3. Sistem/AI ekranları: /ai-koc, /profil, /ayarlar
4. Parity ekranları: /dashboard, /performans, /calisanlar, /izin, /masraf, /menu
