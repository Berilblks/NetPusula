# Faz 5 doğrulama raporu — 2026-10-01

Kapsam: UserExam API, tek aktif hazırlık, ilk kullanım onboarding ve basit hedef/tarih düzenleme. Faz 6, deneme CRUD, grafik, istatistik, gerçek dashboard veya alt gezinme eklenmedi. Çalışma mevcut `main` üzerinde yapılmıştır; bu faz için commit/push yapılmadı.

## Sonuç tablosu

| Kontrol | Sonuç |
| --- | --- |
| dotnet restore | Başarılı |
| dotnet build --no-restore | Başarılı, 0 hata / 0 uyarı |
| dotnet test --no-build --no-restore | 84/84 test; önceki 63 testin kapsamı korundu |
| dotnet ef migrations has-pending-model-changes | Bekleyen model farkı yok |
| dotnet ef migrations script --idempotent | Başarılı; SQL obj/Phase5Migrations.sql içinde |
| SQLite migration testi | Faz 3 şemasından Faz 5'e geçiş ve ikinci uygulama başarılı; eski satırlar korunuyor |
| flutter pub get | Başarılı, mevcut paket sürümleri korundu |
| flutter gen-l10n | Başarılı |
| flutter analyze | No issues found |
| flutter test | 74/74; önceki 50 test korundu |
| flutter build apk --debug (API dart-defines ile) | Başarılı |
| Gerçek PostgreSQL | Doğrulanamadı: Docker Desktop Linux engine pipe bulunamadı |
| iOS/fiziksel cihaz | Bu Windows ortamında çalıştırılmadı |

APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Emulator yapılandırması `API_BASE_URL=http://10.0.2.2:5080`, `ALLOW_INSECURE_HTTP=true`. Release URL/signing ayarları bu fazda değiştirilmedi. Flutter'ın x86 desteğine ilişkin gelecek sürüm bildirimi derlemeyi engellemedi.

İlk backend çalıştırmasında iki test nullability uyarısı ve desteklenmeyen ID ile GET için yanlış 404 beklentisi görüldü. API'de o yöntem bulunmadığı için doğru sonuç 405'tir; sahiplik PUT testi hâlâ yabancı kullanıcıya 404 bekler. Uyarılar ve beklenti düzeltildi. Flutter lint uyarıları düzeltildi. Migration scaffold'un genel veri kaybı uyarısı incelendi: önceki migration'lar değiştirilmedi; Up kayıt silmez, eski mükerrer aktifleri deterministik pasifleştirir. Down completeness kolonunu kaldırır; deaktive edilen kayıtları yeniden aktive etmez.

## Backend değişiklikleri

- `GET /api/user-exams/active`: current user'ın aktifi, yoksa 204. 404/ağ hatası “hazırlık yok” anlamında kullanılmaz.
- `POST /api/user-exams`: examId, targetNet, examDate; 201 safe DTO. Kimlik JWT/ICurrentUser'dan gelir.
- `PUT /api/user-exams/{id}`: sadece aktif sahibinin targetNet/examDate alanları; 200 safe DTO.
- Bilinmeyen/yabancı sahiplik 404; tarihsel satır update 409. Bilinmeyen JSON alanları (UserId/ExamId değiştirme denemesi dahil) 400.
- PostgreSQL user row lock + transaction + unique partial index. Yeni hazırlık eski kaydı silmez. Aynı aktif sınav/hedef/tarih POST retry'ı aynı ID'yi döndürür.
- `maximumTargetNet` katalog DTO'suna eklendi. Pozitif decimal ve numeric(12,4) temsil kuralı; tam/aktif/grupsuz katalogda bölüm soru sayısı toplamı. Eksik katalogda null. Soru sayısı/bölen verileri değiştirilmedi.
- DATE semantiği: mobil yerel gün, backend Türkiye UTC+03 gününü güvenilir sunucu saatinden hesaplar. Saat/timezone request alanı yok.
- Yeni migration `20260930173315_EnforceSingleActiveUserExam`: unique filtered index ve Exam.HasCompleteSectionConfiguration. Eski mükerrer aktiflerde en yeni CreatedAtUtc/Id kazanır; kalan tarihçe korunur.

## Backend testleri

`PreparationTests.cs`: 20 test vakası. Authentication gerekliliği, safe DTO/204, JWT sahipliği, body injection, kullanıcı izolasyonu, inactive/nonexistent exam, beş geçersiz target sınırı, eksik katalog, past/missing date, Türkiye gün sınırı, hedef/tarih update, geçmişi koruma, idempotent aynı POST, başarısız replacement'ın eski aktifi koruması, database unique index ve eşzamanlı POST.

`PreparationMigrationTests.cs`: 1 test. Eski şemada iki aktif kayıt oluşturur, yeni migration'ı iki kez uygular, sadece en yeninin aktif kaldığını/tüm kayıtların korunduğunu ve indeksin ikinci aktifi engellediğini doğrular. Bu SQLite relational migration testidir; PostgreSQL row lock'u veya production migration uygulaması iddiası değildir.

Mevcut `DatabaseTests` tarihçe testi yeni kurala uyarlandı: ikinci aktif eklemeden önce eskisini pasifleştirir; ilişki/tarihçe ve deneme sonuçlarının korunması kontrolleri kaldırılmadı. Diğer auth/exam/health testleri korunmuştur. Toplam: 63 + 21 = 84.

## Flutter akışı ve testleri

AuthState'e business alanı eklenmedi. PreparationRepository mevcut public/authorized Dio'ları kullanır. PreparationController `idle/loading/none/ready/error` ve `saving` durumlarını ayırır; logout/kullanıcı değişiminde eski istek sonuçları kabul edilmez. Yalnızca 204 onboarding açar. Offline lookup retry ekranında kalır.

Routes: `/preparation`, `/onboarding`, `/goal/edit` eklendi. `/home` için hem auth hem hazır aktif preparation gerekir. Onboarding welcome → API exam kartları → decimal target → date picker → review/save. Back/step progress, SafeArea, scroll, klavye, büyük yazı ve disabled submit desteklenir. Hata halinde draft bellekte korunur. Home artık sınav/hedef/tarih ve kalan gün gösterir; düzenleme exam'i değiştirmez, logout korunur.

`preparation_test.dart`: 10 test. Calendar/leap/year/time-of-day, scaled-int Türkçe decimal, sadece 204'ün none olması, exact create/update gövdeleri, 400/404/409/429/500 güvenli eşleme, duplicate save ve logout sırasında tamamlanan save'in reddi.

`preparation_widget_test.dart`: 14 test. None → onboarding ve bypass engeli, returning user → home, bugün/geçmiş metni, loading'de içerik göstermeme, offline/retry, API kartları/tek seçim, empty/retry, hedef sınırı, date picker past sınırı ve review, save/home, hatada taslak/retry, saving sırasında submit/back engeli, edit, onboarding logout, küçük ekran/klavye/büyük yazı.

Önceki 50 test korunmuştur; eski temporary-home test fake'i artık active-preparation yanıtı da verir ve restore testindeki HTTP çağrı sayısı 1'den 2'ye güncellendi. Toplam 50 + 24 = 74.

## Dosyalar

Yeni backend:

- `backend/src/NetPusula.Api/PreparationEndpoints.cs`
- `backend/src/NetPusula.Application/Preparations/PreparationContracts.cs`
- `backend/src/NetPusula.Infrastructure/Preparations/PreparationService.cs`
- `backend/src/NetPusula.Infrastructure/Migrations/20260930173315_EnforceSingleActiveUserExam.cs` ve `.Designer.cs`
- `backend/tests/NetPusula.Tests/PreparationTests.cs`
- `backend/tests/NetPusula.Tests/PreparationMigrationTests.cs`

Güncellenen backend: `Program.cs`, `ExamEndpoints.cs`, `ExamDtos.cs`, `Domain/Exam.cs`, `Domain/UserExam.cs`, `Infrastructure/DependencyInjection.cs`, `DomainModelConfiguration.cs`, `ExamSeed.cs`, `NetPusulaDbContextModelSnapshot.cs`, `DatabaseTests.cs`. Önceki migration dosyaları aynıdır.

Yeni Flutter:

- `mobile/lib/features/preparation/domain/preparation.dart`
- `mobile/lib/features/preparation/data/preparation_repository.dart`
- `mobile/lib/features/preparation/application/preparation_controller.dart`
- `mobile/lib/features/preparation/presentation/goal_screen.dart`
- `mobile/lib/features/preparation/presentation/preparation_loading_screen.dart`
- `mobile/lib/features/preparation/presentation/preparation_text.dart`
- `mobile/test/preparation_test.dart`
- `mobile/test/preparation_widget_test.dart`

Güncellenen Flutter: `core/routing/app_router.dart`, `features/auth/presentation/home_screen.dart`, `l10n/app_tr.arb` ve generated localization sınıfları, `test/support/auth_fakes.dart`, `test/widget_test.dart`. Auth repository/controller/interceptor/secure-storage kaynakları değiştirilmedi.

Dokümanlar: README.md, docs/architecture.md, yeni docs/preparation-onboarding.md ve bu rapor.

## Güvenlik, sınırlamalar ve manuel adımlar

Sahiplik her sorgu/yazmada current-user ile filtrelenir; arbitrary user endpoint yoktur. Request DTO'ları sahiplik ve exam mutation alanlarını kabul etmez. Entity/PasswordHash/token cevaplara eklenmez. Token logging, credential log interceptor, secret veya üretim URL'si eklenmedi. Auth regression ve single-flight testleri geçer. Kişisel preparation cevapları no-store'dur.

Canlı PostgreSQL için Docker motorunu başlatıp mevcut connection environment ile `dotnet ef database update --project src/NetPusula.Infrastructure` komutunu iki kez çalıştırın. DB check ve eşzamanlı kullanıcı create/update testini gerçek PostgreSQL üzerinde tamamlayın. Mevcut mükerrer aktif satırları production migration öncesi gözden geçirin; migration en yeni kaydı seçer.

Uygulama kapatılırsa kaydedilmemiş onboarding draft'ı saklanmaz. Offline cache, çok cihazlı anlık sync, optimistic UI version/ETag, sınav değiştirme UI'si, official sınav takvimi ve grouped-exam hedef seçimi yoktur. Son geçerli goal update lock sırasına göre kazanır. Türkiye dışındaki tarih sınırında cihaz/sunucu günleri farklı olabilir; server validation otoritedir. Fiziksel Android/iOS kabul adımları [preparation-onboarding.md](preparation-onboarding.md) belgesindedir. Gerçek dashboard ve deneme CRUD bu fazın dışında kaldı.

Önerilen commit: `feat: add exam preparation onboarding`.
