# Faz 9 doğrulama — mobil deneyim

## Kapsam ve başlangıç

Başlangıç `main`, HEAD `d665dd9` (Faz 8). Faz 1–8 işlevleri korunarak yalnız mobil presentation/theme/localization, UI testleri ve belgeler değiştirildi. Backend, API, analytics formülleri, model/migration, Flutter repository/domain/provider/router ve dependency sürümleri değişmedi. Commit/push yapılmadı; Faz 10 başlatılmadı.

UI denetimi düzenleme öncesi tamamlandı; bulgular, token'lar, bileşenler ve ekran kararları [design-system.md](design-system.md) içindedir.

## Komut sonuçları

| Kontrol | Sonuç |
| --- | --- |
| `dotnet restore` | Başarılı |
| `dotnet build --no-restore` | Başarılı; 0 warning, 0 error |
| `dotnet test --no-build` | 183/183; backend yeni test yok |
| `dotnet ef migrations has-pending-model-changes --project src/NetPusula.Infrastructure` | Pending model change yok |
| `flutter pub get` | Başarılı; 37 paketin constraint dışı yeni sürüm bildirimi; upgrade yapılmadı |
| `flutter gen-l10n` | Başarılı; generated Dart repo geleneğiyle korunur |
| `flutter analyze` | No issues found |
| `flutter test` | 208/208; önceki 173 + yeni 35 |
| Android debug APK | Başarılı; son assembleDebug 21,4 s |
| `git diff --check` | Temiz |

Backend komutları `backend`, Flutter komutları `mobile` dizininde çalıştırıldı. APK komutu:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=ALLOW_INSECURE_HTTP=true
```

Flutter SDK Android x86 desteğinin gelecek sürümde kaldırılacağını bildirdi. Bu SDK bildirimi gizlenmedi; Gradle derlemesi başarılı. Paket/lockfile içerik değişikliği yoktur.

İlk UI test geçişlerinde lazy list'te henüz oluşturulmamış/ekran dışındaki butonlara test tıklaması, selection semantics'in parent yerine child node'da olması ve test-only yanlış getter/import kullanımları düzeltildi. Son süitte başarısız/atlanmış test yoktur. Test helper artık scroll sonrası layout pump ve hitTestable assertion yapar; uygulama assertion'ları kaldırılmadı.

## Test kapsamı

Yeni `mobile/test/design_system_test.dart` 35 test içerir:

- Welcome, login, register, onboarding hedef/tarih/özet, dashboard, statistics, history, detail ve mock review: her biri 320×640, 1× ve 2× yazıda (18 test).
- Seçili sınav radio semantics ve adım etiketi; statistics seçili range/bölüm; chart tarih/ad/signed value semantics; ayrı cevap çubuğu etiketleri.
- Bölüme yakın geçersiz cevap sayısı; keyboard açıkken erişilebilir eylemler; edit prepopulation; onaylı delete ve tek snackbar; history empty CTA.
- Hedef farkı için pozitif/negatif/sıfır sunumu; güvenli server error + retry; busy submit disable/etiket/live semantics.
- Açık/koyu önemli metin renklerinin 4.5:1 kontrastı; sistem koyu tema geçişi.

Önceki 173 test auth form validation, parola visibility/submit, loading/network/server error, no preparation, routing, goal draft, create/edit/delete ve merkezi invalidation, sıfır/tek/çok nokta ve negatif chart, grouped sections, empty result, rapid range switching, logout/user change stale response, exact decimal formatting, pull-to-refresh ve aktif hazırlık kapsamını korur. `statistics_test.dart` dashboard girişinin yeni konumuna scroll eder; `widget_test.dart` welcome microcopy ve güvenli scroll/tap helper'ını günceller. Arbitrary sleep/delay eklenmedi.

## Emülatör ve gerçek API görsel denetimi

Pixel_3 AVD, kalıcı AVD verisini değiştirmeyen `-read-only -no-snapshot` oturumunda çalıştırıldı. İlk GPU denemesi siyah ekran verdi; software GPU ile soğuk açılış sonrası gerçek screenshot'lar incelendi. Bir System UI yanıt vermiyor dialog'u Wait ile geçildi. Emülatörün mevcut uçak modu kapatıldı. API host allowlist yalnız geçici süreç ortamında `10.0.2.2` için genişletildi; proje appsettings dosyaları değiştirilmedi.

İzole `netpusula-phase9` Docker Compose projesinde PostgreSQL 16, port 55439 ve disposable veritabanı kullanıldı. Mevcut migration'lar uygulandı; sentetik Deniz hesabıyla uygulamada login, beş adımlı ALES hazırlığı ve bir deneme kaydı yapıldı. Kaydedilen 40,00 net sunucudan gösterildi. Kullanıcının mevcut `postgres-db` ortamına müdahale edilmedi.

Gerçek piksel görüntüsü incelenen ekranlar:

| Ekran | Kontrol / yerel screenshot |
| --- | --- |
| Welcome | Pusula, iki eylem, status-bar kontrastı; `welcome-final.png` |
| Login | Form hiyerarşisi, klavye ve güvenli hata durumu; `login.png` |
| Register | Form/yardım metni/parola visibility kontrolleri; `register.png` |
| Onboarding | Adım/progress, hedef input, seçilen sınav ve tarih/özet akışı; `onboarding-goal.png`, `onboarding-target.png` |
| Dashboard | Hazırlık bağlamı, empty CTA ve populated net kartı; `dashboard-empty.png`, `dashboard.png` |
| Add mock | Bilgi/sonuç/özet adımları, klavye/scroll/save; `add-mock.png`, `add-mock-sections.png` |
| History | Tıklanabilir ad/tarih/net kartı; `history.png` |
| Detail | Bölüm/net sunumu, düzenle/sil eylemleri; `detail.png` |
| Statistics | Range, genel metrik, tek nokta/target chart, bölüm seçimi, cevap çubukları; `statistics.png`, `statistics-section-select.png`, `statistics-section.png` |

Screenshot'lar `mobile/build/phase9-visual/` altında ignored yerel kanıtlardır; commit adayı değildir. Emülatörde ayrıca 320 dp genişlik (1080 px / 540 dpi) ve font_scale 2.0 ile koyu statistics filtre/metrik/grafik metinleri incelendi: `statistics-dark-filters.png`, `statistics-dark-large.png`. Metin/chip'ler sarıldı, taşma görülmedi. Screenshot viewport dışında kalan liste içeriği scroll ile erişilebilirdir.

Görsel inceleme welcome status-bar kontrast düzeltmesini ve bölüm başlığı/soru sayısından input'a 16 px boşluk eklenmesini sağladı. Son boşluk değişikliği tüm 208 test ve APK build ile doğrulandı. **Son APK emülatöre yeniden kurulamadı:** `INSTALL_FAILED_INSUFFICIENT_STORAGE`. Bu nedenle son 16 px düzeltmenin cihaz piksel doğrulaması yapılmış sayılmaz; önceki APK'nın dokuz ekran denetimi yapılmıştır.

Ek çok-denemeli sentetik fixture'ları API üzerinden yazan komut otomatik onay denetimince engellendi; sonuç ayrıntılı gerekçe vermedi. Tekrarlanmadı. Canlı emülatör analytics incelemesi UI'dan kaydedilmiş tek denemeyle sınırlı kaldı; çok nokta/range/değişim senaryoları otomatik testlerde doğrulandı.

## Güvenlik ve temizlik

Değişen/untracked 25 aday dosya yalnız kaynak/test/localization/belgedir. Private-key/token pattern kontrolü ve disposable doğrulama değerleriyle exact match taraması bulgu vermedi. Gerçek token/parola/connection string kaynak veya rapora eklenmedi. Backend ve auth/network log davranışı değişmedi. APK, build/test logları ve screenshot'ların ignored olduğu doğrulandı.

Geçici API süreci kapatıldı; `netpusula-phase9` container/network/volume kaldırıldı. Geçici helper/script, environment ve hesap dosyaları silindi; yalnız bu işte başlatılan emülatör süreçleri sonlandırıldı. `postgres-db` çalışır halde kaldı.

## Dosyalar

20 mevcut dosya değişti, 5 yeni dosya oluşturuldu (toplam 25):

- `README.md`
- `docs/architecture.md`
- `docs/design-system.md`
- `docs/phase9-validation.md`
- `mobile/lib/app/app.dart`
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/lib/core/theme/design_tokens.dart`
- `mobile/lib/core/widgets/app_components.dart`
- `mobile/lib/features/auth/presentation/auth_widgets.dart`
- `mobile/lib/features/auth/presentation/home_screen.dart`
- `mobile/lib/features/auth/presentation/login_screen.dart`
- `mobile/lib/features/auth/presentation/register_screen.dart`
- `mobile/lib/features/auth/presentation/splash_screen.dart`
- `mobile/lib/features/dashboard/presentation/net_trend_chart.dart`
- `mobile/lib/features/mock_exams/presentation/mock_exam_screens.dart`
- `mobile/lib/features/preparation/presentation/goal_screen.dart`
- `mobile/lib/features/preparation/presentation/preparation_loading_screen.dart`
- `mobile/lib/features/statistics/presentation/statistics_screen.dart`
- `mobile/lib/features/welcome/welcome_screen.dart`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_tr.dart`
- `mobile/lib/l10n/app_tr.arb`
- `mobile/test/design_system_test.dart`
- `mobile/test/statistics_test.dart`
- `mobile/test/widget_test.dart`

## Sınırlar ve teslim

Fiziksel Android/iOS cihazında ve TalkBack kullanıcısıyla test yapılmadı; semantic/kontrast testleri bunların yerine geçmiş sayılmaz. Çok noktalı grafik, tüm hata/loading varyasyonları ve auth geçişlerinin tamamı emülatörde manuel tekrar edilmedi; otomatik regresyon kapsamı vardır. Son APK tekrar kurulumunun storage engeli yukarıda belirtilmiştir. Yeni dependency, migration, endpoint, alt navigasyon veya sonraki faz özelliği yoktur.

Önerilen commit: `feat: polish mobile experience`. Commit/push yapılmadı; değişiklikler inceleme için unstaged bırakıldı.
