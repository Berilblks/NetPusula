# NetPusula

Türkiye'de ÖSYM sınavlarına hazırlananlar için mobil uygulama. Faz 1–6 kapsamında domain/veritabanı, authentication, tek aktif hazırlık/onboarding ve deneme ekleme, düzenleme, silme, bölüm sonuçları ve sayfalı geçmiş hazırdır. Gerçek dashboard, istatistik ve alt gezinme henüz kapsamda değildir.

## Teknolojiler ve gereksinimler

- .NET 8 SDK (backend/global.json: 8.0.418, daha yeni 8.0.4xx yamaları kabul edilir)
- Flutter 3.29.0 / Dart 3.7.0 ile doğrulanan Android/iOS projesi
- Riverpod, go_router, Dio, flutter_secure_storage
- ASP.NET Core, EF Core 8 / Npgsql, PostgreSQL 16
- Docker Desktop (Linux containers) + Compose v2, Git
- Android SDK/JDK; iOS derlemek için macOS ve Xcode gerekir.

## Dizinler

```text
backend/
  global.json
  NetPusula.sln
  src/
    NetPusula.Api/
    NetPusula.Application/
    NetPusula.Domain/
    NetPusula.Infrastructure/
  tests/NetPusula.Tests/
mobile/
  android/
  ios/
  lib/
    app/
    core/constants/
    core/routing/
    core/theme/
    features/welcome/
    l10n/
    main.dart
  test/
docs/architecture.md
docker-compose.yml
.env.example
.gitignore
```

## PostgreSQL

Depo kökünde PowerShell:

```powershell
Copy-Item .env.example .env
# .env içindeki POSTGRES_PASSWORD alanını yerel bir parola ile doldurun.
docker compose config --quiet
docker compose up -d --wait
docker compose ps
```

Veritabanı yalnızca 127.0.0.1 üzerinde açılır. Varsayılan port 5432, kullanıcı/veritabanı netpusula'dır. .env ile değiştirilebilir. Parola için gömülü varsayılan yoktur. Veriler postgres_data volume'ünde kalır; durdurmak için `docker compose down`. Mevcut volume oluşturulduktan sonra .env parolasını değiştirmek veritabanı parolasını değiştirmez.

## Backend

```powershell
cd backend
dotnet restore
dotnet build --no-restore
$env:ConnectionStrings__Database = 'Host=localhost;Port=5432;Database=netpusula;Username=netpusula;Password=<yerel-parolanız>'
dotnet tool restore
dotnet ef database update --project src/NetPusula.Infrastructure
dotnet run --project src/NetPusula.Api -- --check-database
$env:Jwt__SigningKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
dotnet run --project src/NetPusula.Api
```

Parolayı kaynak dosyalarına koymayın; ortam değişkeni veya yerel .NET user-secrets kullanın. Örnekteki yer tutucuyu kendi .env değerinizle değiştirin. Compose .env dosyasını okur; ASP.NET Core otomatik olarak okumaz.

- Sağlık: http://localhost:5080/api/health → `{"status":"healthy"}`
- Development Swagger: http://localhost:5080/swagger
- `--check-database`: gerçek bağlantıyı kontrol eder, başarılıysa 0, başarısızsa 1 ile çıkar. Tablo veya migration oluşturmaz.
- Sağlık kontrolü yalnızca API canlılığını ölçer; veritabanı hazır olma kontrolü değildir.

Development ayarları appsettings.Development.json dosyasındadır. Varsayılan CORS kökeni http://localhost:3000; üretim listesi boştur. Dağıtımda `ASPNETCORE_ENVIRONMENT=Production`, `AllowedHosts`, `Cors__AllowedOrigins__0` ve `ConnectionStrings__Database` ortam değişkenlerini tanımlayın. Üretimde HTTPS gereklidir; ters proxy kullanıldığında güvenilen proxy/forwarded-header yapılandırmasını dağıtıma göre ayrıca yapın. Üretimde Swagger kapalıdır.

## Flutter

```powershell
cd mobile
flutter pub get
flutter gen-l10n
flutter run -d <android-veya-ios-cihaz-kimliği>
```

`flutter devices` ile cihazları görebilirsiniz. Uygulama Dio ile API'ye bağlanır; oturum güvenli depolamada saklanır. API bağlantı ayarları aşağıdaki Faz 4 bölümündedir.

Uygulama adı lib/core/constants/app_brand.dart içinde, Türkçe metinler lib/l10n/app_tr.arb içindedir. Yerelleştirme Dart dosyaları Flutter'ın gerçek gen-l10n çıktısıdır. Android manifest ve iOS Info.plist içindeki mağaza/launcher adı da yeniden markalamada güncellenmelidir.

Geçici Android/iOS kimliği: `dev.netpusula.netpusula`. Alan adı sahipliği doğrulanmamıştır; mağaza yayınından önce sahip olduğunuz nihai kimlikle değiştirin. Platform ikonları Flutter şablonundandır. Yayın imzalama ve mağaza varlıkları bu fazın dışındadır.

Paketler kurulu SDK'nın çözebildiği kararlı sürümlerden seçilmiştir; daha yeni SDK gerektiren sürümler zorlanmamıştır. pubspec.lock depoda tutulmalıdır.

## Kontroller

```powershell
cd backend
dotnet restore
dotnet build --no-restore
dotnet test --no-build
dotnet format --verify-no-changes --no-restore
cd ../mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Backend testleri sağlık yanıtını, Development/Production Swagger davranışını ve CORS köken sınırını; Flutter testleri ilk ekranı ve küçük ekranda büyük yazıyı doğrular. Faz 1 sonuçları docs/validation.md, Faz 2 sonuçları docs/phase2-validation.md içindedir. Yeni testler net hesabını, veritabanı kısıtlarını, tarihsel netleri ve katalog API davranışını da kapsar.

Faz 1–5 GitHub üzerinde kayıtlıdır. Faz 6 değişiklikleri inceleme için commit edilmeden bırakılmıştır.


Android temel hedefleri: minimum API 23, compile SDK 36, NDK 27.0.12077973. iOS minimum 12.0; iOS derlemesi Windows üzerinde doğrulanamaz.


## Faz 2: katalog ve migration

Mevcut migration: InitialDomainModel (Infrastructure/Migrations). Uygulama açılışında otomatik uygulanmaz. Yukarıdaki backend komutlarında bağlantıyı ayarlayıp database update çalıştırın. Tasarım zamanı factory yalnızca ConnectionStrings__Database ortam değişkenini okur; parola içermeyen varsayılanı sadece migration üretimi içindir. EF CLI için user-secrets yerine bu ortam değişkenini kullanın.

```powershell
# backend dizininde; migration üretmek/incelemek için çalışan DB gerekmez
dotnet tool restore
dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure
dotnet ef migrations script --idempotent --project src/NetPusula.Infrastructure --output obj/InitialDomainModel.sql
# Docker/DB çalıştıktan ve ConnectionStrings__Database ayarlandıktan sonra:
dotnet ef database update --project src/NetPusula.Infrastructure
# İkinci çalıştırma değişiklik yapmamalı:
dotnet ef database update --project src/NetPusula.Infrastructure
dotnet run --project src/NetPusula.Api -- --check-database
```

API çalışırken ayrı PowerShell penceresinde:

```powershell
Invoke-RestMethod http://localhost:5080/api/health
$exams = Invoke-RestMethod http://localhost:5080/api/exams
$exams | Format-Table
$ales = $exams | Where-Object Code -eq 'ALES'
Invoke-RestMethod "http://localhost:5080/api/exams/$($ales.Id)"
Invoke-RestMethod "http://localhost:5080/api/exams/$($ales.Id)/sections"
```

Beklenen: altı sınav; ALES için SAYISAL/SOZEL, 50 soru ve bölen 4; diğer beş sınavın bölüm listeleri henüz boş. Gerçek PostgreSQL üzerinde migration/seed doğrulaması bu ortamda Docker motoru erişilemediği için tamamlanamadı. Bu kontrolleri Docker Desktop Linux engine çalıştıktan sonra uygulayın.

User → UserExam → MockExam → MockExamResult ilişkisi geçmişi korur; Exam → ExamSection katalog ilişkisi sınırsız bölüm/grup destekler. Net decimal olarak doğru − yanlış/bölen ile hesaplanır; Net/TotalNet saklanmaz. Sonuçlar soru sayısı ve böleni snapshot olarak tutar. Tüm FK silmeleri RESTRICT, zamanlar UTC, sınav tarihi DateOnly'dir. Ayrıntılar: [mimari](docs/architecture.md).

EF araç/Design/Relational 8.0.31 kullanılır; Npgsql sağlayıcısı 8.0.11 korunmuştur. Microsoft.EntityFrameworkCore.Sqlite 8.0.31 yalnızca test bağımlılığıdır. Faz 2 için Flutter kaynakları değiştirilmedi.



## Faz 3: backend authentication

Register, login, refresh, logout ve korumalı me uç noktaları eklendi. Flutter kaynakları değişmedi. Ayrıntılı API/config/security/rotation sözleşmesi: [authentication.md](docs/authentication.md). Çalıştırma sonuçları ve dosya listesi: [phase3-validation.md](docs/phase3-validation.md).

API başlangıcında Jwt__SigningKey zorunludur. Yerel terminalde, değeri ekrana yazmadan:

```powershell
$env:Jwt__SigningKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

Bu key yerel geliştirme içindir; yeniden üretildiğinde önceki access JWT'leri geçersiz olur. Üretimde kalıcı güçlü key secret manager/environment ile sağlanmalıdır. Ortam değişkenleri: Jwt__Issuer, Jwt__Audience, Jwt__SigningKey, Jwt__AccessTokenMinutes (15), Auth__RefreshTokenDays (30), AuthRateLimit__PermitLimit (20), AuthRateLimit__WindowSeconds (60). Appsettings gerçek secret içermez. .env dosyasını API otomatik okumaz.

Yeni migration: 20260930115643_AddAuthentication. İlk migration değiştirilmedi. Docker çalıştıktan sonra, backend dizininde bağlantı ayarıyla:

```powershell
dotnet tool restore
dotnet ef database update --project src/NetPusula.Infrastructure
dotnet ef database update --project src/NetPusula.Infrastructure
dotnet run --project src/NetPusula.Api -- --check-database
dotnet run --project src/NetPusula.Api
```

İkinci update değişiklik yapmamalıdır. Bu ortamda Docker motoruna erişilemedi: canlı PostgreSQL migration ve row-lock testi hâlâ manuel doğrulama gerektirir.

| Yol | Başarı |
| --- | --- |
| POST /api/auth/register | 201, { displayName, email, password } ile |
| POST /api/auth/login | 200, { email, password } ile |
| POST /api/auth/refresh | 200, { refreshToken } ile |
| POST /api/auth/logout | 204, { refreshToken } ile |
| GET /api/auth/me | 200, Authorization: Bearer access-token ile |

Auth yanıtında access/refresh token, UTC bitişleri ve güvenli user DTO bulunur. Parola hasher ile; refresh yalnızca SHA-256 hash olarak saklanır. Her refresh önceki token'ı iptal eder. Eski token tekrar kullanılırsa aynı oturum ailesindeki yeniler de iptal edilir; istemci refresh'i tekilleştirmelidir. Logout access JWT'yi anında iptal etmez; varsayılan en çok 15 dakika daha geçerli kalır. Public health/exams anonimdir.

Üretimde auth HTTPS gerektirir. Uygulama başına/IP başına hız sınırı çoklu instance'lar arasında paylaşılmaz; proxy/ingress güven ve hız sınırı ayarları dağıtımda ayrıca yapılmalıdır. Email doğrulama ve parola sıfırlama bu fazda yoktur.



## Faz 4: Flutter authentication

Türkçe splash, karşılama, giriş, kayıt ve geçici authenticated home tamamlandı. Oturum flutter_secure_storage ile saklanır; başlangıçta /me ile geri yüklenir. Dio tek refresh işlemini eşzamanlı isteklere paylaştırır, dönen token çiftini kaydeder ve 401 alan isteği yalnızca bir kez tekrarlar. Logout ağ olmasa da yerel oturumu kapatır; sunucudaki olası açık oturum kullanıcıya bildirilir.

Mimari, secure storage/rotation tercihleri, emulator/fiziksel cihaz/üretim komutları ve manuel kontrol listesi: [Flutter authentication](docs/mobile-authentication.md). Test/derleme sonuçları ve dosya listesi: [Faz 4 doğrulama](docs/phase4-validation.md).

Backend ve DB hazırken Android emulator için `mobile` dizininde:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=ALLOW_INSECURE_HTTP=true
```

Backend `AllowedHosts` listesi 10.0.2.2 içermelidir; tam başlangıç komutu bağlantılı belgede yer alır. API_BASE_URL zorunlu bağlantı yapılandırmasıdır; üretimde gerçek HTTPS origin verilmelidir. HTTP yalnızca açıkça izin verilen debug geliştirmesinde çalışır. Backend key/token secret'ları Flutter'a konulmaz. Bu fazda backend davranışı değiştirilmedi; sınav onboarding ve dashboard eklenmedi.

## Faz 5: kullanıcı hazırlığı ve onboarding

Auth sonrası `/api/user-exams/active` kontrol edilir. Aktif hazırlığı olmayan kullanıcı sınav → hedef net → tarih → özet adımlarını tamamlar. Hazırlığı olan kullanıcı geçici home'a gider; hedefini ve tarihini düzenleyebilir. Yükleme/ağ hatası “hazırlık yok” sayılmaz; retry ekranı gösterilir.

Yeni authenticated uç noktalar: `GET /api/user-exams/active` (yoksa 204), `POST /api/user-exams`, `PUT /api/user-exams/{id}`. UserId JWT'den alınır; request'e eklenmesi reddedilir. Değiştirilecek sınav yeni hazırlık olarak oluşturulur; eski kayıtlar korunur. Tam kataloglar için `maximumTargetNet`, mevcut sınav DTO'larına opsiyonel alan olarak eklendi.

Yeni migration: `20260930173315_EnforceSingleActiveUserExam`. API ve mobil sürümü kullanmadan önce backend dizininde:

```powershell
dotnet tool restore
dotnet ef database update --project src/NetPusula.Infrastructure
```

Veritabanı bağlantısını önceki kurulum adımlarındaki ortam değişkeninden sağlayın. Migration önce bir kullanıcıya ait eski mükerrer aktif kayıtlar varsa en yenisini aktif bırakır, diğerlerini tarihçeyi silmeden pasifleştirir; sonra unique partial index'i oluşturur. Yeni `HasCompleteSectionConfiguration` alanı yalnızca mevcut doğrulanmış ALES seed'inde true'dur; soru/bölüm sayıları değiştirilmedi.

Yaşam döngüsü, API örnekleri, decimal/tarih kuralları, offline davranışı ve manuel kontrol listesi: [hazırlık ve onboarding](docs/preparation-onboarding.md). Sonuçlar: [Faz 5 doğrulama](docs/phase5-validation.md).

## Faz 6: deneme takibi

Home → Deneme Ekle → bilgi/bölüm sonuçları/kontrol → sunucu net özeti; Deneme Geçmişi → detay/düzenle/onaylı silme tamamlandı. Beş JWT korumalı `/api/mock-exams` uç noktası eklendi. Net ve toplam yalnız backend decimal hesabından gelir; yeni skor DTO alanları hassasiyet için JSON metni olarak taşınır. Blank sunucuda türetilir; edit eski snapshot kurallarını korur.

Yeni migration: `20261001114310_SnapshotMockSectionDisplay`. Backend çalıştırmadan önce mevcut kurulumdaki ortam değişkenleriyle `dotnet ef database update --project src/NetPusula.Infrastructure` uygulayın. Sayısal snapshot ve eski migration'lar değişmedi, yalnız tarihsel bölüm gösterim alanları eklendi.

Sözleşme, pagination, tarih/snapshot/silme ve manuel kontroller: [Deneme takibi](docs/mock-exam-tracking.md). Komut sonuçları, testler ve dosya listesi: [Faz 6 doğrulama](docs/phase6-validation.md). Gerçek PostgreSQL doğrulaması Docker motoru erişilemediği için hâlâ bekliyor.
