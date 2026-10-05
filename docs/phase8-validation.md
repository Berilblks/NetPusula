# Faz 8 doğrulama raporu

Son rapor: 5 Ekim 2026. Faz 8 değişiklikleri incelenmek üzere uncommitted bırakıldı. Başlangıç ve bitiş HEAD: `1fbef32 feat: add performance dashboard`, branch `main`. Commit, push, history rewrite veya migration oluşturulmadı.

## Uygulanan kapsam

`GET /api/statistics?range=5|10|20|all` ve `/statistics` ekranı tamamlandı. Varsayılan 20, all sınırı 500; sınır bütün analizlere uygulanır ve metadata/UI ile açıklanır. Toplam/bölüm son/ortalama/en yüksek/en düşük net, en iyi deneme, bölüm serileri, cevap ortalamaları/tarihçesi, kısa vadeli değişim ve deneme aralığı sunucu tarafından hesaplanır. Kesin tanımlar [advanced-statistics.md](advanced-statistics.md) içindedir.

Dashboard yalnız giriş bağlantısı kazandı. Ortak DecimalAggregate son-altı karşılaştırmasını ve özet hesaplarını paylaşır; Faz 7 DTO sözleşmesi korunur. Mevcut özel çizgi grafiği opsiyonel hedefle yeniden kullanılır. Yeni paket yoktur.

## Komut sonuçları

| Kontrol | Sonuç |
| --- | --- |
| `dotnet restore` | Başarılı; tüm projeler güncel |
| `dotnet build --no-restore` | Başarılı; 0 uyarı, 0 hata |
| `dotnet test --no-build` | **183/183**; önceki 147 + yeni 36 |
| `dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure` | Bekleyen model değişikliği yok |
| `flutter pub get` | Başarılı; bağımlılık sürümleri değiştirilmedi |
| `flutter gen-l10n` | Başarılı; mevcut generated source konvansiyonu korundu |
| `flutter analyze` | No issues found |
| `flutter test --reporter expanded` | **173/173**; önceki 133 + yeni 40 |
| Android debug APK | Başarılı; mevcut geliştirme dart-defines ile |
| `git diff --check` | Temiz |

APK komutu: `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=ALLOW_INSECURE_HTTP=true`. APK ve test logları `mobile/build/` altında ignored kalır. Release/signing yapılmadı.

Ara kontrollerde giderilen bulgular: yanlış dizinden başlatılan bir dotnet build proje bulamadı; yeni testte expression tree içinde `^1` kullanımı derlenmedi, normal index'e çevrildi. İlk Flutter analizindeki üç brace bildirimi ve bir unused import düzeltildi. İlk widget koşusunda navigation loading frame testi bir frame erken bakıyordu; kontrollü pump eklendi. Cevap çubuklarında birleşen semantics ayrı container'larla düzeltildi. Son tam koşular hatasızdır.

Gizlenmeyen araç bildirimleri: pub get, constraint dışı 37 yeni paket sürümü bulunduğunu bildirdi; yükseltme yapılmadı. Flutter APK derlemesi Android x86 desteğinin gelecekte kaldırılacağına dair SDK bildirimi verdi. Bunlar analiz/derleme hatası değildir.

## Backend kapsamı — 36 yeni test vakası

- JWT ve aktif hazırlık gerekliliği; yabancı kullanıcı/inaktif hazırlık dışlama; arbitrary UserId/UserExamId ve geçersiz/tekrarlı range reddi.
- Sıfır/tek kayıt, varsayılan ve 5/10/20/all aralıkları; 500/501 sınırında cap metadata ve agregaların tutarlılığı.
- Tarih sırası, aynı gün CreatedAtUtc/Id bağlayıcısı; son/ortalama/en iyi/en kötü; en iyi net eşitliği.
- Decimal bölen 3/4/8, negatif net, snapshot korunması, doğru/yanlış/boş kesirli ortalamaları.
- Yetersiz/tam altı/altıdan fazla kısa vadeli karşılaştırma; dashboard ile aynı sonuç; negatif değişim.
- Bölüm kimliği/ad değişimi, yeni gruplu sonuçsuz bölüm, eksik tarihsel sonuç ve inaktif snapshot gösterimi.
- İlk/son tarih, tek kayıtta null aralık, aynı gün sıfır ve kesirli ortalama aralık.
- Güvenli DTO, iç içe decimal-string alanlar ve integer adetler.

## Flutter kapsamı — 40 yeni test

Dashboard girişi, loading/empty/tek kayıt, ağ/sunucu/hazırlık hataları ve retry; dört filtre, hızlı filtre değişimi ve eski yanıt koruması; genel/bölüm metrikleri; en iyi denemeden mevcut detay rotası; sıfır/tek/çok nokta ve negatif grafik; gruplu bölüm seçimi ve sonuçsuz bölüm; cevap ortalamaları/semantics/tarihçesi; pozitif/negatif/yetersiz değişim; aktivite ve sıfır gün aralığı; cap açıklaması; pull-to-refresh; create/edit/delete invalidation; logout ve yeni kullanıcıya geçerken eski veri koruması; detaydan dönüşte filtre; 320px ekran/2× metin; strict decimal parsing ve geçersiz verinin boş sayılmaması.

## Gerçek PostgreSQL

İzole Compose projesi `netpusula-phase8`, PostgreSQL 16-alpine, loopback port 55438, geçici API port 5088 kullanıldı. Kimlik bilgileri çalışma anında rastgele üretildi ve raporlanmadı. Kullanıcının mevcut `postgres-db` konteyneri/5432 ortamı değiştirilmedi.

Mevcut dört migration boş veritabanına uygulandı. Gerçek HTTP API üzerinden:

- Boş istatistiklerde null ve tek kayıtta net sözleşmesi.
- İki bölüm ve doğru decimal toplam.
- Başka kullanıcı ve önceki hazırlığın dışlanması.
- 25 deneme üzerinde 5/10/20/all sayıları, net ortalamaları, best/worst, kronolojik seriler, cevap ortalamaları, aralık ve kısa vadeli değişimler.
- Bir tarihsel bölüm sonucu eksik olduğunda doğru payda/son değer/seri.
- Bölen 3 ile negatif net: Phase 6 toplam ve bölüm decimal metniyle birebir eşitlik.
- Aynı gün ve aynı CreatedAtUtc ile UUID sırası, en iyi eşitlik bağlayıcısı ve sıfır gün aralığı.
- 401 ve istemcinin scope/geçersiz range girişlerinin 400 olması.
- Son model kontrolünde bekleyen migration olmaması.

SQL command logunda her başarılı statistics isteğinde **dört DbCommand** görüldü. Son komutun deneme LIMIT alt sorgusu sonuç LEFT JOIN'inden önceydi; bölüm başına query yoktu. SQL/credential içerikleri rapora kopyalanmadı. 500/501 cap sınırı ilişkisel otomatik testte doğrulandı; PostgreSQL üzerinde 25 denemelik gerçek API senaryosu çalıştırıldı. Yük testi yapılmadı.

Son API sözleşmesindeki `sufficientData` alanıyla gerçek PostgreSQL koşusu tekrar başarılı oldu. Her koşudan sonra geçici API durduruldu, yalnız bu Compose projesinin konteyneri ve volume'u kaldırıldı. Geçici script/loglar da Git metadata dizininden temizlendi.

## Güvenlik ve Git

Changed/untracked aday dosyalar private key, JWT/GitHub/API token ve literal credential desenleri açısından incelendi. Yeni backend testindeki açıkça sentetik fixture parolası dışında gerçek secret bulunmadı. Runtime PostgreSQL/JWT değerleri source'a veya .env'ye yazılmadı. DTO projection'ları entity serialize etmez; endpoint kullanıcı/hazırlık seçicisi kabul etmez; auth kapsamı backend'de zorunludur. SQL hataları mevcut global güvenli hata işleyicisinden geçer. Token loglama eklenmedi.

Mevcut .gitignore değişmedi. bin/obj, mobile/build, .dart_tool, APK, log ve SQL validation çıktı yollarının ignore durumu doğrulandı. Generated localization Dart dosyaları mevcut takip konvansiyonuna uygun tutuldu. Stage/commit/push yapılmadı; HEAD ve önceki commitler değişmedi.

## Sınırlar

All, son 500 denemedir; lifetime analytics/export değildir. Farklı tarihsel soru/bölen yapılandırmaları normalize edilmez. Grafik eşit zaman değil deneme sırası eksenidir; tooltip/zoom yoktur. In-memory autoDispose kullanılır, ekrana yeni girişte filtre son 20 olur. O(seçili deneme × bölüm) payload katalog bölüm sayısına bağlıdır. Gerçek cihaz kullanılabilirlik incelemesi ve üretim yük testi yapılmadı; widget/analyze/APK doğrulaması tamamlandı. AI, skor/sıra tahmini, öneri ve Faz 9 uygulanmadı.

Önerilen commit mesajı: `feat: add advanced performance statistics`.

## Değişen dosyalar

Toplam 23 dosya:

- `README.md`
- `backend/src/NetPusula.Api/Program.cs`
- `backend/src/NetPusula.Api/StatisticsEndpoints.cs`
- `backend/src/NetPusula.Application/Statistics/StatisticsContracts.cs`
- `backend/src/NetPusula.Infrastructure/Analytics/DecimalAggregate.cs`
- `backend/src/NetPusula.Infrastructure/Dashboard/DashboardService.cs`
- `backend/src/NetPusula.Infrastructure/DependencyInjection.cs`
- `backend/src/NetPusula.Infrastructure/Statistics/StatisticsService.cs`
- `backend/tests/NetPusula.Tests/StatisticsTests.cs`
- `docs/advanced-statistics.md`
- `docs/architecture.md`
- `docs/phase8-validation.md`
- `mobile/lib/core/routing/app_router.dart`
- `mobile/lib/features/auth/presentation/home_screen.dart`
- `mobile/lib/features/dashboard/presentation/net_trend_chart.dart`
- `mobile/lib/features/mock_exams/application/mock_exam_controller.dart`
- `mobile/lib/features/statistics/application/statistics_provider.dart`
- `mobile/lib/features/statistics/domain/statistics.dart`
- `mobile/lib/features/statistics/presentation/statistics_screen.dart`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_tr.dart`
- `mobile/lib/l10n/app_tr.arb`
- `mobile/test/statistics_test.dart`
