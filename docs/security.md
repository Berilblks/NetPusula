# Güvenlik modeli

Faz 10 kapsamı mevcut MVP'nin kaynak, regresyon ve izole gerçek PostgreSQL/HTTP denetimidir. Bu çalışma bağımsız penetrasyon testi veya üretim kapasite sertifikası değildir. Kanıtlar ve sınırlar: [Faz 10 doğrulama](phase10-validation.md).

## Kimlik doğrulama ve oturum

Parolalar Identity V3 PBKDF2 (210.000 iterasyon) ile hash'lenir. E-posta trim/normalize edilir ve unique index ile korunur. Yanlış parola ve bilinmeyen hesap aynı generic 401 yanıtını verir. Duplicate registration 409 döndürür; bu mevcut sözleşme hesap varlığını belli eder. Email doğrulama/parola sıfırlama bu fazın kapsamı değildir.

Access JWT yalnız HS256/JWT, doğru issuer/audience/signature, zorunlu expiration ve geçerli GUID subject ile kabul edilir. Clock skew sıfırdır; varsayılan ömür 15 dakika (ayarlanabilir 1–60). Anahtar Base64 biçiminde 32–128 rastgele byte olmalıdır; kaynakta/default config'de gerçek anahtar yoktur. Eksik/bozuk JWT ayarı başlangıcı durdurur. Development dışındaki eksik/bozuk PostgreSQL connection string de artık başlangıcı durdurur; bu kontrol bağlantı erişilebilirliğini veya parola doğruluğunu kanıtlamaz.

Refresh token 256-bit rastgele değer, veritabanında yalnız SHA-256 hash; varsayılan ömür 30 gün. Rotation/replay/logout aynı aile kök satırının PostgreSQL `FOR UPDATE` kilidi altında çalışır. Rotation atomiktir; tekrar kullanılan token tüm aileyi iptal eder. Eşzamanlı aynı-token denemelerinde bir rotation başarılı olsa bile replay onun yeni refresh token'ını da iptal eder. Logout local secure storage'ı önce temizler, uzaktan aile iptalini best-effort yapar. Stateless access JWT logout sonrasında süresi dolana kadar geçerlidir; anlık access-token blacklist garantisi yoktur.

Flutter Android secure storage/iOS device-only keychain kullanır; password saklamaz. Backup Android'de kapalıdır. Shared refresh single-flight ve en fazla bir 401 retry vardır; non-401 yanıt tekrar edilmez. Oturum generation kontrolü istek, refresh, başarılı yanıt ve hata yanıtını kapsar. Logout/kullanıcı değişiminden sonra eski yanıt yayınlanmaz. Ambiguous refresh timeout/crash sonrasında eski refresh'i yeniden kullanmak yerine oturum kapatılır. Bu güvenlik davranışı offline süresi dolmuş oturumda yeniden login gerektirebilir.

## Sahiplik ve veri sınırı

`/api/auth/me`, user-exams, mock-exams, dashboard ve statistics JWT gerektirir. Kullanıcı kimliği yalnız doğrulanmış subject'ten gelir. Hazırlık/mutasyon sorguları kullanıcıya, dashboard/statistics/geçmiş aktif hazırlığa bağlıdır. Detay/edit/delete tarihsel hazırlıktaki kendi denemesine erişebilir; başka kullanıcı için 404 verir. İstemciden UserId/UserExamId/Net/TotalNet gibi alanlar kabul edilmez. Request DTO'ları unknown JSON alanlarını reddeder; entity serialize edilmez.

Integer count, doğru+yanlış+boş, bölüm kümesi, snapshot, target decimal scale, metin uzunluğu ve Türkiye takvim sınırları backend'de doğrulanır. Hassas route body sınırı 16 KiB'dir. Statistics last 5/10/20/all (son 500), history en fazla 100/page. Decimal net hesapları .NET decimal, JSON string; Flutter yalnız kesin biçimlendirme ve çizim yapar.

## HTTP, log ve yapılandırma

Development dışında HTTPS zorunlu, Swagger kapalıdır. CORS yalnız açıkça listelenmiş origin'lerdir; wildcard yoktur. Auth/private yanıtlar `no-store`, `no-cache`; 400/401/403/404/405/409/413/429/500 hata yüzeyi generic ProblemDetails'tır. SQL/stack/token istemciye dönmez. Global handler yalnız exception türünü kendi logger'ına yazar. EF sensitive logging/Dio LogInterceptor yoktur. Hosting/framework logları ayrıca deployment erişim/retention/redaction politikasına tabidir; üretimde verbose request/body log açılmamalıdır.

Flutter credential taşıyan client sabit origin, HTTPS, redirect kapalı, 10/15/10 saniye connect/receive/send timeout kullanır. HTTP istisnası yalnız debug build + açık development dart-define ile mümkündür. Release manifest cleartext kapalıdır; TLS bypass yoktur.

Auth endpoint'leri socket peer IP başına ortak fixed-window bütçesi kullanır (varsayılan 20/60 sn, queue yok). `X-Forwarded-For` kendiliğinden güvenilmez. Limit dolunca 429 + Retry-After gelir. Limit process-local'dir, restart/multi-instance arasında ortak değildir; NAT kullanıcıları aynı bütçeyi paylaşır. Reverse proxy arkasında trusted proxy ve edge rate-limit/TLS ayarı Faz 11 deployment kararıdır. Bu mekanizma DDoS koruması değildir.

## Bütünlük ve eşzamanlılık

Unique normalized email, refresh hash, exam/section kimliği ve mock-section index'leri; composite FK ve RESTRICT ilişkiler; snapshot/count/divisor/expiry check constraint'leri bulunur. Partial unique index bir kullanıcıda en fazla bir aktif hazırlığı garanti eder. Hazırlık değişimi ve mock mutation aynı kullanıcı satırını kilitler. Çok adımlı yazmalar transaction içindedir. Kontrollü trigger hatalarıyla hazırlık değişimi, mock create/update/delete, refresh rotation/logout rollback doğrulanmıştır.

Dashboard/statistics ve Faz 10 itibarıyla mock list/detail çoklu okumaları RepeatableRead snapshot içinde çalışır; eşzamanlı edit eski metadata ile yeni sonuçları birleştiremez. Bu seçim PostgreSQL'in READ COMMITTED altında ardışık SELECT'lerin farklı commit'leri görebilmesi nedeniyle gereklidir: [PostgreSQL 16 transaction isolation](https://www.postgresql.org/docs/16/transaction-iso.html).

Duplicate POST için idempotency key yoktur. Yanıt kaybından sonra kullanıcı tekrar gönderirse iki ayrı deneme oluşabilir; istemci otomatik POST retry yapmaz. Edit last-writer-wins'tir; distributed lock/optimistic version sözleşmesi yoktur.

## Operasyon sınırı

Gerçek secrets secret manager/korumalı environment üzerinden verilmeli; `.env.example` sadece template'tir. İmzalama dosyaları, local env, APK, bin/obj/build, log ve geçici validation verileri version control dışında kalır. NuGet ve Pub advisory sorguları bilinen kayıtları kapsar; bulgu olmaması güvenlik garantisi değildir. Üretim öncesi yeniden tarayın: [NuGet audit](https://learn.microsoft.com/nuget/concepts/auditing-packages), [Dart security advisories](https://dart.dev/tools/pub/security-advisories).
