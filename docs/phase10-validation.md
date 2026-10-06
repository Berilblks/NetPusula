# Faz 10 — doğrulama çalışma kaydı

## Değişiklik öncesi baseline

`main`, HEAD `2c17c46`, origin `https://github.com/Berilblks/NetPusula.git`; çalışma ağacı temiz. Mimari, auth/JWT/refresh, endpoint/DTO, EF constraint, Flutter network/storage/lifecycle ve Android/iOS release config kaynakları incelendi.

2026-10-05 başlangıç komutları: dotnet restore/build başarılı (0 warning/error), test 183/183, pending model change yok; flutter pub get/gen-l10n/analyze başarılı, test 208/208. Flutter 37 yeni constraint-dışı paket sürümü bildiriyor; upgrade yapılmadı. NuGet include-transitive vulnerability taraması tüm projelerde bulgu vermedi. Kaynak secret taraması yalnız test fixture/UI tanımları ve ortam değişkenli README örneği buldu; gerçek credential bulunmadı. `.env.example` password alanı boştur.

Bu başlangıç kaydı ürün düzeltmelerinden önce oluşturuldu. Aşağıdaki sonuçlar 5–6 Ekim 2026 çalışmasına aittir.

## Hata kayıtları ve düzeltmeler

| Bulgu | Seviye / tekrar üretme / neden | Düzeltme ve regresyon |
|---|---|---|
| Production eksik DB ayarıyla açılıyordu | Orta; connection boş/bozuk iken host açılır; kontrol yalnız DbContext resolve sırasında | DatabaseConnectionOptions + Program startup validation; ReleaseHardeningTests iki negatif durum. AuthApiFactory/TestAuthConfiguration geçerli sentetik DB config sağlar. |
| Beklenmeyen 500 yanlış media type | Düşük; exception endpoint'i application/json döndürür | GlobalExceptionHandler explicit application/problem+json; ExceptionHandlerTests ve gerçek trigger-failure HTTP assertion. |
| Oturum sonrası geç response | Orta, defense-in-depth; pending 200/500 logout + yeni login sonrasında Dio caller'a ulaşabiliyordu (feature provider'ları zaten ayrı guard içeriyordu) | AuthInterceptor response/error generation check; Completer kontrollü iki test. |
| Çok sorgulu deneme okumasında karışık sürüm | Orta; sonuç tablosu lock barrier'ında parent SELECT tamamlanır, eşzamanlı edit commit olur; eski ad/yeni net döner | MockExamService list/detail RepeatableRead; gerçek PG race komutu önce detail'da başarısız, düzeltme sonrası detail ve history tutarlı geçti. |
| Offline istatistikte uzun loading/retry | Orta; gerçek APK + API kapatma; Riverpod default 10 retry ilk hatayı geciktiriyordu | Dashboard/statistics/detail/draft/catalogue FutureProvider retry=null. Statistics network/server/no-preparation testlerine yalnız bir çağrı assertion'ı; önce başarısız, sonra üçü başarılı. |

Yeni özellik, migration, business formula, API alanı veya bağımlılık sürümü değişikliği yoktur.

## Güvenlik / HTTP / gerçek PostgreSQL

- Kaynak secret audit: gerçek credential bulunmadı. Private-key/JWT/GitHub/API token/password/connection/.env adayları incelendi; test fixture ve UI password alan adları gerçek secret sayılmadı. Bu fazda oluşturulan disposable credentials yalnız ignored runtime dosyasında tutuldu; rapora alınmadı.
- Gerçek PostgreSQL16 ayrı rastgele isimli container, ayrı DB/user/port; kullanıcının postgres-db container'ına dokunulmadı. Dört migration temiz DB'ye uygulandı; ikinci update no-op; model change yok.
- Unique/partial active index, composite FK/RESTRICT ve snapshot/auth schema incelendi. Gerçek DB kullanıcı silme, negatif count, yabancı mock FK ve çok aktif hazırlık girişimlerini reddetti.
- Gerçek HTTP iki kullanıcı: register/login/me/catalogue/preparation/create/list/detail/edit/dashboard/statistics/delete/logout. Başka kullanıcının read/PUT/DELETE ve preparation PUT'u 404; boş kullanıcının analytics/history'si boş. Aktif hazırlık değişince eski kayıtlar yeni 500 kayıtlık aggregate'e karışmadı.
- Duplicate/case-normalized register, trim/case login, malformed/empty/long email/password; unknown/wrong-password aynı 401. JWT malformed/expired/signature/issuer/audience, refresh malformed/unknown/expired/replay/logout reddedildi. Sahiplik/Net/TotalNet/CreatedAt/family alanları, negatif/fractional/çok büyük sayılar, gelecekte tarih, uzun ad, eksik sonuç ve invalid/duplicate/arbitrary statistics query reddedildi. Diğer bölüm/date/group sınırları mevcut regresyonlarla korunur.
- Gerçek malformed JSON 400, >16KiB body 413, unsupported method 405; application/problem+json + no-store. Kontrollü DB exception 500 generic problem; SQL/stack/token istemciye sızmadı.
- Ayrı listener'da permit=2 ile login/refresh ortak bütçeyi tüketti; register + sahte X-Forwarded-For 429/Retry-After verdi. Unit theory üç endpoint'i ayrı ayrı kapsar. İlk harness beklenen login kodu 400 idi; mevcut güvenli sözleşme 401 olduğundan assertion düzeltildi ve gerçek HTTP tekrar geçti.
- Sekiz paralel preparation switch: en fazla bir aktif. Aynı refresh'e sekiz paralel istek: bir 200/yedi 401 ve replay sonrası ailede sıfır aktif refresh. Dört duplicate mock POST dört kayıt oluşturdu (idempotency iddiası yok). Paralel edit/delete yalnız 200/204/404, orphan yok.
- Geçici DB trigger ile preparation insert, mock result insert/update, mock parent delete, refresh rotation update ve logout revoke hataları oluşturuldu. Önceki aggregate/aktif hazırlık/token durumu korundu; trigger'lar finally ile kaldırıldı; üretim failure hook eklenmedi.
- Divisor 3/4/8, pozitif/sıfır/negatif/tekrarlayan kesir gerçek DB→API decimal-string doğrulandı. Aynı-gün interval sıfır, yeterli altı+ karşılaştırma ve 5/10/20/all range sayıları doğrulandı. .NET decimal sonlu hassasiyeti korunur; binary double skoru yok.

## Performans

500 aktif deneme/iki bölüm; her endpoint ısınma ardından beş ölçüm. pg_stat_statements ile SELECT sayısı (BEGIN/COMMIT hariç). Aynı bilgisayarda emulator/build yükü vardı; kapasite sertifikası değildir.

| Endpoint | Medyan HTTP ms | SELECT/request |
|---|---:|---:|
| dashboard | 24,60 | 3 |
| statistics all | 29,94 | 4 |
| statistics last5 | 26,53 | 4 |
| history pageSize100 | 26,45 | 4 |

N+1 gözlenmedi; bounded analytics ve history korunur. Flutter'da delilsiz rebuild optimizasyonu veya cache eklenmedi.

## Flutter / Android smoke

- Dio 400/403/409/429/500 yeni beş test: refresh/retry yok. Mevcut testler timeout, malformed payload, storage failure, simultaneous401, single refresh, ikinci401 sınırı, logout-during-refresh, range/user değişiminde geç yanıtı kapsar.
- Gerçek API kapatıldığında mock save hata/retry gösterdi; ad ve counts korunarak aynı taslak recovery'de kaydedildi. Statistics offline ilk hata sonrası görünür retry (son fix APK), API kapalı cold launch startup error/cihazdan çıkış; API açılıp retry ile session restore geçti. Edit/delete hata davranışı widget/controller regresyonlarında; ayrı gerçek offline edit/delete yapılmadı.
- Yeni disposable Android34 Google APIs x86_64 Pixel3 AVD D: üzerindeki ignored mobile/build/phase10-avd altında oluşturuldu. /data yaklaşık 5 GB boş; güncel APK install -r başarılı. Eski kullanıcı AVD'si silinmedi. İlk boot System UI ANR host yükü sırasında görüldü; Wait sonrasında düzeldi, ürün crash'i olarak sınıflandırılmadı.
- Faz 10 APK ile welcome→register→ALES onboarding→dashboard→add→history→detail→edit→statistics akışı gerçek API/PG üzerinde geçti. Son retry düzeltmesi sonrası APK yeniden derlenip kuruldu; cold session restore, statistics offline hata, startup offline/recovery, logout→login user B yeniden doğrulandı. B kendi boş dashboard'unu gördü; A'nın denemesi görünmedi. Final reinstall sonrası kayıt/onboarding/mutation zincirinin tamamı ikinci kez yürütülmedi; bu adımlar önceki Faz10 APK'sında ve final 215 test içinde doğrulandı.
- Home/background/foreground statistics'i korudu. Density540=320dp + fontScale2 + koyu tema gerçek ekranda taşma görülmedi; açık tema dashboard ve semantik chart metinleri kontrol edildi. Tam widget suite açık/koyu tema, 320px/2x, form/draft, selected controls, error, chart/distribution semantics regresyonlarını içerir. Tam TalkBack/fiziksel cihaz audit iddiası yok.

## Son komutlar ve test sayıları

| Komut | Sonuç |
|---|---|
| dotnet restore | Başarılı |
| dotnet build --no-restore | 0 warning / 0 error |
| dotnet test --no-build | 193/193; baseline183 +10 yeni |
| dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure | Değişiklik yok |
| flutter pub get / flutter gen-l10n | Başarılı |
| flutter analyze | Temiz |
| flutter test | 215/215; baseline208 +7 yeni, mevcut retry/media-type testleri güçlendirildi |
| flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=ALLOW_INSECURE_HTTP=true | Son APK başarılı, emulator install başarılı |
| flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://api.example.test | Son APK başarılı, 17,4 MB; placeholder endpoint/debug signing, yayın artifact'i değil |
| NuGet vulnerable include-transitive | Beş projede bilinen advisory yok |
| flutter pub outdated --json | 37 newer packages; raporlananlarda advisory/discontinued/retracted flag yok; pub get advisory uyarmadı. Upgrade yapılmadı |

Başarısız ara koşular gizlenmedi: üç eski production Health/CORS testinde eksik DB fixture (düzeltildi,193 geçti); açık isolated API yüzünden DLL copy kilidi (API durduruldu,build geçti); release download DNS storage.googleapis.com hatası (Gradle daemon yeniden başlatılıp tekrar başarılı). Flutter debug x86 deprecation ve AVD SDK XML3/4 compatibility uyarıları vardı. Release CupertinoIcons font uyarısı devam ediyor; [release-readiness](release-readiness.md) platform doğrulama sınırını açıklar.

## Dosya kapsamı ve karar

API: Program, yeni DatabaseConnectionOptions, GlobalExceptionHandler. Infrastructure: MockExamService. Backend tests: AuthApiFactory, TestAuthConfiguration, ExceptionHandlerTests, yeni ReleaseHardeningTests. Tekrar üretilebilir test aracı: backend/validation/phase10.py. Flutter: AuthInterceptor ve beş ağ provider'ının bulunduğu dashboard/statistics/mock/preparation application dosyaları; yeni release_hardening_test ve güçlendirilmiş statistics_test. Belgeler: README, architecture, security, release-readiness, bu kayıt.

MUST FIX / PHASE11 / post-MVP ayrımı ve exact package/bundle IDs [release-readiness.md](release-readiness.md) içindedir. Güvenlik sınırı [security.md](security.md). Denetlenen kapsamda açık critical/high ürün engeli yok; Faz 11 yapılandırmasına geçiş için uygun, iOS/production yayın onayı değil. Faz 11 başlatılmadı. Commit/push yapılmadı; öneri: `chore: harden application for release`.

## Son temizlik / Git

İzole API process'leri ve yalnız netpusula-phase10 container/volume kaldırıldı; runtime.json secret dosyası silindi. Kullanıcının postgres-db container'ı çalışmaya devam ediyor. Yeni disposable emülatör kapatıldı. Otomatik onay denetimi toplu klasör/Python bytecode silme komutlarını “blocked by policy” ile reddetti; detaylı gerekçe verilmedi. Dosya silmeyi başka araçla aşmaya çalışmadım: ignored mobile/build altındaki AVD, ekran görüntüleri ve loglar lokal kaldı. Yeni Python helper'ın __pycache__ dizini için dar kapsamlı ignore eklendi; kaynak olarak stage edilmemeli. İstenirse bu disposable AVD klasörü kullanıcı tarafından kaldırılabilir.

Son aday dosya taramasında private key/GitHub token/JWT literal/credential URL bulgusu yok. git diff --check başarılı; yalnız LF→CRLF bilgilendirme uyarıları var. 22 kaynak/test/belge/ignore dosyası değişik/yeni; staged dosya yok. HEAD 2c17c46, main korunuyor. Commit/push yok.
