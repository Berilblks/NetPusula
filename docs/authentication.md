# Backend authentication — Faz 3

## Katmanlar
Domain: User hash alanı/normalizasyon ve RefreshToken metadata.
Application: DTO/validation, IAuthService, IAccessTokenIssuer, ICurrentUser.
Infrastructure: EF persistence, yerleşik parola hasher'ı ile auth akışları ve refresh rotation.
Api: JWT üretim/doğrulama, endpoint'ler, current-user helper, hız sınırı ve config validation.

Flutter değişmedi. Sosyal giriş, email doğrulama, parola sıfırlama/değiştirme ve cihaz yönetimi yoktur.

## API
| Yöntem/yol | JSON isteği | Başarı |
| --- | --- | --- |
| POST /api/auth/register | displayName, email, password | 201 + auth yanıtı |
| POST /api/auth/login | email, password | 200 + auth yanıtı |
| POST /api/auth/refresh | refreshToken | 200 + yeni auth yanıtı |
| POST /api/auth/logout | refreshToken | 204 |
| GET /api/auth/me | Authorization: Bearer access-token | 200 + id/displayName/email |

Auth yanıtı: accessToken, accessTokenExpiresAtUtc, refreshToken, refreshTokenExpiresAtUtc, tokenType (Bearer), user (id/displayName/email). Entity, hash veya internal session metadata dönmez.

İsim trim edilir, 2–120 UTF-16 karakterdir. Email trim + invariant uppercase NormalizedEmail ile eşsizdir; maksimum 254 ASCII karakter ve mailbox biçimi. Display-name syntax, whitespace/control ve Unicode mailbox kabul edilmez. IDN için ASCII/punycode kullanılabilir; daha geniş uluslararası email desteği ayrı karar gerektirir.

Parola 8–128 UTF-16 karakter; en az bir harf ve bir rakam, kontrol karakteri yok. Boşluk ve özel karakterler serbesttir; parola trim/normalize edilmez. Yerleşik PasswordHasher<User>, IdentityV3, PBKDF2-HMAC-SHA512, 210000 iteration kullanılır. Salt/format hasher tarafından yönetilir. SuccessRehashNeeded login sırasında uygulanır. PasswordHash=null eski kullanıcılar login olamaz.

Validation → 400 problem JSON; login/refresh hataları → genel 401. Bilinmeyen email ve yanlış parola yanıtları aynıdır. Bilinmeyen/null-hash hesap için gerçek dummy hash doğrulaması yapılır; bu zamanlama farkını azaltır, kesin sabit süre garantisi değildir. Duplicate email kayıt sırasında 409 döner; bu bilinçli sözleşme kayıt üzerinden email varlığını gösterebilir. UNIQUE indeks ve atomik SaveChanges eşzamanlı kayıt yarışını korur.

Bozuk JSON/medya türü genel problem yanıtı, throttling 429 + Retry-After döner. Auth yanıtları no-store'dur; Kestrel gövde sınırı 16 KiB. Üretimde auth HTTP yönlendirilir veya HTTPS yoksa reddedilir. İstek baştan TLS ile gönderilmelidir.

## Yapılandırma
| Ortam anahtarı | Varsayılan/sınır |
| --- | --- |
| Jwt__Issuer | NetPusula, zorunlu |
| Jwt__Audience | NetPusula.Mobile, zorunlu |
| Jwt__SigningKey | Varsayılan yok; Base64 olarak 32–128 rastgele bayt |
| Jwt__AccessTokenMinutes | 15; 1–60 |
| Auth__RefreshTokenDays | 30; 1–90 |
| AuthRateLimit__PermitLimit | 20; 1–1000 |
| AuthRateLimit__WindowSeconds | 60; 1–3600 |

Geçersiz/eksik JWT ayarı web host başlangıcını durdurur. Migration CLI design-time factory ile JWT key gerektirmeden çalışır. --check-database web host başlatmaz.

API çalıştırılacak PowerShell penceresinde:

```powershell
$env:Jwt__SigningKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
cd backend
dotnet tool restore
# ConnectionStrings__Database değerini README'deki gibi yerel DB için ayarlayın.
dotnet ef database update --project src/NetPusula.Infrastructure
dotnet run --project src/NetPusula.Api
```

Komut key'i ekrana/dosyaya yazmaz. Yeniden üretmek eski access JWT'lerini geçersiz kılar. Üretimde sabit güçlü key secret manager/environment üzerinden tüm instance'lara verilmeli, key rotation planlanmalıdır. MVP tek key kullanır; çoklu key/kid rotasyonu yoktur. .env yalnızca Compose tarafından okunur; API otomatik okumaz. JWT key mobil istemciye verilmez.

JWT HS256 kullanır; sub (UserId), jti, issuer/audience/nbf/exp dışında kişisel claim yoktur. Issuer, audience, signature, lifetime/not-before, algorithm, token type ve Guid subject doğrulanır. ClockSkew=0, saatler UTC ve senkron olmalıdır. ICurrentUser korumalı endpoint'ler için UserId sağlar. /health ve /exams anonim kalır.

## Refresh ve eşzamanlılık
32 bayt kriptografik RandomNumberGenerator çıktısı uppercase hex olarak istemciye verilir. Yalnızca SHA-256 hash'i saklanır. SHA-256 yüksek entropili token içindir, parola için değildir. Token tam değeriyle gönderilir; lowercase/whitespace kabul edilmez.

RefreshTokens: Id, UserId, FamilyId, TokenHash, CreatedAtUtc, ExpiresAtUtc, RevokedAtUtc, ReplacedByTokenId. TokenHash UNIQUE; UserId/FamilyId/ExpiresAtUtc/replacement indeksleri; expiry > creation CHECK. User/replacement FK'leri RESTRICT. RevokedAtUtc concurrency token'dır.

Kayıt/login ayrı aile açar; FamilyId ilk token'ın Id değeridir. Refresh:
1. Hash ile token bulunur, transaction açılır.
2. PostgreSQL'de değişmez kök satırı SELECT ... FOR UPDATE ile kilitlenir.
3. Token kilitten sonra yeniden okunur; süre/revocation kontrol edilir.
4. Yeni token eklenir, eski token revoke + replacement ile işaretlenir.
5. JWT hazırlanır, transaction commit olur, yanıt döner.

Rotation/logout/replay aynı kökü kilitler; farklı instance'larda da bir session seri işlenir. EF concurrency check ek savunmadır; kaybeden update ve yeni token rollback edilir. PostgreSQL üretim sağlayıcısıdır, SQLite yalnızca test içindir.

Revoked token tekrar gelirse o ailedeki tüm aktif token'lar iptal edilir; diğer login aileleri etkilenmez. Aynı token'la eşzamanlı iki refresh'te biri kazanır; ikinci replay sayılır ve kazananın yeni refresh token'ı da iptal edilir. İstemci refresh'i tekilleştirmelidir. Kaybolan yanıt sonrası eski token'ı otomatik retry etmek yeniden login gerektirebilir; bu katı replay politikası bilinçlidir.

Refresh süresi her rotation'da yeniden başlar (30 gün kayan süre); mutlak session sınırı yoktur. Cleanup işi eklenmedi. Aktif soy zinciri varken süresi dolmuş/revoked kök dahil aile kayıtları silinmemelidir: lock/replay için gereklidir. PostgreSQL'de kök yoksa işlem durur. Bakım tüm aileyi, FK ve replay saklama süresini dikkate almalıdır.

Logout access JWT istemez; refresh secret'a sahip olmak iptal yetkisidir. Eski rotated token dahil verilen token'ın ailesini iptal eder. Bilinmeyen/boş/expired/revoked değerler aynı 204 sonucunu verir (geçerli JSON DTO gerekir). JWT denylist yoktur: logout/replay sonrası mevcut access token kısa süresi dolana kadar geçerlidir.

## Rate limit, log ve dağıtım
Register/login/refresh/logout socket-IP bazlı fixed-window kovasını paylaşır: 20/60 sn, kuyruk yok. X-Forwarded-For doğrudan okunmaz. State process belleğindedir, restart ile sıfırlanır ve instance'lar arasında paylaşılmaz. Güvenilen reverse-proxy/forwarded-header ve HTTPS termination ayarları dağıtımda yapılmalıdır; aksi halde ortak proxy IP aynı kovayı paylaşır. Ingress/WAF katmanı ek koruma sağlamalıdır; Redis yoktur.

Auth logları yalnızca olay türü/gerektiğinde UserId içerir. Password/JWT/refresh/hash/key/header yazılmaz. Request-body/Authorization loglama ve EF sensitive data logging açılmamalıdır. Custom global handler exception mesajı yerine türünü kaydeder. Altyapı logları erişim denetimi altında tutulmalıdır. Testler loglara secret sızıntısını kontrol eder.

## Migration ve sınırlar
20260930115643_AddAuthentication gerçek EF CLI çıktısıdır; InitialDomainModel korunmuştur. Migration yalnızca RefreshTokens tablosu/kısıt/indekslerini ekler. Pending-model kontrolü ve idempotent SQL script üretimi yapıldı.

SQLite üzerinde API, persistence, concurrency ve regression testleri geçer. Docker motoruna erişilemediğinden gerçek PostgreSQL row-lock ve migration uygulaması bu ortamda doğrulanmadı. Yayın öncesi PostgreSQL üzerinde migration, auth akışları ve eşzamanlı refresh kontrolü gerekir. Sonuçlar phase3-validation.md içindedir.

Referanslar: [Microsoft JWT Bearer](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication), [yerleşik rate limiting](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit).

