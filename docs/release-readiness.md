# Release hazırlığı — Faz 10

## Karar

Mevcut doğrulamada açık critical/high auth, cross-user leak, veri bütünlüğü, migration veya Android derleme engeli bulunmadı. Mevcut MVP için Faz 11 hazırlığına geçilebilir; bu belge mağazaya/üretime yayın onayı değildir. iOS build ve cihaz smoke yapılmadı (Windows ortamı). Aşağıdaki platform/operasyon kararları tamamlanmadan yayın yapılmamalıdır.

## MUST FIX before Phase 11

Doğrulanan kapsamda açık ürün engeli yok. Faz 10 değişiklikleri henüz kullanıcı incelemesi/commit bekliyor. Fiziksel cihazlar, iOS ve gerçek production altyapısı bu sonucun dışında.

## PHASE 11 yapılandırma/karar

- Android applicationId/namespace ve iOS Runner bundle ID: `dev.netpusula.netpusula`; değiştirilmedi. RunnerTests: `dev.netpusula.netpusula.RunnerTests`. Nihai mağaza kimliği kararı gerekli.
- Android release halen debug signing config kullanıyor. Gerçek anahtar oluşturulmadı. Upload key/keystore yönetimi ve release signing şart; doğrulama APK'sını yayınlamayın.
- Android compile SDK 36, target SDK 35, min SDK 23; versionName 1.0.0/versionCode 1, Java 11, NDK 27.0.12077973. Paket manifestinde INTERNET ve AndroidX'in signature-level DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION var. Tehlikeli runtime permission yok. App label NetPusula; backup/cleartext release'de false, debuggable yok. Debug HTTP yalnız açık development flag ile.
- iOS deployment target 12.0; kurulu secure-storage Darwin 0.3.2 pod minimumu da 12.0. Info.plist ATS istisnası ve gereksiz permission yok; device-only/unlocked keychain, sync kapalı. Team/provisioning, gerçek cihaz keychain/upgrade/backup davranışı ve Xcode archive doğrulanmalı. Burada iOS build iddiası yok.
- Release derlemesinde CupertinoIcons font uyarısı var; kaynakta doğrudan Cupertino icon kullanımı yok. iOS/adaptive ikon görünümü cihazda doğrulanmalı; gerekliliği doğrulanırsa uygun font asset eklenmeli. Uyarı gizlenmedi; Android build başarılı.
- Production domain/TLS, secret manager/JWT rotation, trusted reverse-proxy, edge rate limit, CORS origin, database least privilege/TLS, backup-restore ve izleme/log retention ayarları belirlenmeli. Health endpoint DB readiness garantisi vermez.
- SDK/paket yükseltmeleri ayrı kontrollü iş: Flutter 3.29/Dart 3.7; pub outdated 37 daha yeni sürüm bildirdi (ör. secure_storage 11, go_router 18). Toplu upgrade yapılmadı. Yayından önce NuGet/Pub advisory yeniden çalıştırılmalı.

## Post-MVP kabul edilebilir sınırlar

Duplicate POST idempotency garantisi yok; response kaybı sonrası manuel tekrar ayrı deneme oluşturabilir. Edit last-writer-wins. Logout sonrası mevcut access JWT kalan kısa ömründe geçerlidir; refresh ailesi iptal edilir. Process-local IP rate limit edge DDoS koruması değildir. Süresi dolmuş oturumda ambiguous offline refresh güvenlik için yeniden login gerektirebilir. Statistik all son 500, history 100/page ile sınırlı. Performans ölçümleri tek yerel makinede, üretim kapasite sertifikası değildir.

## Kanıt ve tekrar

[Faz 10 doğrulama](phase10-validation.md), [güvenlik modeli](security.md). İzole gerçek PostgreSQL kontrolleri için backend build sonrası `python -X utf8 backend/validation/phase10.py setup`, `race`, `check`, ardından her durumda `cleanup`. Sabit local portlar 55440/5080/5081 boş olmalı. Docker PostgreSQL16 image ve Python stdlib kullanılır; mevcut PostgreSQL'e bağlanmaz. Secret'lar yalnız ignored obj/phase10/runtime.json içinde rastgele üretilir, cleanup siler. Test sonuçları obj/build altında lokaldir; scripts source gerçek credential içermez.
