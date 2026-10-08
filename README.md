# FileFlyfer

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

FileFlyfer, macOS 13+ üzerinde USB ile bağlı Android cihazların ortak depolama alanını ADB üzerinden yöneten bağımsız bir SwiftUI uygulamasıdır. Telefona ek uygulama kurmaz, root erişimi kullanmaz ve dosya içeriğini ağ üzerinden göndermez.

## Özellikler

- Bağlı, yetkisiz ve çevrimdışı cihazları otomatik algılama; çoklu cihaz seçimi
- Model, cihaz adı ve Android sürümü bilgisi
- `/sdcard` altında breadcrumb, sık kullanılan klasörler ve çift tıklamayla gezinme
- Dosya adı, tür, boyut ve değiştirilme tarihi
- Tekli/çoklu gönderme ve indirme, sürükle-bırak, sıralı aktarım kuyruğu ve iptal
- Klasör oluşturma, yeniden adlandırma ve onaylı silme
- Çakışmada üzerine yazma, atlama veya yeni isim seçeneği
- Türkçe, Unicode, boşluk, tırnak ve kabuk özel karakterlerini güvenli işleme
- Kullanıcı dostu merkezi hata eşleme ve gerektiğinde teknik ayrıntıyı saklama

ADB yüzde ilerlemesini güvenilir biçimde sağlamadığı için uygulama sahte bir yüzde göstermez; devam eden aktarım belirsiz ilerleme göstergesi kullanır.

## Geliştirme

Gereksinimler: macOS 13 veya sonrası, Xcode 15 veya sonrası ve Android SDK Platform-Tools (ADB).

```sh
open Package.swift
swift test
swift run FileFlyfer
```

Android SDK Platform-Tools'u Android Studio'nun SDK Manager'ından veya `sdkmanager` ile yükleyin. Uygulama ADB'yi sırasıyla paket kaynağında, `ADB_PATH` ortam değişkeninde, Homebrew yollarında ve `~/Library/Android/sdk/platform-tools/adb` altında arar. Örnek:

```sh
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb" swift run FileFlyfer
```

## Xcode'da açma

`Package.swift` dosyasını Xcode ile açmak geliştirme ve çalıştırma içindir:

```sh
open -a Xcode Package.swift
```

App Store veya imzalı `.app` üretmek için Xcode'da gerçek bir macOS App projesi oluşturun:

Depodaki hazır Xcode projesini açıp çalıştırabilirsiniz:

```sh
open FileFlyferXcode/FileFlyferXcode.xcodeproj
```

İmzalı dağıtım için Xcode'da Target > Signing & Capabilities bölümünde kendi Team'inizi seçin. Apple Developer hesabı gerekir.

Doğrudan web sitesinden dağıtım için Organizer > Distribute App > Developer ID seçin. App Store için önce App Store Connect'te aynı bundle ID ile uygulama kaydı oluşturun, ardından Organizer > Distribute App > App Store Connect > Upload seçin. App Store dağıtımında Apple Development değil, dağıtım sertifikası kullanılmalıdır; Xcode bunu dağıtım akışında seçtirir.

Not: Debug yapılandırmasında sandbox kapalıdır. Release/App Store yapılandırmasında sandbox açıktır; paketli ADB alt süreci `ADBHelper.entitlements` ile ana uygulamanın sandbox ve USB izinlerini devralır. ADB'nin RSA kimliği uygulamanın Application Support konteynerinde tutulur ve daemon, sandbox içindeki yerel soketi kullanır.

İmzalama için Apple Developer Program hesabı, Team seçimi ve geçerli sertifika gerekir. Hesap veya sertifika yoksa Signing & Capabilities ekranındaki “Add Account” ile Apple ID'nizi ekleyin; ücretli dağıtım ve App Store gönderimi için Apple Developer üyeliği gereklidir.

## Android bağlantısı

1. Ayarlar > Telefon Hakkında bölümünü açın.
2. Yapım Numarası'na yedi kez dokunun.
3. Geliştirici Seçenekleri > USB Hata Ayıklama'yı etkinleştirin.
4. Veri destekli USB kablosu ile Mac'e bağlayın.
5. Telefon kilidini açıp RSA izin penceresini onaylayın.

Algılanmıyorsa yalnızca şarj destekleyen kabloyu değiştirin, USB modunu kontrol edin ve `adb devices -l` çıktısını doğrulayın.

## Mimari

- `ADBService`: ADB komutları, depolama sınırı ve hata eşleme
- `ProcessRunner`: stdout/stderr, çıkış kodu, zaman aşımı ve iptal
- `AppViewModel`: cihaz izleme, gezinme, kuyruk ve kullanıcı işlemleri
- SwiftUI görünümleri: macOS arayüzü ve onboarding
- Protokol tabanlı servis enjeksiyonu sayesinde sahte servisle test

Kullanılan komutlar: `adb devices -l`, `adb -s SERIAL shell getprop`, güvenli argümanlarla `sh -c` tabanlı dizin listeleme, `adb push`, `adb pull`, `mkdir --`, `mv --` ve `rm -rf --`. Swift tarafında komut satırı birleştirilmez; executable URL ve argument dizisi kullanılır. Listeleme sırasında dosya adları Base64 kodlanarak ayrıştırıcıya taşınır.

## Paketleme ve notarization

Yerel `.app` paketi üretmek için:

```sh
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

Script, release executable'ını `dist/FileFlyfer.app` içine koyar. Üretim ADB binary'sini `Vendor/platform-tools/adb` altına yerleştirin. İmzalı paket için `CODE_SIGN_IDENTITY` verin:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Şirketiniz (TEAMID)" ./scripts/package-app.sh
```

Bu script geliştirme ve Developer ID dağıtımı için başlangıç paketidir; App Store yüklemesi için Xcode içinde gerçek bir macOS Application target'ı oluşturup aynı bundle identifier, sandbox capability ve `Mac App Store` dağıtım sertifikasıyla Archive/Distribute akışı kullanılmalıdır.

ADB ikilisi depoya dahil değildir. Google'ın lisans koşullarını kabul ederek Android SDK Platform-Tools'u kendiniz yükleyin; uygulama kurulu ADB'yi kullanır. Paketlenmiş bir uygulama dağıtacaksanız, dahil ettiğiniz Platform-Tools sürümünün lisans ve bildirim koşullarını izleyin.

Developer ID dağıtımında ADB dahil yürütülebilirleri imzalayın, Hardened Runtime kullanın, paketi Apple notarization işleminden geçirin ve Gatekeeper ile doğrulayın. App Store dağıtımı için sandbox ve imzalama ayarlarını Xcode arşivinde ayrıca doğrulayın.

## Bilinen sınırlamalar

- İlk sürüm yalnızca USB ADB kullanır; MTP, Wi-Fi, iOS, root, bulut, önizleme ve senkronizasyon yoktur.
- Bazı üretici ROM'ları ortak depolamadaki `stat`/`base64` araçlarında farklılık gösterebilir.
- Aktarım ilerlemesi ADB'nin güvenilir yüzdesi olmadığı için belirsizdir.
- Klasör indirme arayüzü ilk sürümde kapalıdır; dosyalar seçilerek indirilir.
- Üretim ADB binary'si ve tam Google lisans metinleri kaynak kod deposuna henüz eklenmemiştir; yayın arşivinden önce yukarıdaki paketleme adımları zorunludur.

## Örnek hata senaryoları

- `unauthorized`: telefon kilidini açıp RSA iznini onaylayın.
- `offline`: kabloyu yeniden bağlayın ve cihaz listesini yenileyin.
- `no space left on device`: cihazda alan açın.
- `permission denied` / salt okunur hedef: ortak depolamada yazılabilir klasör seçin.
- Uzun süren komut: işlem zaman aşımı hatasına dönüşür; aktarım 60 dakika sınırına sahiptir.
- Kablo aktarımda çıkarılırsa kuyruk öğesi başarısız olur ve cihaz izleyici durumu en geç birkaç saniyede yeniler.
