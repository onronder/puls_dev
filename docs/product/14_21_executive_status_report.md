# PULS Yönetici Durum Raporu

Tarih: 4 Haziran 2026

## Yönetici Özeti

PULS, erken ürün paketleme aşamasından veri destekli ve anlatısı netleşmiş bir ürün temelinin üzerine taşındı. Uygulamada artık çalışan demo tenant'ı, gerçek tenant ayrımı, role göre erişim, veritabanı destekli ekranlar, AI Coach bağlam hazırlığı ve kaynak bağımsız veri bağlantısı çalışma alanı bulunuyor.

Mevcut ürün; kontrollü ürün demoları, satış ekibi hazırlığı ve müşteri keşif görüşmeleri için anlamlı bir seviyeye geldi. Ancak henüz canlı müşteri entegrasyonu ürünü olarak konumlandırılmamalı. Gerçek connector runtime, güvenli credential saklama, import çalıştırma, arka plan işleri, bildirimler ve rollback süreçleri bilinçli olarak kapalı tutuluyor.

En önemli ürün kararı netleşti: PULS, yalnızca Canias için geliştirilmiş bir ürün değil. Canias ilk connector profili. Ürün mimarisi; PULS canonical data modeli, unified source namespace'ler, domain bazlı kaynak sahipliği ve ERP, CSV / Excel, custom API, SFTP veya gelecekteki farklı connector'lardan güvenli veri aktarımı üzerine kuruluyor.

## Genel Tamamlanma Tahmini

| Alan | Tahmini tamamlanma | Durum |
| --- | ---: | --- |
| Ürün temeli ve paketleme | %85 | Güçlü temel oluştu |
| DB destekli demo ve tenant kanıtı | %90 | Remote proof tenant ve empty tenant doğrulandı |
| Core HR ekran hazırlığı | %75 | Ana operasyon ekranları demo data ile kullanılabilir; son polish ve derin workflow'lar kalıyor |
| AI Coach hazırlığı | %60 | Bağlam ve guardrail hazır; live LLM/chat ve aksiyon çalıştırma gelecek faz |
| Connector setup ve pre-runtime kontrol katmanı | %80 | Setup, mapping, preflight, credential boundary, preview, approval ve kapalı apply contract modellendi |
| Gerçek connector runtime hazırlığı | %25 | Runtime mimarisi hazırlandı; canlı connector çalıştırma başlamadı |
| Gerçek connector olmadan kontrollü demo hazırlığı | %80 | Guided demo ve ürün anlatısı için güçlü seviye |
| Gerçek connector destekli canlı müşteri rollout | %55 | PR15-PR16 runtime, credential, execution ve operasyon işleri gerekiyor |

Pratik özet: PULS, gerçek connector olmadan kontrollü demo ve customer discovery için yaklaşık **%80 hazır**. Gerçek connector destekli canlı müşteri rollout için yaklaşık **%55 hazır**.

## Şu Ana Kadar Tamamlananlar

### 1. Ürün Kapsamı Ve Konumlandırma

PULS'un ürün kapsamı başlangıca göre çok daha net. Ürün artık dış veri kaynaklarına bağlanan, bu verileri canonical modele eşleyen ve workflow sahipliğini PULS içinde tutan bir HR operations layer olarak konumlanıyor.

Mevcut ürün iddiası kaynak bağımsız: Bir müşteri organizasyon verisini Canias'tan, tek seferlik aktarımı CSV / Excel'den, masraf veya başka operasyonel verileri ise farklı bir sistemden besleyebilir.

### 2. DB Destekli Demo Temeli

Ana ürün hikayesi artık yalnızca statik frontend fixture'larına bağlı değil. Çalışanlar, departmanlar, pozisyonlar, cost center'lar, izin ve masraf süreçleri, performans verileri, sözleşmeler, onay senaryoları, ERP metadata, source namespace ve identity mapping içeren gerçekçi bir demo data temeli var.

Puls Teknik A.S. seeded proof tenant olarak kullanılıyor. PULS Connector Lab ise empty onboarding tenant olarak kullanılıyor. Birlikte iki kritik satış hikayesini kanıtlıyorlar: operasyon verisi dolu mevcut şirket ve connector seçmeden ürüne başlayan yeni müşteri.

### 3. Rol Ve Tenant Kanıtı

Ürün artık demo ve QA için daha net bir rol/tenant modeline sahip. Admin, manager, HR ve employee postürleri ana route'larda test edildi. Empty connector tenant, seeded proof tenant'tan ayrı tutuluyor. Bu da demo datasının canlı müşteri durumu gibi yanlış anlaşılması riskini azaltıyor.

### 4. Core Uygulama Hazırlığı

Ana ürün yüzeyleri tutarlı bir uygulama hissine yaklaştı:

- Dashboard
- Çalışanlar
- Departmanlar ve pozisyonlar
- İzin
- Masraf
- Performans
- Sözleşmeler
- Tanım, kurulum ve ayarlar
- ERP / veri bağlantıları
- AI Coach

Ürün her workflow'da tamamen feature-complete değil. Ancak ana ekranlar artık DB destekli data ile tutarlı bir ürün hikayesi anlatabiliyor.

### 5. AI Coach Hazırlığı

AI Coach, statik teaser olmaktan çıkıp DB context readiness seviyesine geldi. Hangi operasyonel domain'lerin hazır, kısmi veya bloklu olduğunu gösterebiliyor. Guardrail'ler net: otonom workflow aksiyonu yok, ERP yazma yok, gizli live chat yok, insan onayı zorunlu.

Bu sayede AI anlatısı satış tarafında güvenilir hale geliyor; live LLM otomasyonu varmış gibi fazla iddialı bir konumlandırma yapılmıyor.

### 6. Connector Temeli

ERP / veri bağlantısı alanı PR14 ile ürünün en güçlü omurgası haline geldi. Bugün şu yetenekleri destekliyor:

- Empty connector onboarding
- Provider seçimi
- Kalıcı setup state'i
- Kaynak bağımsız lifecycle postürü
- Mapping discovery
- Domain ownership
- Preflight kontrolleri
- Credential boundary ve güvenli handoff talebi
- Güvenli activity timeline
- Dry-run import preview
- Human review boundary
- Admin approval policy
- Kapalı apply execution contract
- Tab'li workbench UX

Ürün artık veri hareket etmeden önce hangi adımların tamamlanması gerektiğini açıklayabiliyor. Bu, production-grade connectivity yolunda kritik bir eşik.

### 7. Kalite Ve Observability

Frontend hata gözlemlenebilirliği için Sentry eklendi ve setup event'i doğrulandı. Type safety, i18n, unit test, build, sensitive grep, Playwright smoke, secret varsa authenticated e2e ve PR bazlı verify script'leri artık kalite kapısının parçası.

Bu, tüm risklerin kapandığı anlamına gelmiyor. Ancak proje informal testlerden tekrar edilebilir kalite kontrol sürecine geçti.

## Satış Ekibi İçin Güncel Ürün Anlatısı

PULS bugün şu şekilde anlatılabilir:

> PULS, insan operasyonlarını, workflow görünürlüğünü ve gelecekteki AI desteğini canonical data modeli etrafında merkezileştiren kaynak bağımsız bir HR operations platformudur. Dış veri bağlantılarını canlı connector runtime açılmadan önce hazırlayabilir, doğrulayabilir ve güvenli şekilde incelemeye alabilir.

Bugün güvenle gösterilebilecekler:

- Operasyon datası dolu gerçekçi şirket tenant'ı
- Kuruluma sıfırdan başlayan empty customer tenant
- Role göre erişim ve route davranışı
- AI Coach readiness ve guardrail'leri
- ERP / veri bağlantısı setup workbench'i
- Mapping, preflight, credential handoff, preview ve approval sınırları
- Live connector runtime'ın sonraki faz olduğu konusunda açık ve dürüst ürün dili

Bugün iddia edilmemesi gerekenler:

- Canias API bağlantısı canlı ve tamamlandı
- CSV / Excel import execution tamamlandı
- PULS bugün ERP'ye yazabiliyor
- Credential'lar bugün saklanıyor ve doğrulanıyor
- AI Coach bugün otonom onay, oluşturma, sync veya yazma aksiyonları çalıştırabiliyor
- Notification Center ve rollback operasyonları tamamlandı

## Açık Ana Riskler

| Risk | Anlamı | Mevcut önlem |
| --- | --- | --- |
| Gerçek connector runtime henüz yok | Canlı API veya dosya connector'ı çalışmıyor | PR14 runtime öncesi güvenli sınırları modelledi |
| Credential storage henüz yok | Güvenli secret capture ve saklama gelecek fazda | Ürün yalnızca güvenli referans state'i tutuyor |
| Import apply açık değil | Preview var, canonical write kapalı | Apply gate'leri ve approval policy görünür |
| Bazı ekranlarda derin workflow eksikleri var | Ana yüzeyler hazır, tüm iş akışları tam değil | QA ve route matrix closeout için rehber kalıyor |
| Satışta fazla iddia riski | Ürün advanced görünüyor ama runtime yok | Dil net olmalı: "connector runtime fazına hazır", "live integrated" değil |

## Önerilen PR15-PR16 Planı

Detaylı geliştirme planı: [15_16_connector_runtime_ai_roadmap.md](./15_16_connector_runtime_ai_roadmap.md)

### PR15: Connector Runtime Control Plane

Amaç: çok tenant'lı ve çok connector'lü runtime omurgasını gerçek veri yazma açmadan kurmak.

Önerilen işler:

- DB-backed connector job queue
- Railway worker skeleton
- Job ownership, run status ve concurrency kuralları
- Retry, backoff, dead-letter ve failure classification
- Runtime-safe Sentry logging ve scrubbing
- Operator-visible runtime logları
- Güvenli credential capture ve secret storage boundary
- No-readback credential modeli
- Backend/server-side secret resolution
- Runtime preflight with credential reference
- AI runtime evidence contract

İş sonucu: PULS connector işlerini browser'dan bağımsız şekilde kuyruğa alabilecek, worker ile çalıştırabilecek, hata/retry/log state'lerini güvenli tutabilecek ve AI için güvenli operasyon sinyalleri üretebilecek.

### PR16: First Controlled Data Movement

Amaç: PR15 runtime omurgası üzerinde ilk gerçek veri hareketini kontrollü, auditable ve rollback-aware şekilde açmak.

Önerilen işler:

- İlk kontrollü apply path olarak CSV / Excel import execution
- Batch lock ve idempotency enforcement
- Canonical write audit trail
- Rollback veya compensating-action tasarımı
- Apply öncesi admin approval enforcement
- Import sonuçları için Notification Center delivery
- Generic apply path kanıtlandıktan sonra Canias runtime spike
- Canias, Logo, Custom API, SFTP gibi provider-specific connector contract'leri
- AI operational recommendations

İş sonucu: PULS, kontrollü approval, audit ve recovery ile canonical modele gerçek veri hareketi gösterebilecek; AI Coach ise connector, import ve canonical data sonuçlarından güvenli öneriler üretebilecek.

## Gerçek Müşteri Connector Go-Live Öncesi Yapılması Gerekenler

- Müşteri kaynak sistemi ve domain bazlı data ownership netleştirilmeli
- Required field ve mapping coverage tamamlanmalı
- Credential'lar yalnızca güvenli server-side flow ile alınmalı
- Gerçek credential ile connector preflight çalıştırılmalı
- Gerçek müşteri datası üzerinde dry-run preview yapılmalı
- Create / update / skip sonuçları müşteri paydaşlarıyla incelenmeli
- Admin-only policy ile apply onayı alınmalı
- Audit, notification ve rollback planıyla controlled import çalıştırılmalı
- İlk production run Sentry ve connector activity loglarıyla izlenmeli
- Go-live sonrası destek, retry ve sorumluluk süreci netleştirilmeli

## Final Değerlendirme

PR14 tamamlanmış kabul edilebilir. PR14, connector control plane'i oluşturdu ve `/erp` sayfasını profesyonel bir workbench haline getirdi. Bundan sonra daha fazla pre-runtime açıklama katmanı eklemek yerine gerçek operasyonel temele geçmek daha doğru: secrets, runtime jobs, controlled execution, notifications ve sonunda ilk gerçek connector.

Ürün bugün guided executive demo ve customer discovery için güçlü seviyede. Ancak ürün dili dürüst kalmalı: PULS gerçek connector runtime fazına hazırlandı; henüz müşteri ERP'siyle canlı entegre çalışan bir ürün değildir.
