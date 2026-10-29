# Premium tasarım Aşama 2.1

Giriş ve kayıt ekranları mevcut kayıt tasarımı temel alınarak aynı
`PremiumAuthPage` ve `AuthBrandHeader` bileşenlerini kullanır. Her ikisinde
68 px mevcut CompassMark logosu, aynı üst hizalama, tipografi, 24 px yatay
boşluk, yuvarlatılmış form alanları ve aynı gradient submit düğmesi vardır.
Girişteki ayrı koyu hero kaldırıldı. Logo altındaki tek slogan korundu;
başlıkların altındaki yinelenen açıklamalar kaldırıldı.

Karşılama ekranındaki genel pusula ikonu da mevcut NetPusula logosuyla değişti.
Hazırlık onboarding'inin beş adımında aynı marka başlığı ve temaya uyumlu
hafif lavanta radial arka plan kullanılır. İlk adımda tek kısa açıklama vardır.
Sınav seçimi, hedef doğrulaması, tarih seçimi, özet, geri/ileri ve kaydetme
işlevleri korunur. Hedef düzenleme ekranı eski wrapper'ını korur.

## Kapsam

Bu aşamada backend, PostgreSQL, migration, JWT/Google akışı, provider,
repository, routing veya kullanıcı verileri değiştirilmedi. Önceki commit
edilmemiş çalışmalar korunur. Commit/push yapılmaz.

Değişen sunum dosyaları:

- `mobile/lib/features/auth/presentation/premium_auth_page.dart`
- `mobile/lib/features/auth/presentation/login_screen.dart`
- `mobile/lib/features/auth/presentation/register_screen.dart`
- `mobile/lib/features/preparation/presentation/goal_screen.dart`
- `mobile/lib/features/welcome/welcome_screen.dart`
- `mobile/lib/l10n/app_tr.arb` ve üretilen localization Dart dosyaları
- `mobile/test/premium_auth_ui_test.dart`
- `mobile/test/preparation_widget_test.dart`
- Yeni `mobile/test/onboarding_premium_test.dart`
- Bu rapor

## Görsel doğrulama

Giriş/kayıt açık ve koyu tema önizlemeleri ile onboarding'in beş adımı
`mobile/build/auth-preview` altında üretildi. Bunlar gerçek Flutter widget
render'larıdır; onboarding verileri test fixture'larıdır. Dosyalar ignored'dır.
320 px genişlik, 2x yazı ve klavye açık senaryoları test edilir. İlk iki yeni
test hatası, testte klavye resize tamamlanmadan hit-test yapılmasından kaynaklandı;
yerleşimin tamamlanması beklenerek düzeltildi. İlk analyze'daki test lint'i düzeltildi.

Google hesabı ve kullanıcı verileri değiştirilmeden görsel inceleme yapılır;
cihazda mevcut oturum nedeniyle erişilemeyen onboarding adımları için bu
render'lar kullanılır. Gerçek hesapla yeni kayıt/hedef kaydetme yapılmaz.

## Son kontroller

- `flutter analyze`: temiz.
- `flutter test --concurrency=1`: **251/251 başarılı**; dört yeni onboarding tema/büyük yazı testi.
- Görsel render testi: **12/12 başarılı** (giriş/kayıt ve beş onboarding adımı).
- `git diff --check`: temiz.
- Android arm64 debug APK: başarılı (Gradle 83,6 saniye); mevcut Google Web
  client ID ve yerel development dart-defines korundu.
- Redmi Note 8: `install -r` başarılı; uygulama açıldı. Karşılama, giriş ve
  kayıt ekranları cihazda koyu temada görsel olarak kontrol edildi.
- Açık tema, büyük yazı, klavye ve onboarding'in beş adımı widget render/test
  ortamında doğrulandı. Son cihaz ekran görüntüsünde klavye açık değildi;
  gerçek cihazda klavye açık kontrolü tamamlanmış sayılmıyor. Gerçek kullanıcıyla
  onboarding oluşturma/kaydetme yapılmadı.
- Ekran görüntüleri ve APK `mobile/build` altında ignored kaldı.
