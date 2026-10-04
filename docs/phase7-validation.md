# Faz 7 doğrulama — performans dashboard'u

Başlangıç HEAD: `af89bc1 feat: add mock exam tracking`, dal main. Bu fazda commit/push yapılmadı; Faz 8 başlatılmadı.

## Uygulanan kapsam

Tek `GET /api/dashboard` endpoint'i: active-preparation kapsamı, nullable son/ortalama/en iyi net, signed hedef farkı, en fazla 20 chronological trend noktası, en fazla 3 recent mock, stable-ID section istatistikleri ve son 3/önceki 3 ortalama farkı. Snapshot hesap kuralları ve decimal string sözleşmesi korunur. Yeni migration yoktur.

Flutter Home Material 3 dashboard'a dönüştü; özel düz çizgili grafik, hedef referansı, bölüm grupları, boş/yükleme/hata durumları, mevcut detay/geçmiş/ekle rotaları, pull-to-refresh ve mutasyon invalidation'ı hazır. Chart dependency eklenmedi. Tam tanımlar ve tasarım kararları [dashboard-statistics.md](dashboard-statistics.md) içindedir.

## Backend doğrulama

- `dotnet restore`: başarılı.
- `dotnet build --no-restore`: başarılı; 0 uyarı, 0 hata.
- `dotnet test --no-build`: **147 geçti**, 0 başarısız/atlanan. Önceki 120 + yeni 27 test vakası.
- `dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure`: bekleyen model değişikliği yok.

Yeni testler auth/no-active; query parametresiyle kullanıcı/hazırlık enjeksiyonunun kapsamı değiştirmemesi; diğer kullanıcı/inaktif hazırlık dışlama; boş/null ve gerçek sıfır; tek/çoklu deneme; pozitif/sıfır/negatif hedef farkı; TakenAt ve aynı gün CreatedAt/Id tie-break; chronological/bounded trend ve son 3; 1/5/6/7/25 deneme comparison pencereleri; negatif değişim; section latest/average/best/missing result; yeni/gruplu/inaktif section; sabit kimlik/ad değişimi; divisor 3/4/8 decimal hassasiyeti ve negatif net; Türkiye gün/today/past/future; güvenli DTO ve integer count/decimal string JSON sözleşmesini kapsar.

## Flutter doğrulama

Yeni dashboard dosyasında **32 test** geçti. Önceki **101 test** dahil birleşik Flutter paketi **133/133** geçti. Final analyze/APK sonucu aşağıdaki son kontrol bölümünde yer alır.

Yeni testler loading/populated, greeting/preparation, son/ortalama/en iyi, hedef kalan/eşit/aşım, zero-data CTA, tek/çok nokta grafiği, target çizgisi/semantics, negatif/büyük net, section/grup/no-data, pozitif/negatif/yetersiz improvement, recent/detail/history/add navigasyonu, pull-to-refresh, ağ/5xx/no-preparation ayrımı + retry, create/edit/delete invalidation, geç yanıt sırasında logout, küçük ekran/büyük yazı ve decimal parsing'i kapsar. Önceki test assertion'ları korunmuştur; ortak harness'e yeni endpoint fixture'ı eklenmiştir. Testlerde keyfi sleep/delay yoktur; pending API repository Future'ları Completer ile kontrol edilir.

Geliştirme sırasında analyzer uyarıları, SemanticsHandle test cleanup'ı ve başlangıç auth akışıyla çakışan logout fixture zamanlaması düzeltildi. Son geçen sonuçlar raporlanır; product hata mesajları raw exception içermez.

## Gerçek PostgreSQL

Docker Engine 29.2.0; mevcut Compose `postgres:16-alpine` imajıyla ayrı `netpusula-phase7` proje/container/volume, yalnız 127.0.0.1:55437 üzerinde geçici veritabanı oluşturuldu. Mevcut kullanıcı PostgreSQL ortamına dokunulmadı. Dört migration boş veritabanına başarıyla uygulandı, pending-model kontrolü temiz.

.NET API 127.0.0.1:5087 üzerinde yalnız yerel env ile başlatıldı. Kontroller gerçekten çalıştırıldı:

- Auth zorunluluğu, no-active 409, iki ayrı kullanıcı ve ALES hazırlıkları.
- Sıfır denemede tüm skorlar null ve bölüm attemptCount=0.
- Tek denemede latest/average/best=81; targetDifference=-1.
- Üç denemede toplamlar 81, 76.5, 58.5: average=72, best=81, latest=58.5; başka kullanıcının 100 neti dışarıda.
- Trend eski → yeni; recent yeni → eski.
- Bölüm average=36, latest=29.25; count=3.
- Geçici test katalog böleni 3 ile yeni sonuç: dashboard latest decimal metni Phase 6 create response toplamına tam eşit. Katalog böleni testten sonra geri alındı.
- Hazırlık değişiminde eski denemeler korunur ama dashboard count=0/null olur.
- Yeni aktif hazırlıkta 25 deneme: trend=20, recent=3, count=25; son 3 average=48, önceki 3=42, change=6.

Tüm kontroller geçti. Bu çalışma PostgreSQL SQL projection/RepeatableRead/scoping/decimal endpoint davranışını doğrular; kapasite/yük testi değildir. Geçici API süreci, container, volume, network, script, log ve parola temizlendi. Kalıcı üretim test hook'u veya kaynak secret eklenmedi.

## Güvenlik

Current-user kimliği yalnız JWT'den; aktif hazırlık filtresi service sorgusunda zorunlu. İstemciden UserId/UserExamId seçimi alınmaz. No-store ve HTTPS middleware kapsamına dashboard eklendi. EF entity/snapshot/token/hash serialize edilmez. Yeni kaynak/test/doküman dosyalarında private key/JWT literal/GitHub token/API key imzaları ve credential atamaları incelendi: gerçek sır yok. Test parolası sentetik fixture, README bağlantısı placeholder ve key örnekleri runtime random üretimidir. SQL/log/APK/build çıktıları Git ignore kapsamında kalır.

## Sınırlar

Aggregate streaming server-side decimal ile O(result row count), uygulama belleği O(section count + 20); N+1 veya lifetime entity listesi yok. SQL numeric division ile Phase 6 decimal farkını önlemek için bilinçli tercih; çok büyük geçmişlerde ayrıca ölçüm gerekir. Section questionCount güncel katalog bağlamıdır, geçmiş netleri normalize etmez. Chart eşit aralıklı deneme sırasını gösterir, tooltip/zoom içermez. Tüm skor gösterimleri iki ondalığa yuvarlanır. Gerçek fiziksel cihaz üzerinde görsel kontrol ve iOS build yapılmadı. AI/tahmin/öneri motoru/bottom navigation yoktur.

Önerilen commit: `feat: add performance dashboard`.

## Son kontrol

Son rapor kontrolü: 4 Ekim 2026. `flutter pub get` ve `flutter gen-l10n` başarılı; `flutter analyze`: No issues found. Birleşik `flutter test`: **133 geçti**, 0 başarısız. `git diff --check` temiz. `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=ALLOW_INSECURE_HTTP=true` 4 Ekim 2026 tarihinde başarıyla tamamlandı (59,2 saniye). Çıktı: `mobile/build/app/outputs/flutter-apk/app-debug.apk`; Git tarafından ignore ediliyor. Önceki terminal oturumu kapanmış olduğu için APK sonucu bu tekrar ile kesinleştirildi. SDK güncelleme/x86 destek bildirimi derlemeyi engellemedi; bağımlılıklar yükseltilmedi.

## Dosya listesi

- `README.md`
- `backend/src/NetPusula.Api/DashboardEndpoints.cs`
- `backend/src/NetPusula.Api/Program.cs`
- `backend/src/NetPusula.Application/Dashboard/DashboardContracts.cs`
- `backend/src/NetPusula.Infrastructure/Dashboard/DashboardService.cs`
- `backend/src/NetPusula.Infrastructure/DependencyInjection.cs`
- `backend/tests/NetPusula.Tests/DashboardTests.cs`
- `docs/architecture.md`
- `docs/dashboard-statistics.md`
- `docs/phase7-validation.md`
- `mobile/lib/features/auth/presentation/home_screen.dart`
- `mobile/lib/features/dashboard/application/dashboard_provider.dart`
- `mobile/lib/features/dashboard/domain/dashboard.dart`
- `mobile/lib/features/dashboard/presentation/net_trend_chart.dart`
- `mobile/lib/features/mock_exams/application/mock_exam_controller.dart`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_tr.dart`
- `mobile/lib/l10n/app_tr.arb`
- `mobile/test/dashboard_test.dart`
- `mobile/test/preparation_widget_test.dart`
- `mobile/test/support/auth_fakes.dart`
