# Kullanıcı hazırlığı ve onboarding — Faz 5

## Yaşam döngüsü ve sahiplik

User üzerinde kalıcı bir sınav alanı yoktur. UserExam kullanıcının belirli bir dönemdeki hazırlığıdır. Aynı kullanıcının çok sayıda tarihsel kaydı olabilir, fakat en fazla bir tanesi aktiftir. POST yeni aktif hazırlık oluşturur ve mevcut aktifi aynı transaction içinde pasifleştirir. Satır, kimlik, ExamId ve geçmiş denemeler silinmez. Aktif hazırlıkla aynı sınav/hedef/tarih POST edilirse aynı kayıt döner; kaybolan cevap sonrası kullanıcı retry'ı gereksiz geçmiş oluşturmaz.

PUT yalnızca aktif kaydın hedef ve tarihini değiştirir. ExamId ve UserId değiştirilemez. Tarihsel kaydı düzenleme 409 döner; başka kullanıcıya ait ve bilinmeyen kimlik aynı 404 sonucunu üretir. ID ile GET listeleme/okuma endpoint'i yoktur. Aktif okuma yalnızca ICurrentUser.UserId ile filtrelenir.

PostgreSQL'de transaction başında kullanıcının Users satırı FOR UPDATE ile kilitlenir; aynı kullanıcıya ait create/update işlemleri farklı sunucu instance'larında da sıralanır. Eski aktif kayıt SaveChanges ile pasifleştirildikten sonra yeni satır eklenir; her iki save tek transaction içindedir, hata halinde birlikte rollback olur. `UX_UserExams_OneActivePerUser`, `UserId` üzerinde `WHERE "IsActive" = TRUE` unique partial index'idir; uygulama katmanı atlanırsa da iki aktif kayıt oluşamaz. SQLite test sağlayıcısı yazma transaction'ı ve aynı partial index'i kullanır. Unique/serialization/deadlock veya SQLite busy/constraint yarışı 409 olarak döner; sınırsız otomatik retry yoktur.

## API sözleşmesi

Tüm `/api/user-exams` uç noktaları JWT gerektirir; cache-control no-store, production HTTPS ve 16 KiB request body sınırı uygulanır. JSON içinde tanımlanmamış alanlar reddedilir; UserId eklenmesi kullanıcı değişikliğine yol açmaz, 400 olur.

| Uç nokta | Başarı | Diğer durumlar |
| --- | --- | --- |
| GET /api/user-exams/active | 200 DTO; aktif kayıt yoksa **204 boş gövde** | 401 / 5xx |
| POST /api/user-exams | 201 DTO, Location: /api/user-exams/active | 400 doğrulama, 404 aktif sınav bulunamadı, 409 yarış |
| PUT /api/user-exams/{id} | 200 DTO | 400 doğrulama, 404 bilinmeyen/yabancı ID, 409 tarihsel kayıt/yarış |

POST gövdesi:

```json
{"examId":"00000000-0000-0000-0000-000000000003","targetNet":80.25,"examDate":"2027-01-01"}
```

PUT gövdesi:

```json
{"targetNet":85.5,"examDate":"2027-02-01"}
```

Bunlar kullanıcı tarafından seçilmiş örnek tarihlerdir; resmi sınav tarihi iddiası değildir. Yanıt alanları: `id`, `exam { id, code, name, maximumTargetNet }`, `targetNet`, `examDate`, `createdAtUtc`, `updatedAtUtc` (ilk oluşturulmada null). EF entity, UserId ve auth alanları dönmez. `GET /api/exams` ve `/api/exams/{id}` mevcut alanları korur; nullable `maximumTargetNet` eklenmiştir. `/sections` sözleşmesi aynıdır.

## Net ve katalog doğrulaması

TargetNet pozitif decimal'dır. En fazla dört ondalık basamak ve mevcut PostgreSQL numeric(12,4) temsil aralığı (en fazla 99999999.9999) kabul edilir. Bu teknik temsil sınırı sınavın resmi maksimumu değildir. Mobile `NetTarget` dört basamak ölçekli int tutar; virgül/nokta kabul eder, JSON'a sayısal decimal metninin karşılığını gönderir. Virgül, harf veya bilimsel gösterimle hesaplama yapılmaz; client/body DTO'da UserId bulunmaz.

Bir üst sınır sadece `HasCompleteSectionConfiguration=true`, en az bir bölüm, tüm bölümler aktif ve GroupCode yoksa bölüm QuestionCount toplamından türetilir. Bu fazın mevcut ALES kataloğunda toplam 100'dür. Diğer beş seed sınav eksik yapılandırma nedeniyle null döndürür; yapay sınır/soru sayısı eklenmedi. Kısmi, emekliye ayrılan veya gruplu yapılandırmada yanlış toplam iddia edilmez. Flag, incelenmiş katalog migration'larıyla yönetilmelidir; gelecekte katalog değişirse completeness de gözden geçirilmelidir. Ceza böleni maksimumu değiştirmez: tüm yanıtlar doğruysa net soru sayısıdır.

## Tarih semantiği

DB `date`, .NET `DateOnly`, JSON `YYYY-MM-DD` kullanır. Sınav saati veya UTC midnight dönüşümü yoktur. Flutter date picker ve kaydetme doğrulaması cihazın güncel yerel takvim gününden önceki tarihleri engeller. Backend cihaz saatini güvenilir kabul etmez: TimeProvider.GetUtcNow() + 03:00 ile Türkiye takvimini esas alır; sunucu için geçmiş tarihleri 400 ile reddeder. MVP Türkiye odaklıdır; kullanıcı timezone profili eklenmedi. Türkiye dışında gece sınırında veya yanlış cihaz saatinde istemci kabul etse de sunucu reddedebilir; Türkçe mesaj Türkiye takvimini belirtir ve seçim korunur.

Bugün kabul edilir. Gün hesabı yerel yıl/ay/gün alanlarını UTC takvim tarihleri olarak karşılaştırır; DST/saat farkından kaynaklanan 23/25 saat hatası yoktur. Bugün “Bugün”, geçmiş “Sınav tarihi geçti”, gelecek “N gün kaldı” olarak görünür. Negatif gün sayısı gösterilmez. Geçmiş tarihli mevcut hazırlık silinmez veya kendiliğinden pasifleştirilmez; düzenlerken güncel/gelecek bir tarih seçilmelidir.

## Flutter durum ve yönlendirme

AuthState değiştirilmedi. Kayıt/giriş auth yanıtındaki doğrulanmış profili kullanır; restart restore mevcut /me kontrolünü korur. Ardından `PreparationController` authenticated kullanıcının aktif hazırlığını yükler.

- `preparationRepositoryProvider`: mevcut authorized Dio ve public catalogue Dio üzerinden sözleşmeyi uygular.
- `preparationControllerProvider`: idle, loading, none, ready, error + saving/issue/active durumları.
- `examCatalogueProvider`: API'den aktif sınavlar, loading/error/empty/retry.
- `localNowProvider`: yerel gün hesabı için test edilebilir saat.

Logout/kullanıcı değişiminde hazırlık sıfırlanır. İstek nesli kontrolü geç tamamlanan lookup/save sonucunun yeni oturuma yazılmasını engeller. Mevcut auth interceptor/secure storage/refresh single-flight korunmuştur.

Router: anonim → welcome/login/register; authenticated + yükleniyor/hata → `/preparation`; authenticated + 204 → `/onboarding`; aktif kayıt → `/home` veya `/goal/edit`. Home'a deep link onboarding kontrolünü atlatamaz. Loading sırasında home gösterilmez. 404, timeout, bozuk 200 gövdesi veya bağlantı hatası **204 yerine yorumlanmaz**; retry edilebilir korumalı hata ekranı vardır. Offline cache bu fazda yoktur.

## Ekran akışı

Onboarding beş adım: karşılama → API sınav kartları → hedef net → Material tarih seçici → özet/kaydet. İlerleme göstergesi, geri tuşu, SafeArea, kaydırma, klavye ve büyük yazı desteklenir. Tek sınav seçilir; seçim yapılmadan devam edilemez. Hata halinde mevcut adım, sınav, net ve tarih bellekte kalır; retry mümkündür. Saving sırasında ikinci submit/geri engellenir. Uygulama tamamen kapanırsa kaydedilmemiş taslak kalıcı değildir.

Home selamlama, sınav, hedef, seçilen tarih, kalan gün, “Deneme takibi yakında burada olacak.”, hedef düzenleme ve logout içerir. Düzenleme yalnızca hedef/tarihtir; sınav değişikliği UI'si bu fazda yoktur. Backend yeni sınava geçişi POST ile destekler. 404/409 düzenleme hatalarında değişiklikler korunur; eski hazırlık başka oturumda değiştirilmişse yeni oturum açarak aktif hazırlık yeniden yüklenebilir. Çok cihazlı anlık senkronizasyon yoktur; eşzamanlı geçerli goal update'lerinde kilit sırasındaki son işlem geçerlidir.

400 alan hataları, 401/session, 404, 409, 429, 5xx, timeout ve ağ hataları yerel güvenli mesajlara çevrilir. Raw server JSON veya exception gösterilmez. Mevcut token yenileme davranışı aynıdır.

## Migration ve yerel çalıştırma

Yeni migration: `20260930173315_EnforceSingleActiveUserExam`. Önceki iki migration değiştirilmedi. Yeni Exam completeness alanını ekler; mevcut ALES seed'ini tam olarak işaretler. Var olan mükerrer aktif hazırlıklarda CreatedAtUtc DESC, Id DESC sırasındaki en yeniyi aktif bırakır; diğerlerine UpdatedAtUtc yazar ve pasifleştirir. Ardından unique index oluşturulur. Hiçbir tarihçe satırı silinmez. Down index/flag'i kaldırır, eski mükerrer aktivasyonları geri açmaz. Production migration öncesi yedek ve etkilenecek kullanıcıların gözden geçirilmesi uygundur.

Backend dizininde mevcut bağlantı ortam değişkeniyle:

```powershell
dotnet tool restore
dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure
dotnet ef database update --project src/NetPusula.Infrastructure
dotnet ef database update --project src/NetPusula.Infrastructure
dotnet run --project src/NetPusula.Api -- --check-database
```

API/Android emulator başlatma için [mobile-authentication.md](mobile-authentication.md) komutları aynıdır. Önce migration, sonra API/mobile çalıştırılmalıdır. SQL üretimi ve SQLite migration testi canlı PostgreSQL doğrulaması yerine geçmez.

## Manuel kabul

1. Yeni hesap: welcome → onboarding; sınav listesi backend'den gelmeli.
2. Sınav seçmeden devam edilememeli; 0/negatif/aşırı hassas ve bilinen maksimumu aşan netler reddedilmeli.
3. Virgüllü 80,25 net, bugün/gelecek tarih ve özet → home; resmi tarih otomatik uydurulmamalı.
4. Logout/login ve uygulama restart → hazırlık korunmalı, onboarding atlanmalı.
5. Home'dan hedef/tarih düzenle → güncel değerler; sınav değiştirme alanı olmamalı.
6. Aktif lookup sırasında offline → retry; onboarding'e zorlanmamalı. Save ağ hatası → seçimler korunmalı.
7. Başka kullanıcıyla giriş → önceki hazırlık görünmemeli; API'de yabancı ID update 404 olmalı.
8. Yeni hazırlık POST → eskisi pasif ve geçmiş kayıtlar korunmuş; DB'de en fazla bir aktif satır.
9. Gerçek PostgreSQL'de eşzamanlı create/update, migration iki kez ve row-lock davranışını doğrulayın.
10. Küçük fiziksel Android/iOS ekranlarında klavye, büyük yazı, geri ve date picker'ı kontrol edin.
