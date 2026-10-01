# Faz 6 doğrulama — 1 Ekim 2026

Faz 6 uygulandı; commit/push yapılmadı. Dal main, HEAD `5b0bd22 feat: add exam preparation onboarding`. Önceki migration ve Git geçmişi değiştirilmedi. Faz 7 başlatılmadı.

## Komut sonuçları

| Kontrol | Sonuç |
| --- | --- |
| dotnet restore | Başarılı |
| dotnet build --no-restore | Başarılı, 0 uyarı / 0 hata |
| dotnet test --no-build | 120 geçti, 0 başarısız, 0 atlandı |
| dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure | Bekleyen model değişikliği yok |
| EF migrations add SnapshotMockSectionDisplay | Gerçek EF tooling ile üretildi |
| EF migrations script --idempotent | Başarılı, backend/obj/Phase6Migrations.sql; ignore ediliyor |
| flutter pub get | Başarılı; mevcut sürüm kısıtları korundu |
| flutter gen-l10n | Başarılı, mobile dizininde |
| flutter analyze | No issues found |
| flutter test | 101 geçti; mobile/build/phase6-tests.log ignore ediliyor |
| flutter build apk --debug | Başarılı; mobile/build/app/outputs/flutter-apk/app-debug.apk |
| git diff --check | Temiz |
| Docker / PostgreSQL | Linux engine named pipe bulunamadı; canlı doğrulama yapılamadı |

Test geliştirme sırasında decimal DTO okuma sözleşmesi, test kodlaması ve async widget test zamanlaması sorunları düzeltildi; yukarıdaki sonuçlar son başarılı çalıştırmalardır. Testlerde keyfi sleep/delay yoktur; in-flight işlemler repository sınırında Completer ile kontrol edilir. Flutter SDK x86 desteğinin gelecekte kaldırılması bildirimi build'i engellemedi. Bağımlılıklar yükseltilmedi.

## Backend kanıtı

Önceki 84 teste 36 yeni vaka eklendi (MockExamTests 35, MockMigrationTests 1). Kapsam: beş uç noktanın auth gerektirmesi, aktif hazırlığın sunucudan çözümü, mass assignment/UserId/UserExamId/Net/TotalNet reddi, yabancı/eksik/inaktif/mükerrer bölüm, negatif/aşırı/kesirli sayılar, blank doğrulaması, decimal bölüm/toplam net, metadata/tarih sınırları, güvenli DTO, aktif hazırlık filtresi, newest-first ve pagination limitleri, başka kullanıcının read/edit/delete reddi, tarihsel kurallarla edit, aggregate delete.

SQLite trigger ile insert/delete sırasında veritabanı hatası enjekte edildi; partial mock veya partial çocuk silme kalmadığı doğrulandı. Hata yanıtında SQL/trigger ayrıntısı bulunmuyor. Geçersiz edit önceki ad/sonuçları koruyor. Migration testi eski şemadan yeni snapshot alanlarına geçişi ve iki kez migration uygulamasını; display backfill sırasında eski soru/bölen/netin korunmasını doğruluyor.

PostgreSQL FOR UPDATE, partial index davranışı ve provider-specific concurrency **gerçek PostgreSQL'de doğrulanmadı**. SQLite sonuçları bu iddia için kullanılmıyor.

## Flutter kanıtı

Önceki 74 teste 27 yeni test eklendi. Home CTA'ları/logout, API bölüm kaynağı, metadata grupları, doğru/yanlış/boş, gelecek tarih sınırı, adımlar arası taslak, review, çift gönderim engeli, server toplamı, save hatası/taslak, history loading/empty/error/retry/cards/load more, detail, edit doldurma/yenileme, delete confirmation/cancel/success/failure, yabancı veya olmayan detail, açık no-preparation yönlendirmesi ve ağ hatasının onboarding sayılmaması, pending save sırasında logout, küçük ekran/büyük yazı kapsanıyor. Decimal gösterim BigInt ile negatif ve yüksek hassasiyet değerlerinde sınandı.

## Güvenlik ve Git

Değişen/yeni dosyalar private key, JWT literal, GitHub token, yaygın API key imzaları, hassas/generated dosya yolları ve credential atamaları bakımından tarandı. Gerçek sır bulunmadı. Test parolası yalnız sentetik fixture; README bağlantısı yer tutucu, signing key örnekleri runtime random üretimidir. Uygulama request/response token logu eklenmedi. Client mass assignment kapalı, sahiplik sorguları current-user filtreli, bölüm üyeliği ve pagination sınırları kontrollü. Generated SQL/APK/test logları mevcut ignore kurallarıyla dışarıda; .gitignore değişmedi. Hiçbir dosya stage edilmedi.

## Kararlar ve sınırlar

Tam sözleşme/ownership/net/blank/snapshot/date/transaction/pagination/delete/Riverpod/draft kararları [mock-exam-tracking.md](mock-exam-tracking.md) içindedir. Sayısal netler sunucuda decimal; wire skorları decimal string. Liste yalnız aktif hazırlıktır, eski sahip olunan kayda ID ile erişilebilir. Delete explicit transaction ile yapılır, FK RESTRICT korunur. Yeni migration yalnız tarihsel gösterim snapshot'larını ekler.

Mevcut seed sadece ALES bölümlerini içerir; diğer sınavlar için soru uydurulmadı. Kalıcı offline taslak, belirsiz POST yanıtından sonra idempotency key, ETag edit conflict çözümü ve final dashboard yoktur. Migration öncesi değiştirilmiş eski bölüm adları geri kazanılamaz; backfill mevcut katalog adını kullanır. Tam cihaz/API uçtan uca testi ve iOS build yapılmadı.

## Manuel adımlar

1. Docker Desktop Linux engine / PostgreSQL'i çalıştırın, bağlantı/JWT ayarlarını ortam değişkenlerinden sağlayın.
2. Backend dizininde `dotnet ef database update --project src/NetPusula.Infrastructure` iki kez çalıştırın.
3. Gerçek PostgreSQL'de auth, tek aktif UserExam index'i, mock persist/edit/delete/rollback, sahiplik sorguları ve eşzamanlı hazırlık/mutasyon davranışını doğrulayın.
4. Android cihaz/emulator ile onboarding → ekle → history → edit → onaylı sil akışını gerçek API'ye karşı kontrol edin; iOS'u macOS/Xcode'da derleyin.

Önerilen commit mesajı: `feat: add mock exam tracking`. Kullanıcı ayrıca istemeden commit/push yapılmayacaktır.

## Oluşturulan/değiştirilen dosyalar

- `README.md`
- `backend/src/NetPusula.Api/MockExamEndpoints.cs`
- `backend/src/NetPusula.Api/Program.cs`
- `backend/src/NetPusula.Application/MockExams/MockExamContracts.cs`
- `backend/src/NetPusula.Domain/MockExam.cs`
- `backend/src/NetPusula.Domain/MockExamResult.cs`
- `backend/src/NetPusula.Infrastructure/DependencyInjection.cs`
- `backend/src/NetPusula.Infrastructure/DomainModelConfiguration.cs`
- `backend/src/NetPusula.Infrastructure/Migrations/20261001114310_SnapshotMockSectionDisplay.Designer.cs`
- `backend/src/NetPusula.Infrastructure/Migrations/20261001114310_SnapshotMockSectionDisplay.cs`
- `backend/src/NetPusula.Infrastructure/Migrations/NetPusulaDbContextModelSnapshot.cs`
- `backend/src/NetPusula.Infrastructure/MockExams/MockExamService.cs`
- `backend/tests/NetPusula.Tests/MockExamTests.cs`
- `backend/tests/NetPusula.Tests/MockMigrationTests.cs`
- `docs/architecture.md`
- `docs/mock-exam-tracking.md`
- `docs/phase6-validation.md`
- `mobile/lib/core/routing/app_router.dart`
- `mobile/lib/features/auth/presentation/home_screen.dart`
- `mobile/lib/features/mock_exams/application/mock_exam_controller.dart`
- `mobile/lib/features/mock_exams/data/mock_exam_repository.dart`
- `mobile/lib/features/mock_exams/domain/mock_exam.dart`
- `mobile/lib/features/mock_exams/presentation/mock_exam_screens.dart`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_tr.dart`
- `mobile/lib/l10n/app_tr.arb`
- `mobile/test/mock_exam_test.dart`
