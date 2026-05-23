# PULS Data Contracts

Bu klasor, UI migration sonrasinda production veri katmanina gecis icin alan bazli veri sahipligi dokumanlarini tutar.

## Dosyalar

- `PULS_FIELD_OWNERSHIP_MATRIX.csv`: Route ve ekran bloklarina gore her alanin source-of-truth, canonical tablo, calculation owner, RLS scope, demo fallback ve write-back kararlarini listeler.

## Ana Ilkeler

- PULS ERP/HR replacement degildir; mevcut sistemlerin uzerinde calisan self-HR ve AI destekli intelligence katmanidir.
- Ham ERP data lake kurulmaz.
- MVP'de hassas bordro ve ozel nitelikli ozluk verileri alinmaz.
- UI metrikleri ve product intelligence alanlari PULS calculation layer tarafindan sahiplenilir.
- Demo fallback production davranisi degildir; sadece dev/demo flag ile kullanilir.

