# Building and running

## Prerequisites

- Flutter 3.44+ (Dart 3.12+)
- Android: JDK 17, Android SDK with API 36, NDK per `flutter doctor`
- iOS: Xcode 15+, CocoaPods, a paid Apple developer account (PushKit and CallKit
  need real entitlements; VoIP pushes do not work in the simulator)

```bash
flutter doctor -v
flutter pub get
```

## Environment files

`.env.development`, `.env.staging` and `.env.production` are committed and hold
**public** values only. Copy `.env.example` if one is missing.

| Key | Meaning |
|---|---|
| `API_BASE_URL` | Backend base URL; must be `https` outside development |
| `SOURCE_REPOSITORY_URL` | Shown on the About screen (GPL-3.0 requirement) |
| `SIP_USER_AGENT` | User-Agent sent in SIP requests |
| `SIP_REGISTER_EXPIRY_SECONDS` | Registration expiry hint (backend policy wins) |
| `API_TIMEOUT_MS` | HTTP connect/receive timeout |
| `SIP_VERBOSE_LOGGING` | Native SIP logging; ignored in production |
| `ALLOW_INSECURE_TRANSPORT` | Permits plain-HTTP backends; ignored in production |

## Running

```bash
flutter run --flavor development -t lib/main_development.dart
flutter run --flavor staging     -t lib/main_staging.dart
flutter run --flavor production  -t lib/main_production.dart
```

The flavor is chosen by the entrypoint, so no `--dart-define` is needed. Running
`lib/main.dart` directly falls back to `--dart-define=FLAVOR=<name>` and defaults
to `development`.

Development and staging install with `.dev` / `.staging` application-id
suffixes, so all three builds can coexist on one device.

## Firebase (push)

Push is optional at build time — without Firebase config the app still works in
the foreground, it just cannot be woken for incoming calls.

1. Create Firebase projects (one per environment is recommended).
2. Add `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist`. Both are git-ignored.
3. iOS: upload the APNs auth key to Firebase, and enable **Push Notifications**
   and the **Background Modes** (`voip`, `audio`, `remote notification`)
   capabilities in Xcode.
4. Android: no extra step; FCM is picked up from `google-services.json`.

## Android builds

```bash
flutter build apk  --release --flavor production -t lib/main_production.dart
flutter build appbundle --release --flavor production -t lib/main_production.dart
```

Signing: create `android/key.properties` (git-ignored):

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Without that file the release build falls back to debug signing so a fresh clone
still builds.

The Liblinphone AAR comes from Belledonne's Maven repository, declared in
`android/build.gradle.kts`. ProGuard keeps `org.linphone.**` because the SDK
relies on JNI callbacks.

## iOS builds

```bash
cd ios && pod install && cd ..
flutter build ipa --release --flavor production -t lib/main_production.dart
```

In Xcode, create matching schemes/configurations named after the flavors and set
`PRODUCT_BUNDLE_IDENTIFIER` per configuration
(`id.callnusa.mobile[.dev|.staging]`).

Required capabilities: Push Notifications, Background Modes (Voice over IP,
Audio, Remote notifications). CallKit needs no entitlement but does need the
`voip` background mode to report calls from a terminated state.

## Checks

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

Suggested CI stages: `analyze` → `test` → `build appbundle` → `build ipa`.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Missing required env key` at launch | `.env.<flavor>` not listed in `pubspec.yaml` assets, or the key is absent |
| `API_BASE_URL must use https` | Non-production backend over HTTP; set `ALLOW_INSECURE_TRANSPORT=true` in `.env.development` |
| `SIP_STACK_UNAVAILABLE` | The native Linphone plugin is not registered — check `MainActivity.kt` / `AppDelegate.swift` |
| Registration stuck at `connecting` | TLS port or certificate chain; verify with `openssl s_client -connect sip.host:5061` |
| No incoming call when terminated (iOS) | Missing `voip` background mode or PushKit token not registered with the backend |
