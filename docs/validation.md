# Faz 1 doğrulama — 2026-09-29

Ortam: Windows, .NET SDK 8.0.418, Flutter 3.29.0 / Dart 3.7.0.

| Komut | Sonuç |
| --- | --- |
| dotnet restore | Başarılı, 5 proje |
| dotnet build --no-restore | Başarılı, 0 hata / 0 uyarı |
| dotnet test --no-build | 5/5 başarılı |
| dotnet format --no-restore | Uygulandı |
| dotnet format --verify-no-changes --no-restore | Başarılı (ilk 4 testli temel üzerinde; ek hata testi sonradan formatlandı) |
| dotnet list package --vulnerable --include-transitive | Son taramada hiçbir projede bilinen açık raporlanmadı |
| flutter pub get | Başarılı |
| flutter gen-l10n | Başarılı, gerçek SDK çıktıları oluşturuldu |
| flutter analyze | No issues found |
| flutter test | 2/2 başarılı |
| flutter build apk --debug | Başarılı, build/app/outputs/flutter-apk/app-debug.apk |
| docker compose config --quiet | Başarılı; yalnızca doğrulama sürecine rastgele geçici parola verildi, dosyaya yazılmadı |
| docker version / docker info | İstemci kurulu, Docker Linux engine named pipe bulunamadı |
| docker desktop start | Başlangıç tamamlanmadı; bekleyen CLI çağrısı sonlandırıldı |
| dotnet run --no-build --project src/NetPusula.Api -- --check-database | Bağlantı ayarı olmadan beklendiği gibi genel hata ve exit code 1 |

Canlı PostgreSQL başlatma ve başarılı API → PostgreSQL bağlantısı doğrulanamadı. Docker Desktop motorunu çalıştırın, README'deki .env kurulumunu ve bağlantı kontrolünü uygulayın. Veritabanı veya gerçek parola oluşturulmadı. iOS derlemesi Windows üzerinde çalıştırılmadı; macOS/Xcode gerekir. Fiziksel cihaz/emülatör üzerinde çalışma denenmedi.

İlk backend testinde CORS konfigürasyonunun erken okunması sorunu düzeltildi. Eski xUnit şablonundan gelen geçişli güvenlik uyarıları test bağımlılıkları yenilenerek giderildi. İlk APK denemesinde SDK/NDK ve minimum Android sürümü uyuşmazlıkları giderildi: compile SDK 36, NDK 27.0.12077973, minSdk 23. Son APK derlemesinde Kotlin daemon bağlantı uyarısı oldu; derleyicinin yedek yolu ile APK başarıyla üretildi.

Doğrudan bağımlılıklar:
- Backend: Npgsql.EntityFrameworkCore.PostgreSQL 8.0.11, Microsoft.AspNetCore.OpenApi 8.0.24, Swashbuckle.AspNetCore 6.6.2.
- Test: Microsoft.AspNetCore.Mvc.Testing 8.0.31, Microsoft.NET.Test.Sdk 18.10.1, xunit 2.9.3, xunit.runner.visualstudio 3.1.5.
- Flutter: flutter_riverpod 3.3.2, go_router 17.0.0, dio 5.11.1, flutter_secure_storage 10.3.4; SDK flutter_localizations/flutter_test; flutter_lints 5.0.0. pubspec.lock korunur.

Git deposu başlatıldı; dosyalar stage edilmedi ve commit oluşturulmadı. .env ve build çıktılarının ignore edildiği, .env.example ve pubspec.lock dosyalarının ignore edilmediği kontrol edildi.
