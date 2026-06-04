# PR15.4 Secure Credential Runtime Boundary

Tarih: 4 Haziran 2026

## Executive Summary

PR15.4, connector runtime'a geçmeden önce PULS'un credential sınırını production-grade hale getirir. Canias, Logo, CSV/Excel, SFTP veya custom API fark etmeksizin ürünün ortak kuralı aynıdır: PULS uygulama ekranı secret toplamaz, göstermez veya geri okumaz. Product DB yalnızca server-side secret manager tarafından üretilen opaque reference ve güvenli state bilgisini tutar.

Bu PR provider entegrasyonu yapmaz. Ama ileride gerçek connector geliştirildiğinde worker'ın hangi credential state ile iş başlatabileceğini, hangi state'lerde duracağını ve operatöre hangi güvenli kanıtların gösterileceğini netleştirir.

## Product Boundary

| Alan | PR15.4 kararı |
| --- | --- |
| UI | Secret input, password field, API key field veya connection string alanı yok |
| Client adapter | `credentials_ref` seçmez, göstermez, activity timeline'a taşımaz |
| Product DB | Sadece safe opaque reference formatını kabul eder |
| Runtime worker | Credential değerini değil, sadece service-role boundary üzerinden referans state'ini kullanır |
| AI evidence | AI sadece `missing`, `configured`, `verified`, `failed`, `revoked` gibi güvenli state'leri görür |
| Activity timeline | Credential olayları safe event olarak görünür; secret ve reference değeri görünmez |

## State Model

| State | Anlamı | Runtime etkisi |
| --- | --- | --- |
| `missing` | Bağlantı için gerekli referans henüz yok | Runtime preflight başlatılamaz |
| `configured` | Opaque reference server-side boundary tarafından kaydedildi | Doğrulama bekler |
| `verified` | Referans server-side doğrulandı | Runtime preflight kuyruğa alınabilir |
| `failed` | Doğrulama safe hata sınıfıyla başarısız oldu | Operatör incelemesi gerekir |
| `revoked` | Referans kapatıldı | Bekleyen runtime-preflight işleri iptal edilir; yeni iş başlatılamaz |
| `not_required` | Kaynak tipi credential gerektirmez | Runtime credential blocker uygulanmaz |

## What Changed

- `puls_integration.connector_credential_events` safe credential activity history eklendi.
- `connector_credential_reference_is_safe` ile product DB'ye yalnızca opaque reference formatı kabul edildi.
- `set_connector_credential_reference`, `revoke_connector_credential_reference` ve `mark_connector_credential_verification` service-role-only RPC sınırları eklendi.
- `list_connector_credential_events` tenant-safe read model olarak UI ve AI evidence için açıldı.
- `enqueue_connector_job` runtime-preflight işlerini `missing`, `failed` veya `revoked` credential state'lerinde bloklayacak şekilde güncellendi.
- `/erp` activity timeline credential reference event'lerini secret/readback olmadan göstermeye başladı.

## Explicit Non-Goals

- UI içinde API key, password, token, connection string veya FTP credential toplamak yok.
- Provider API çağrısı yok.
- CSV/Excel apply execution yok.
- Canonical write yok.
- ERP/source writeback yok.
- Secret manager implementation yok; PR15.4 sadece product DB ve runtime boundary sözleşmesini kurar.

## AI And HR Product Value

HR AI'ın güvenilir öneri üretebilmesi için connector olayları güvenli, açıklanabilir ve tenant-scoped olmalı. PR15.4 ile AI, credential değerini görmeden şu sorulara cevap verebilecek kanıta sahip olur:

- Bağlantı neden çalıştırılamıyor?
- Operatörün sıradaki güvenli adımı nedir?
- Bir runtime-preflight credential yüzünden mi bloklandı?
- Referans kapatıldı mı, doğrulandı mı, yoksa yeniden hazırlanmalı mı?

AI bu veriyi yalnızca açıklama, özetleme, gap tespiti ve insan incelemesine hazırlık için kullanır. AI job claim edemez, complete edemez, credential okuyamaz, import apply başlatamaz veya ERP'ye yazamaz.

## Verification

- Secret değerleri app table, Sentry, activity log, adapter response veya UI içinde gösterilmez.
- Service-role-only RPC'ler authenticated veya public rollere açık değildir.
- Tenant operator yalnızca safe credential event read modelini okuyabilir.
- Revoked credential state runtime-preflight enqueue akışını bloklar.
- Verify gate: [`../../scripts/verify-15-secure-credential-runtime-boundary.sh`](../../scripts/verify-15-secure-credential-runtime-boundary.sh)

