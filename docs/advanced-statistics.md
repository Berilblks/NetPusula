# Gelişmiş performans istatistikleri — Faz 8

## API ve kapsam

`GET /api/statistics?range=20`, JWT zorunlu. Eksik range = `20`; geçerli değerler yalnız `5`, `10`, `20`, `all`. Boş, tekrarlanan veya geçersiz range ve başka query alanları 400 ProblemDetails döndürür. İstemciden UserId/UserExamId kabul edilmez. Kimlik yoksa 401, aktif UserExam yoksa 409 ve `code: active_preparation_required`. Yalnız JWT kullanıcısının halen aktif hazırlığı okunur; inaktif hazırlık ve başka kullanıcı sonuçları dahil edilmez. Yanıt `no-store`; üretimde HTTPS ve mevcut güvenli hata işleyicisi geçerlidir.

Tek yanıtın alanları: `targetNet`, `range`, `summary`, `series`, `improvement`, `bestMock`, `sections`, `activity`. Entity, token, kullanıcı kimliği, bağlantı bilgisi ve hesaplama snapshot alanları dışarı verilmez.

## Aralık ve sıralama

Son 5/10/20, mevcut kayıt sayısı daha azsa eldeki kayıtların tamamıdır. `all` en yeni **500 deneme** ile sınırlıdır. Bu sınır yalnız çizime değil, **tüm özetlere, en iyi denemeye, bölüm/cevap karşılaştırmalarına ve etkinlik hesabına** uygulanır. Böylece grafik ve özet farklı örneklemlerden gelmez. `range.selection`, `limit`, `availableAttemptCount` ve `isCapped` döner. `availableAttemptCount` aktif hazırlığın filtre öncesi sayısıdır. `isCapped` yalnız all ve toplam > 500 olduğunda true'dur; mobil açık açıklama gösterir. Diğer aralıklar zaten açık son-N seçimidir.

Seçim en yeni → eski `TakenAtUtc DESC, CreatedAtUtc DESC, Id DESC` ile yapılır; yanıt serileri aynı anahtarların artan sırasıyla **eski → yeni** döner. Bu Faz 7 sırasıdır. Eski tarihli son eklenen kayıt otomatik olarak son deneme sayılmaz. Aynı tarihte CreatedAtUtc, o da eşitse Id belirleyicidir. UUID sırası gerçek PostgreSQL üzerinde de doğrulandı.

## Genel özet ve en iyi deneme

`summary`: attemptCount, latestNet, averageNet, bestNet, worstNet.

- latestNet: seçili kronolojik son denemenin toplam neti.
- averageNet: seçili deneme toplamlarının decimal aritmetik ortalaması.
- bestNet / worstNet: maksimum / minimum; negatif skorlar geçerlidir.
- series: mockExamId, name, takenAt, totalNet.
- bestMock: aynı küçük nokta DTO'su; net eşitliğinde bu kronolojik sıradaki **en yeni** kayıt kazanır. Tam detay yüklenmez; mobil mevcut detay rotasını açar.

Sıfır denemede skorlar ve bestMock null, series boş, count sıfırdır. Tek denemede tüm genel net metrikleri aynı değerdir. Eski/import edilmiş sonuçsuz deneme Faz 7 ile tutarlı olarak 0 toplam taşır; mevcut CRUD böyle kayıt oluşturmaz. Hesaplar persist edilmez.

## Bölümler, snapshot ve cevaplar

Gruplama sabit ExamSectionId ile yapılır; değişebilir ad kimlik değildir. Aktif katalog bölümleri sonuçsuz olsa bile listelenir. Sonucu olan inaktif bölümler `isActive: false` ile korunur. Aktif ad/kod/grup/soru sayısı güncel katalogdan, inaktif gösterim son seçili tarihsel snapshot'tan gelir. Gruplar sunucu metadata'sıdır; sınav adı/kodu sabitlenmez.

Her bölüm: examSectionId, sectionCode, sectionName, groupCode, groupName, isActive, questionCount, attemptCount, latestNet, averageNet, bestNet, worstNet, series, answers, improvement.

Bölüm series noktaları: mockExamId, takenAt, correctCount, wrongCount, blankCount, net. Yalnız **var olan** sonuçlar kullanılır; eksik bölüm sonucu sıfır olarak eklenmez. Son bölüm neti, o bölümün son kayıtlı sonucudur. Aktif bölümün hiç sonucu yoksa skorlar/cevap ortalamaları null ve series boştur.

`answers.correct/wrong/blank`, her sayının bölümün seçili kayıtlı sonuçları üzerinden decimal ortalamasıdır; payda bölüm attemptCount'tur. Mobil bu ortalamaları yeniden hesaplamaz. Bölüm seçicisi, bölüm net grafiği, cevap ortalama çubukları ve açılabilir tarihsel doğru/yanlış/boş listesi birlikte değişir. Daha az boşun daha iyi olduğu iddia edilmez.

Her net mevcut `NetCalculator` ve ilgili sonucun soru/bölen snapshot'ıyla hesaplanır. Katalog değişimi geçmiş neti değiştirmez. Farklı soru sayıları/bölenler normalleştirilmez; bunlar ham net karşılaştırmalarıdır. Güncel questionCount geçmiş kayıtlar için ortak maksimum değildir.

## Kısa vadeli değişim

Dashboard ve istatistikler aynı `DecimalAggregate` hesaplayıcısını kullanır. En son 3 netin ortalaması eksi onlardan önceki 3 netin ortalaması. Altıdan eski kayıtlar bu metriğe girmez. Global metrik seçili denemeleri, bölüm metriği seçili aralıktaki **o bölümün kayıtlı sonuçlarını** kullanır. Son 5 filtresinde yeterli veri oluşamaz.

Faz 8 `improvement`: sufficientData, recentAverage, previousAverage, change. Altı kayıt yoksa sufficientData false, üç sayı null. Pozitif/negatif işaret korunur; iyi/kötü/güçlü/zayıf veya öneri etiketi üretilmez. Faz 7 JSON sözleşmesindeki hasEnoughData değiştirilmedi; DTO dönüşümü yalnız alan adını değiştirir.

## Aktivite

`activity`: firstMockDate, lastMockDate, attemptCount, averageDaysBetweenMocks. En az iki ayrı deneme kaydı varsa ardışık takvim günü aralıklarının ortalaması `(son gün − ilk gün) / (attemptCount − 1)` olarak tam decimal hesaplanır. Aynı gün birden fazla deneme geçerlidir; sıfır aralıklar dahil edilir. Bu, farklı gün sayısı ortalaması veya çalışma süresi değildir. Sıfır kayıtta tarihler null; sıfır/tek kayıtta aralık null. Tarih API'nin mevcut DateOnly sözleşmesidir.

## Decimal sözleşmesi

Net, hedef, net ortalamaları/değişimleri, cevap ortalamaları ve gün aralığı dahil **tüm decimal alanlar JSON string** olarak taşınır. Null değer null kalır; adetler integer JSON number'dır. Sunucuda decimal, ara yuvarlama yok. PostgreSQL numeric division ölçeğinin .NET decimal'den farklılaşmasını önlemek için net bölmesi SQL'e taşınmadı. 1/3 gibi değerler Phase 6 CRUD yanıtıyla aynı metin hassasiyetindedir.

Flutter mevcut Score/displayNet biçimlemesini kullanır: string doğrulama ve BigInt ile iki ondalık Türkçe gösterim. Double yalnız grafik/çubuk piksel oranlarında kullanılır; iş metriği veya ortalama hesaplamaz.

## Sorgu ve performans

PostgreSQL RepeatableRead transaction içinde dört SELECT komutu: aktif hazırlık scalar projection; aktif hazırlık deneme sayısı; aktif bölüm metadata projection; **önce denemelere LIMIT uygulanan alt sorgu**, ardından sonuçlara LEFT JOIN scalar stream. N+1, bölüm başına sorgu, EF entity graph ve lifetime sonuç yüklemesi yoktur. SQLite test sağlayıcısında Serializable kullanılır.

Tek akışta toplamlar, bölüm toplamları/cevapları, en iyi kayıt, seriler ve son-altı kuyrukları oluşur. Bellek/payload O(seçili deneme × bölüm sayısı); en fazla 500 deneme. Katalog bölüm sayısı sunucu yapılandırmasına bağlıdır. Count sorgusu tüm hazırlığın index'ini sayar; veri sorgusu yalnız seçili denemelerin sonuçlarını okur. Mevcut UserExamId/TakenAtUtc ve MockExamId/ExamSectionId index'leri kullanılır. Ek denormalizasyon/index/migration yok. Gerçek PostgreSQL logunda dört DbCommand, sonuç komutunda LIMIT alt sorgusu ve LEFT JOIN doğrulandı. Bu sorgu şekli doğrulamasıdır; üretim yük testi/SLA iddiası değildir.

## Mobil ekran, grafik ve yaşam döngüsü

Home yalnız `Detaylı İstatistikler` bağlantısı kazandı. `/statistics` mevcut auth/preparation guard'larının içindedir. Genel özet, toplam net grafiği, karşılaştırma, en iyi deneme, gruplu bölüm seçicisi/bölüm grafiği, cevap dağılımı/tarihçesi ve deneme düzeni ayrı ekrandadır. Alt navigasyon eklenmedi.

Faz 7 NetTrendChart/NetTrendPainter tekrar kullanıldı; hedef opsiyonel hale getirildi. Toplamda hedef çizgisi, bölümde hedef iddiası olmadan ham net çizgisi vardır. Noktalar deneme sırasına eşit aralıkla yerleştirilir; takvim zaman ölçeği değildir. Düz segmentler, negatif/sıfır/tek nokta güvenliği ve semantics korunur. Hedef varsa grafiğin aralığına girer. Cevap çubukları en büyük cevap ortalamasına göre yalnız görsel ölçeklenir; sayısal etiketler ve ayrı erişilebilir semantics vardır. Tooltip/zoom/yumuşatma/chart paketi yok.

Range ekran state'inde tutulur (varsayılan 20); bölüm seçimi mümkünse korunur. `FutureProvider.autoDispose.family` range başına ayrı geleceği izler. Kullanıcı/oturum ve aktif Preparation bağımlılıkları eski sonuçları geçersiz kılar; eski filtre yanıtı yeni filtreyi ezmez. Filtre değişimi auth/preparation fetch'i tetiklemez. Kalıcı cache yoktur; ekrandan çıkıp yeniden girişte varsayılan range başlar. Detaya gidip geri dönünce açık ekran seçimi korunur.

Pull-to-refresh yalnız seçili statistics provider'ını yeniler. Merkezi MockMutationController başarılı create/edit/delete sonrasında statistics ailesini de dashboard/history/detail ile birlikte invalidate eder. Widget'lara mutasyon invalidation kodu dağıtılmadı. Hata/loading sırasında önceki AsyncValue gösterilmez.

Sıfır deneme: açık boş durum + İlk Denemeni Ekle. Tek deneme: geçerli metrik ve yetersiz karşılaştırma. Sonuçsuz bölüm: açık veri yok mesajı. Ağ/5xx/format hatası boş veri sayılmaz; güvenli MockError + retry. Aktif hazırlık hatası mevcut Hazırlığı Kontrol Et akışını kullanır. Logout/kullanıcı değişiminde eski veri gösterilmez. 320px genişlik ve 2× metin testi mevcut.

AI, tahmin, öneri, ÖSYM puan/sıralama, sosyal özellikler ve Faz 9 kapsam dışıdır.
