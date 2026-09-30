# Faz 3 doğrulama — 2026-09-30

## Sonuç
| Kontrol | Sonuç |
| --- | --- |
| dotnet restore | Başarılı |
| dotnet build --no-restore | 0 hata, 0 uyarı; son çalışma 3.99 saniye |
| dotnet test --no-build | 63 başarılı, 0 başarısız, 0 atlanan; son çalışma 14 saniye |
| dotnet format --verify-no-changes --no-restore --exclude src/NetPusula.Infrastructure/Migrations | Başarılı |
| flutter analyze | No issues found (4.2 saniye) |
| flutter test | 2 başarılı |
| dotnet ef migrations add AddAuthentication --project src/NetPusula.Infrastructure --output-dir Migrations | Gerçek EF CLI ile üretildi |
| dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure | Model farkı yok |
| dotnet ef migrations script --idempotent --project src/NetPusula.Infrastructure --output obj/Authentication.sql | Başarılı, SQL incelendi |
| dotnet list package --vulnerable --include-transitive | Beş projede bilinen açık raporlanmadı |
| docker version | İstemci 29.2.0; Docker Linux engine pipe bulunamadı |

Migration: 20260930115643_AddAuthentication. Yalnızca RefreshTokens tablosu, expiry CHECK, UNIQUE hash, sorgu indeksleri ve RESTRICT FK'leri ekler. InitialDomainModel ve Designer dosyalarının işlem öncesi/sonrası SHA-256 değerleri aynı; ilk migration değiştirilmedi.

İlk auth build sırasında .NET 8 WriteAsJsonAsync overload seçimi hatası düzeltildi. Son build ve tüm testler başarılıdır. Generated migration dosyaları format işleminden hariç tutuldu; kaynak kod biçim kontrolü temizdir.

## Testler
Önceki 23 backend testi korunur. 40 yeni auth/security vakası:
- Geçerli kayıt; trim/normalize; built-in hasher doğrulaması, plaintext tutulmaması.
- Raw refresh yerine SHA-256; yalnızca güvenli me DTO alanları; auth loglarında parola/JWT/refresh/hash/key bulunmaması.
- Duplicate/case-insensitive email; eşzamanlı kayıt sonucu tek kullanıcı/session.
- Boş/geçersiz email, kısa/zayıf/null/çok uzun parola ve isim validation.
- Doğru login, yanlış parola/bilinmeyen email için aynı genel yanıt.
- Null-hash eski hesabın reddi; düşük work-factor hash'in login ile yükseltilmesi.
- Eksik JWT ile me reddi, gerçek JWT ile me kabulü.
- Expired/not-before-future, yanlış issuer/audience/signature/subject, unsigned ve bozuk JWT reddi.
- Refresh rotation, eski token replay'i, yalnızca ilgili family iptali; diğer login session'ının korunması.
- Tam expiry sınırında refresh reddi; null/boş/bozuk/bilinmeyen refresh reddi.
- Logout ve tekrarı, iptal sonrası refresh reddi; logout sonrası access JWT'nin süre sonuna kadar çalışması.
- Eski rotated token ile logout'un replacement'ı da iptal etmesi.
- Gerçek eşzamanlı HTTP refresh isteklerinden yalnızca birinin başarılı olması; replay sonucunda ailenin kapanması.
- Persistence UNIQUE hash, optimistic concurrency ve User silme RESTRICT.
- Rate limit 429/Retry-After, spoof edilmiş X-Forwarded-For ile limitin aşılamaması, public health'in açık kalması.
- Eksik signing key ile startup reddi; bozuk JSON problem yanıtları; üretimde auth HTTPS kontrolü.

Auth testleri ayrı SQLite dosyaları ve ayrı bağlantılar kullanır; aynı paylaşımlı connection ile sahte concurrency testi yapılmaz. SQLite testleri PostgreSQL row lock davranışını kanıtlamaz.

## Güvenlik incelemesi
- PasswordHasher<User> IdentityV3 kullanımı ve rehash akışı incelendi; özel parola kriptografisi yok.
- Token RNG 32 kriptografik bayt; refresh DB alanı yalnızca hash.
- Kaynak/config taramasında gerçek JWT key/parola yok. Test key'leri çalışma anında rastgele üretilir. .env ve obj/Authentication.sql ignore edilir.
- Auth log ifadeleri incelendi: olay ve UserId; kullanıcı parolası, token, header veya key yok. Secret-string log testleri başarılı.
- /me RequireAuthorization; subject helper yalnızca authenticated principal kabul eder. Public health/exams korunur.
- JWT issuer/audience/signature/algorithm/type/lifetime/subject kontrolleri açık; ClockSkew=0.
- Login enumeration yanıtı ortak, dummy hasher çalışır. Kayıtta 409 ile varlık bilgisi verilmesi bilinçli sözleşmedir; docs/authentication.md içinde açıklanır.
- Rotation transaction + family root row lock + concurrency token; logout/replay aynı root lock yolunu kullanır.
- Üretimde HTTPS kontrolü, no-store yanıtları, gövde sınırı ve yerleşik rate limiter mevcut.
- Custom global handler exception mesajlarını loglamak yerine türünü kaydeder. Altyapı logları ve production proxy ayarları ayrıca korunmalıdır.

## Doğrulanamayanlar / manuel adımlar
Docker motoru hâlâ erişilemedi: PostgreSQL başlatma, gerçek migration uygulaması, canlı auth persistence ve gerçek PostgreSQL eşzamanlı row-lock testi çalıştırılamadı. README/authentication.md içindeki adımlarla Docker Linux engine çalıştıktan sonra her iki migration uygulanmalı, update tekrarı, --check-database ve auth akışları doğrulanmalıdır.

API web host için Jwt__SigningKey artık zorunludur. README güvenli yerel rastgele key oluşturma komutunu içerir. Üretimde sabit key, HTTPS ve güvenilen proxy/ingress ayarları yapılmalıdır. Rate limiter process-local; distributed değildir. Logout JWT'yi anında iptal etmez. Katı replay politikası nedeniyle istemci refresh'i tekilleştirmelidir. Cleanup/key rotation/email doğrulama/parola sıfırlama iş akışları bu fazda eklenmedi.

## Dosyalar
Yeni:
- Domain/RefreshToken.cs
- Application/Auth/AuthContracts.cs, AuthValidation.cs
- Infrastructure/Auth/AuthService.cs, PasswordTimingHash.cs, RefreshTokenConfiguration.cs, RefreshTokenSecrets.cs
- Api/Auth/AuthEndpoints.cs, AuthSetup.cs, CurrentUser.cs, JwtOptions.cs, JwtTokenIssuer.cs
- Infrastructure/Migrations/20260930115643_AddAuthentication.cs ve .Designer.cs
- Tests/TestAuthConfiguration.cs, AuthApiFactory.cs, AuthTests.cs, AuthSecurityTests.cs
- docs/authentication.md, docs/phase3-validation.md

Değişen:
- Domain/User.cs: ortak email normalizasyonu, hash setter.
- Infrastructure/NetPusulaDbContext.cs ve migration model snapshot.
- Api/Program.cs, GlobalExceptionHandler.cs, appsettings.json.
- Api ve Infrastructure csproj: JwtBearer/Identity.Core 8.0.31.
- HealthTests.cs ve ExamApiTests.cs: gerçek JWT yapılandırması için rastgele test anahtarı.
- README.md ve docs/architecture.md.

Yukarıdaki katman yolları backend/src/NetPusula.* altında, testler backend/tests/NetPusula.Tests altındadır. Flutter kaynakları değiştirilmedi. InitialDomainModel korunmuştur. Commit/stage işlemi yapılmadı; depoda henüz ilk commit olmadığından git status tüm başlangıç dosyalarını untracked gösterir.

Önerilen commit: feat: add secure backend authentication.

