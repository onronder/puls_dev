# PULS Sayfa Sayfa Migration Kuralları

Bu doküman, Lovable prototipindeki ekranları ana PULS uygulamasına tek tek ve kaçakları azaltarak taşımak için standarttır.

## Temel İlke

Artık büyük “Faz 2 yap” prompt’u yok. Her PR tek ekran veya en fazla birbirine çok bağlı iki küçük ekran içerir.

Her ekran prompt’u şunları içermeli:

1. Hedef route ve kapsam dışı route’lar.
2. Lovable kaynak route kodu.
3. Lovable kaynak demo-data parçaları.
4. Ana projede kullanılacak mevcut componentler.
5. Ana projede dokunulabilecek dosyaların tam listesi.
6. UI/UX kabul kriterleri.
7. Mobile kabul kriterleri.
8. Data stratejisi: Supabase query mi, izole demo adapter mı.
9. Kaçak önleme: başka route, auth, layout, i18n ve navigation davranışı bozulmayacak.
10. Test komutları.

## PR Boyutu

Bir PR tek hedefe sahip olmalı:

- Doğru: `/erp` ekranını ekle.
- Yanlış: `/erp`, `/departmanlar`, `/pozisyonlar`, `/ayarlar` ve DB migration hepsini ekle.

## Ana Projede Korunacaklar

- `src/routes/_app.tsx` auth guard.
- `src/lib/auth.tsx` ve persona toggle davranışı.
- `src/lib/persona.ts` persona çözümleme.
- Import alias: `#/...`
- i18n dosyaları: `src/i18n/locales/tr-TR.json`, `src/i18n/locales/en-US.json`
- Faz 1 componentleri:
  - `PageHeader`
  - `SectionHeader`
  - `MetricCard`
  - `StatusPill`
  - `DataList`
  - `EmptyState`
  - `SheetShell`
  - `FormField`
  - `Segmented`

## Standart Test

Her PR sonunda:

```bash
pnpm typecheck
pnpm exec eslint src
pnpm build
pnpm check-i18n
```

Ek olarak route smoke:

- Hedef route 404 vermemeli.
- Mobile bottom tab kırılmamalı.
- Desktop sidebar kırılmamalı.
- Hedef route 390px genişlikte horizontal overflow üretmemeli.
- Sayfada `Hello "/_app/...!"` stub kalmamalı.

## UI/UX Standartları

- Touch target minimum 44px.
- Input font-size 16px.
- Body text 13-14px altına düşmemeli.
- Metadata label 11px altına düşmemeli.
- Ana CTA tek ve net olmalı.
- Toast tek başına işlem yerine geçmemeli; MVP-2 işlevler disabled/teaser olmalı.
- AI Koç aktif chat gibi davranmamalı.
- Her sayfada net H1, kısa açıklama, gerekiyorsa durum pill’i ve ana metrik alanı olmalı.

## Demo Data Stratejisi

- Supabase tablosu varsa query yaz.
- Supabase tablosu yoksa `src/lib/demo/puls-demo-data.ts` içine izole demo adapter ekle.
- Route component içine büyük statik veri gömülmez.
- Demo adapter gerçek DB’ye geçince kolay silinebilir olmalı.

## Sıralama

Önerilen sırayla ekran taşıma:

1. `/erp`
2. `/sirket-kurulum`
3. `/departmanlar`
4. `/pozisyonlar`
5. `/izin-tanimlari`
6. `/masraf-kategorileri`
7. `/performans-parametreleri`
8. `/kariyer`
9. `/egitim`
10. `/is-degerleme`
11. `/sozlesmeler`
12. `/ai-koc`
13. `/profil`
14. `/ayarlar`

