# Mobile apps (Android, iPhone)

The same Flutter code runs on the web, on Android and on iPhone.

## Android

**Install the APK on a phone or tablet**
1. On the device, open `https://mouhssineelboumshouli.github.io/euromed-studios-app/demo/euromed-studios.apk`.
2. Download it, open it, and allow "install unknown apps" for your browser when Android asks.
3. A newer APK installs over the old one. Every build uses the same demo signing key.

The APK on that link is rebuilt each time a PR is merged into `main`. Every
push also builds one, which you can download from the "android-apk"
artifact on the GitHub Actions run.

**Open the project in Android Studio**: see "Android Studio" below.

**Signing.** `android/app/demo-signing.keystore` is a demo key. It is kept in
the repo on purpose, and its password is public. Before a Play Store release,
make a private key and keep it outside the repo.

## iPhone

- **No setup:** open the demo link in Safari, then Share → "Sur l'écran
  d'accueil". The app opens full screen with its own icon.
- **Native app:** iPhone apps must be built on a Mac and signed by Apple.
  - Run the "ios-build" job by hand (Actions → App CI → Run workflow). It
    makes an unsigned `.ipa`.
  - Sign and install that `.ipa` with Sideloadly (Windows) and a free Apple
    ID. The install lasts 7 days.
  - A paid Apple Developer account ($99 a year) gives TestFlight and the
    App Store.

## App icon

Every icon (Android, iPhone, web) comes from the logo drawing in
`lib/core/widgets/logo.dart`. To regenerate them after a logo change, run
`python3 tools/icon/make_icons.py`. It needs `rsvg-convert` and ImageMagick.

## Android Studio (Windows)

1. Install Git, the Flutter SDK (in `C:\dev\flutter`) and Android Studio.
2. In Android Studio, go to Plugins and install **Flutter**. That also
   installs Dart.
3. Run `flutter doctor --android-licenses` and accept all licences.
4. Clone the repo, then open the `app` folder in Android Studio.
5. Run `flutter pub get`. Plug in the device with USB debugging on, choose it
   at the top, and press Run ▶.
