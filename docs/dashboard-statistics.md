# Dashboard ve performans istatistikleri (Faz 7)

## API

Tek uç nokta: `GET /api/dashboard`, JWT zorunlu. `ICurrentUser` → etkin UserExam üzerinden sorgulanır. İstemciden kullanıcı/hazırlık seçici kabul edilmez; ek query alanları kapsamı değiştirmez. Aktif hazırlık yoksa 409 ProblemDetails, `code: active_preparation_required`; kimlik yoksa 401. Başarı 200, cache `no-store`, üretimde HTTPS. EF entity veya hesaplama snapshot alanları serialize edilmez.

Yanıt: `preparation`, `summary`, `recentMocks`, `trend`, `sections`, `improvement`.

- preparation: id, examId, examCode, examName, targetNet, examDate, daysRemaining, dateStatus.
- summary: mockExamCount, latestNet, averageNet, bestNet, targetDifference.
- trend/recentMocks noktası: mockExamId, name, takenAt, totalNet.
- sections: examSectionId, sectionCode, sectionName, groupCode, groupName, isActive, questionCount, attemptCount, latestNet, averageNet, bestNet.
- improvement: hasEnoughData, recentAverage, previousAverage, change.

Tüm decimal alanlar, targetNet dahil, JSON **metin** olarak gönderilir. Sayılar/count/days/questionCount integer JSON number olarak kalır; eksik istatistik null'dır. Örnek: `"averageNet":"74.25"`, `"mockExamCount":6`.

## Kesin tanımlar

Deneme sırası `TakenAtUtc`, `CreatedAtUtc`, `Id` ile belirlenir. Son deneme bu sıralamanın en büyüğüdür; son eklenen eski tarihli bir deneme “son” olmaz. API takenAt alanını mevcut UTC gününden DateOnly olarak verir.

| Alan | Tanım |
| --- | --- |
| mockExamCount | Aktif hazırlıktaki tüm kaydedilmiş denemeler |
| deneme toplamı | Her kayıtlı bölümün snapshot soru/bölenini kullanan mevcut decimal NetCalculator sonuçlarının toplamı |
| latestNet | Kronolojik son denemenin toplamı |
| averageNet | Tüm deneme toplamlarının decimal aritmetik ortalaması |
| bestNet | Tüm deneme toplamlarının maksimumu; negatif en iyi skor da geçerlidir |
| targetDifference | targetNet − latestNet; pozitif kalan, sıfır eşit, negatif hedef üstü |
| trend | Kronolojik son en fazla 20 deneme; yanıt eski → yeni |
| recentMocks | En yeni en fazla 3 deneme; yanıt yeni → eski |
| improvement | En az 6 deneme varsa son 3 ortalaması − önceki 3 ortalaması; daha eskiler pencereye girmez |

Ara değerlerde yuvarlama yoktur; mevcut .NET decimal hassasiyeti geçerlidir. Veri yokken count=0 ve summary skorlarının tamamı null, trend/recent boş olur. Tek denemede latest/average/best eşittir; karşılaştırma insufficient kalır. Eski/import edilmiş, hiç çocuk sonucu olmayan bir MockExam varsa boş toplamın matematiksel değeri 0'dır; mevcut CRUD böyle bir yeni kayıt oluşturmaz.

Gün hesabı mevcut PreparationRules Türkiye takvimini (UTC+3) kullanır. dateStatus future/today/past; daysRemaining=max(0, sınav günü − bugün). Geçmiş sınav yanlışlıkla “bugün” sayılmaz.

## Bölüm kimliği ve snapshot

Gruplama mutable ad ile değil, sabit ExamSectionId ile yapılır. Aktif katalog bölümleri sonuçları olmasa da döner: attemptCount=0 ve skorlar null. Son bölüm neti, o bölümün kaydedildiği en yeni denemeden gelir; son genel denemede bölüm yoksa başka bölümün sonucu kullanılamaz. Bölüm ortalaması yalnız o bölümün kayıtlı sonuçlarını kullanır; atlanan denemeler sıfırla doldurulmaz.

Aktif bölümlerin görünen ad/kod/grup/soru sayısı **güncel katalogdan**, tüm netler **sonuç snapshot'larından** gelir. Ad değişikliği aynı kimliğin istatistiğini bölmez. Sonucu bulunan fakat artık inaktif bölüm de isActive=false olarak döner; gösterim bilgisi son tarihsel snapshot'tan alınır. İlgisiz ve sonuçsuz inaktif bölümler dönmez. Flutter grup metadata'sını dinamik kullanır ve inaktif bölümü “Geçmiş bölüm” olarak işaretler.

Soru/bölen zaman içinde değiştiyse ham netler aynı bölüm kimliğinde birleştirilir. questionCount güncel katalog bağlamıdır; geçmiş tüm kayıtlar için ortak maksimum olduğu iddia edilmez. Normalizasyon, yüzde, güçlü/zayıf sıralaması veya subjektif/prediktif iddia üretilmez. Kullanıcı son/ortalama/en iyi bölüm netlerini doğrudan karşılaştırabilir.

## Sorgu tasarımı

Başarılı istek üç SELECT kullanır: current-user aktif hazırlık + exam scalar projection; aktif section metadata projection; yalnız bu hazırlığın mock/result LEFT JOIN scalar stream'i. N+1 yoktur, EF entity graph yüklenmez/tracking yapılmaz. PostgreSQL RepeatableRead transaction üç okumanın tutarlı anlık görüntüsünü sağlar; SQLite test sağlayıcısı Serializable kullanır.

Hesaplar sunucuda mevcut NetCalculator ile yapılır. SQL division PostgreSQL numeric ölçeği ve SQLite aritmetiği yüzünden özellikle 1/3 gibi değerlerde Phase 6 .NET decimal sözleşmesinden farklı sonuç üretebilir. Bu yüzden aggregate hesabı bilinçli olarak projection stream'i üzerinde .NET decimal ile yapılır; aynı hesabın SQL ve istemci sürümleri eklenmez. Gerçek PostgreSQL testinde bölen 3 çıktısı Phase 6 ile byte-değer olarak aynı decimal metnidir.

İşlem süresi O(sonuç satırı sayısı), uygulama belleği O(bölüm sayısı + 20 trend noktası). Tüm lifetime deneme/EF entity listesi belleğe alınmaz; response lifetime seri döndürmez. Mevcut UserExamId/TakenAtUtc ve MockExamId/ExamSectionId index'leri kullanıma uygundur. Çok büyük lifetime geçmişlerinde her refresh tüm scalar sonuçları tarar; yüzlerce denemelik MVP için bilinçli hassasiyet/performans tercihi, gelecekte ölçümle geliştirilmelidir. Yeni sütun, redundant aggregate veya migration yoktur.

## Flutter

Home artık Material 3 dashboard'dur: greeting ve CTA'lar, hazırlık kartı, büyük son net, ortalama/en iyi/hedef farkı, grafik, tarafsız gelişim farkı, bölüm kartları, son denemeler. Mevcut detay/geçmiş/ekle/düzenle/logout rotaları kullanılır; bottom navigation eklenmedi. Mevcut “Deneme Geçmişi” etiketi tüm denemelere erişim sağlar.

DashboardRepository tek API çağrısı yapar. autoDispose FutureProvider oturum durumu/kullanıcı ve aktif Preparation nesnesini izler; kimlik veya hedef/tarih değişimi yeniden fetch eder. Loading sırasında önceki AsyncValue gösterilmez; başka kullanıcıya ait eski veri taşınmaz. MockMutationController başarılı create/edit/delete sonrasında yalnız dashboard/history/detail provider'larını invalidate eder. Pull-to-refresh ve Yenile sunucudan tekrar okur; uygulama geneli reset yoktur.

Ağ/5xx/format hatası boş istatistik değildir: güvenli Türkçe hata + retry gösterilir. Aktif hazırlık eksikliği yalnız API'nin açık kodundan anlaşılır; Hazırlığı Kontrol Et önce /active çağırır, mevcut onboarding guard'ını kullanır. Hata metni raw exception/token içermez. Sıfır deneme açık CTA, veri olmayan bölüm “Henüz veri yok”, yetersiz gelişim “en az 6 deneme gerekli” olarak gösterilir.

## Grafik ve decimal gösterim

Ek chart paketi yoktur. Küçük CustomPainter düz segmentler/noktalar, düşey net aralığı, yatay deneme sırası ve uç tarih etiketlerini çizer. Kesikli hedef çizgisi API targetNet değeridir; renkler mevcut tema primary/tertiary/outlineVariant'tır. Noktalar eşit aralıklı **deneme sırası**dır, eşit zaman aralığı iddiası yoktur. Tek nokta ortalanır, boş veri çizilmez, negatif ve büyük netlerde aralık target/zero/skorları kapsar. Eğri/smoothing yoktur.

Semantics etiketi her noktanın adı, tarihi, tam kullanıcıya gösterilen neti ve hedefi içerir. Özet skorlar ve bölüm kartları grafikten bağımsız okunur. Tooltip/zoom bu MVP'de yoktur. Türkçe skor biçimleme Phase 6 BigInt tabanlı displayNet'i kullanır; yalnız çizim piksel koordinatlarında double kullanılır. İş hesabı veya istemci ortalama hesabı yoktur. Gösterim iki ondalığa yuvarlanır; negatif target difference UI'da mutlak miktarla “Hedefin üzerinde” olur, API negatifliği korur.

## Güvenlik ve kapsam

Current-user + current-active-preparation kapsamı sunucuda zorunludur. Eski hazırlık kayıtları korunur ve Phase 6 doğrudan erişim kuralları değişmez. İstek kullanıcı/hazırlık kimliği kabul etmez, provider ham token loglamaz. AI, tahmin, öneri motoru, sosyal özellikler, abonelik, bildirim veya Faz 8 yoktur.
