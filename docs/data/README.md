# PULS Data Contracts

Bu klasor, UI migration sonrasinda production veri katmanina gecis icin alan bazli veri sahipligi dokumanlarini tutar.

## Dosyalar

- `PULS_DATA_SOURCE_CALCULATION_OWNERSHIP_CONTRACT.md`: PULS'un ERP/HR replacement olmadigini, veri siniflarini, source-of-truth kararlarini, hesaplama sahipligini ve ekran bazli veri sahipligini tanimlar.
- `PULS_TECHNICAL_IMPLEMENTATION_PLAN.md`: Supabase schema, RLS, frontend data adapter, Railway ERP connector, migration sirasi ve QA stratejisini tanimlar.
- `PULS_FIELD_OWNERSHIP_MATRIX.csv`: Route ve ekran bloklarina gore her alanin source-of-truth, canonical tablo, calculation owner, RLS scope, demo fallback ve write-back kararlarini listeler.
- `11_sidebar_data_api_inventory.md`: Sidebar ve setup route veri/API envanteri, demo sinirlari, mutation/RPC katalogu ve PR11.1–PR11.9 sahiplik haritasi.

## Ana Ilkeler

- PULS ERP/HR replacement degildir; mevcut sistemlerin uzerinde calisan self-HR ve AI destekli intelligence katmanidir.
- Ham ERP data lake kurulmaz.
- MVP'de hassas bordro ve ozel nitelikli ozluk verileri alinmaz.
- UI metrikleri ve product intelligence alanlari PULS calculation layer tarafindan sahiplenilir.
- Demo fallback production davranisi degildir; sadece dev/demo flag ile kullanilir.

## Mevcut Kararlar

- Ilk gercek implementasyon adimi `01-db-schema-foundation` olarak ele alinacak; `PULS_FIELD_OWNERSHIP_MATRIX.csv` dokumantasyon fazi olarak tamamlanmistir.
- Schema foundation migration: `supabase/migrations/20260523143000_puls_schema_foundation.sql` (`puls_core`, `puls_integration`, `puls_audit`).
- Workflow leave/expense migration: `supabase/migrations/20260523160000_puls_workflow_leave_expense.sql` (`puls_workflow`, bootstrap bridge, demo seed).
- Performance/contracts/calc migration: `supabase/migrations/20260523170000_puls_performance_contracts_summary.sql` (`puls_performance`, `puls_calc`, contract metadata, demo seed).
- Yeni production veri modeli icin temiz PULS namespace/schema hedeflenir: `puls_core`, `puls_workflow`, `puls_performance`, `puls_integration`, `puls_calc`, `puls_audit`, `puls_vault`.
- Mevcut Lovable/public tablolar migration gecmisi olarak korunur; yeni hedef model adapter katmani ile soyutlanir.
- Varsayilan sync yonu `ERP -> PULS` read-oriented akistir; write-back kapali baslar ve tenant bazli karar ister.
- `/haklar-uyum` bu data fazina dahil degildir; route ve matrix kapsamina alinmamistir.

## Referanslar

- V1 veri sozlugu repo icinde mevcuttur: `docs/V1 Dokümanlar/Puls_Veri_Sozlugu_v1.0.xlsx`.
- Metrik katalogu: `docs/specs/06-metrik-ve-demo-data-katalogu.csv`.
- Demo data ihtiyaclari: `docs/specs/07-supabase-demo-data-ihtiyaclari.md`.
