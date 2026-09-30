# Faz 2 doğrulama — 2026-09-29

## Sonuçlar
| Kontrol | Sonuç |
| --- | --- |
| dotnet restore | Başarılı, 5 proje |
| dotnet build --no-restore | Başarılı; 0 uyarı, 0 hata; son çalıştırma 2.35 saniye |
| dotnet test --no-build | 23 başarılı, 0 başarısız, 0 atlanan |
| dotnet format --verify-no-changes --no-restore | Başarılı |
| dotnet ef migrations add InitialDomainModel --project src/NetPusula.Infrastructure --output-dir Migrations | Gerçek EF CLI ile üretildi |
| dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure | Model farkı yok; format sonrası --no-build ile de doğrulandı |
| dotnet ef migrations script --idempotent --project src/NetPusula.Infrastructure --output obj/InitialDomainModel.sql | Başarılı; PostgreSQL SQL çıktısı incelendi |
| dotnet list package --vulnerable --include-transitive | Beş projede bilinen açık raporlanmadı |
| flutter analyze | No issues found, 7.8 saniye |
| flutter test | 2 başarılı, 0 başarısız |
| docker version | İstemci 29.2.0; Linux engine named pipe bulunamadı |

Migration: 20260929130143_InitialDomainModel. Altı tablo, altı sınav ve iki ALES bölümü; UUID, timestamptz/date, decimal precision, unique/check ve composite FK/RESTRICT işlemleri incelendi. Down işlemleri de bağımlılık sırasına göre tablo kaldırıyor; üretimde rollback veri kaybına neden olacağından yalnızca bilinçli bakımda kullanılmalıdır.

İlk build, Design paketiyle gelen EF 8.0.31 ile transitif 8.0.11 runtime arasında sürüm uyuşmazlığı nedeniyle başarısız oldu. Infrastructure'a açık Microsoft.EntityFrameworkCore.Relational 8.0.31 referansı eklenerek düzeltildi. Son build uyarısızdır.

Docker motoru erişilemediğinden PostgreSQL başlatılmadı, migration gerçek PostgreSQL'e uygulanmadı, canlı seed/bağlantı doğrulanmadı. SQLite testlerinin başarılı olması PostgreSQL migration uygulaması yerine geçmez. README'deki database update, tekrar update, --check-database ve API kontrol adımlarını Docker çalıştıktan sonra uygulayın.

## Test kapsamı
18 yeni test vakası ve mevcut 5 backend testi:
- 40/8/2, bölen 4 → 38; tüm boş → 0.
- Üç negatif sayım durumu, fazla toplam, int taşması, sıfır/negatif bölen, geçersiz soru sayısı.
- Decimal hassasiyet, farklı bölen, negatif net.
- Snapshot ile geçmiş netin korunması; farklı sınava ait bölüm ve UTC olmayan deneme zamanı reddi.
- Üç uniqueness senaryosu: sınav kodu, sınav içi bölüm kodu, normalize email.
- Sonuç tekrarının engellenmesi, SQL CHECK kısıtları, sınav üyeliği composite FK'leri, tüm geçmiş ilişkilerinde silme reddi.
- UTC audit alanları, oluşturma zamanının korunması, yeni hazırlıkla geçmişin korunması.
- Test DB başlangıcının tekrarında seed çoğalmaması; doğru kayıt sayıları. Gerçek PostgreSQL migration tekrar uygulaması henüz test edilmedi.
- Üç katalog endpoint'i, aktif filtre, DTO alanları, sözleşmeye uygun sıralama, 404/boş liste/405 davranışları.
- Mevcut health, CORS, Swagger ve genel hata gizleme testleri korundu.

Testler SQLite in-memory üzerinde gerçek ilişkisel kısıtlarla çalışır; EF InMemory sağlayıcısı kullanılmaz. PostgreSQL numeric ölçeği/UTC sürücüsü ve gerçek migration uygulaması bu testlerin dışında kalır.

## Yeni dosyalar
- backend/.config/dotnet-tools.json
- backend/src/NetPusula.Domain/Entity.cs
- backend/src/NetPusula.Domain/User.cs
- backend/src/NetPusula.Domain/Exam.cs
- backend/src/NetPusula.Domain/ExamSection.cs
- backend/src/NetPusula.Domain/UserExam.cs
- backend/src/NetPusula.Domain/MockExam.cs
- backend/src/NetPusula.Domain/MockExamResult.cs
- backend/src/NetPusula.Domain/NetCalculator.cs
- backend/src/NetPusula.Application/Exams/ExamDtos.cs
- backend/src/NetPusula.Api/ExamEndpoints.cs
- backend/src/NetPusula.Infrastructure/DomainModelConfiguration.cs
- backend/src/NetPusula.Infrastructure/ExamSeed.cs
- backend/src/NetPusula.Infrastructure/DesignTimeDbContextFactory.cs
- backend/src/NetPusula.Infrastructure/Migrations/20260929130143_InitialDomainModel.cs
- backend/src/NetPusula.Infrastructure/Migrations/20260929130143_InitialDomainModel.Designer.cs
- backend/src/NetPusula.Infrastructure/Migrations/NetPusulaDbContextModelSnapshot.cs
- backend/tests/NetPusula.Tests/NetCalculatorTests.cs
- backend/tests/NetPusula.Tests/TestDatabase.cs
- backend/tests/NetPusula.Tests/DatabaseTests.cs
- backend/tests/NetPusula.Tests/ExamApiTests.cs
- docs/phase2-validation.md

## Değiştirilen dosyalar
- backend/src/NetPusula.Api/Program.cs: endpoint kaydı.
- backend/src/NetPusula.Infrastructure/NetPusulaDbContext.cs: DbSet, model/seed ve UTC audit.
- backend/src/NetPusula.Infrastructure/NetPusula.Infrastructure.csproj: Design/Relational 8.0.31.
- backend/tests/NetPusula.Tests/NetPusula.Tests.csproj: test-only SQLite 8.0.31.
- README.md ve docs/architecture.md: kullanım, model, kararlar ve doğrulama sınırı.

Ek SQL çıktısı backend/obj/InitialDomainModel.sql altında üretildi ve ignore edilir. Flutter için kaynak değişikliği yapılmadı. Biçimlendirme dotnet format ile uygulandı.

## Açık doğrulamalar
YKS, KPSS alt türleri, DGS, MSÜ, YDS bölümleri ve kuralları onboarding öncesi resmî kaynaklardan doğrulanmalı. YDS için otomatik /4 varsayımı yapılmadı. Sadece ALES detayları doğrulanarak seed edildi; kaynak mimari belgesindedir.

Kaynak/config taramasında gerçek parola eklenmedi; .env ve SQL build çıktısının ignore edildiği doğrulandı. Depoda henüz ilk commit bulunmadığından git status tüm başlangıç dosyalarını untracked gösterir. Dosyalar stage edilmedi, commit oluşturulmadı.

Önerilen commit: feat: add exam domain model and configuration.

