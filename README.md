# CallNusa Mobile

Open-source SIP softphone for the [CallNusa](https://callnusa.id) call-center
platform. Flutter client, Liblinphone SIP stack, Laravel + Asterisk backend.

**Licence: GPL-3.0-only** — see [Licensing](#licensing) before you fork or ship.

| | |
|---|---|
| Platforms | Android 6.0+ (API 23), iOS 13+ |
| SIP | Liblinphone over TLS, SRTP mandatory |
| State | Riverpod |
| Storage | `flutter_secure_storage` (secrets), Hive CE (cache) |
| Push | FCM (Android), APNs + PushKit (iOS) |
| Native call UI | CallKit (iOS), Telecom/full-screen intent (Android) |
| Languages | Indonesian (`id`), English (`en`) |

---

## Features (MVP)

- Email/password login against the CallNusa API, with refresh-token handling
- Device provisioning (`/api/v1/provisioning/device`) and automatic SIP registration
- Dial pad and outgoing calls; mute, hold, speaker, duration timer
- Incoming calls in foreground, background and terminated states via native call UI
- Call history with all/missed/inbound/outbound filters and tap-to-redial
- Settings: speaker default, auto-answer, vibration, ringtone, language, diagnostics
- Structured logging with mandatory secret redaction

---

## Quick start

```bash
flutter --version           # 3.44+ / Dart 3.12+
cp .env.example .env.development   # edit API_BASE_URL
flutter pub get
flutter run --flavor development -t lib/main_development.dart
```

The three flavors (`development`, `staging`, `production`) install side by side
on one device and read `.env.<flavor>`. Those files hold **public configuration
only** — no secrets.

Full build, signing and release instructions: [docs/BUILD.md](docs/BUILD.md).

---

## Architecture

```text
features/  → UI + view models          (Riverpod consumers)
core/      → services and adapters     (auth, sip, api, push, database)
shared/    → pure Dart models + widgets
config/    → env and constants
```

Presentation never touches Dio or Liblinphone directly; `core/sip/linphone_service.dart`
is the only file that speaks to the SIP stack, and it does so over a platform
channel to native Kotlin/Swift implementations.

Details and the call state machine: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Native SIP stack

Liblinphone runs natively because the Core needs its own event loop and native
audio/PushKit integration:

- `android/app/src/main/kotlin/id/callnusa/callnusa_mobile/LinphonePlugin.kt`
- `ios/Runner/LinphonePlugin.swift`

Both implement the same method/event channel contract consumed by
`lib/core/sip/linphone_service.dart`. The Android build pulls
`org.linphone:linphone-sdk-android` from Belledonne's Maven repository; iOS pulls
the `linphone-sdk` CocoaPod. Pin the SDK version before release and re-verify the
plugin against that version's API — Liblinphone's Kotlin/Swift wrappers move
between minor releases.

---

## Backend contract

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v1/auth/login` | POST | Create session |
| `/api/v1/auth/refresh` | POST | Refresh access token |
| `/api/v1/auth/logout` | POST | Revoke session |
| `/api/v1/provisioning/device` | GET | SIP credentials, features, policy |
| `/api/v1/devices/current` | PUT | Register push tokens |
| `/api/v1/calls` | GET | Server-side call history |

Errors use `{"error": {"code": "...", "message": "..."}}`; codes are mapped to
localized messages in `lib/shared/utils/error_messages.dart`.

---

## Testing

```bash
flutter analyze
flutter test
```

The SIP state machine is tested against a fake binding
(`test/core/sip_service_test.dart`), so registration, backoff, network
transitions and credential rotation are covered without a device or SIP server.

---

## Security

All API traffic is HTTPS, SIP is TLS with mandatory SRTP, and credentials live in
the Android keystore / iOS keychain. Logging redacts secrets centrally rather
than at each call site. See [docs/SECURITY.md](docs/SECURITY.md).

Report vulnerabilities privately to `security@callnusa.id` rather than in a
public issue.

---

## Licensing

CallNusa Mobile links against Liblinphone, which is AGPL-3.0. The application as
a whole is therefore distributed under **GPL-3.0-only** ([LICENSE](LICENSE)).

If you distribute this app — including through an app store, and including a
modified or rebranded build — you must:

1. offer the complete corresponding source of your version under GPL-3.0-only;
2. keep [NOTICE](NOTICE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) intact;
3. keep the source-repository link reachable from the About screen
   (`SOURCE_REPOSITORY_URL` in the env file);
4. not add dependencies whose licence conflicts with GPL-3.0.

Belledonne Communications sells a commercial Liblinphone licence if you need to
ship a closed-source derivative; that is a separate agreement with them.

## Contributing

Issues and pull requests are welcome. Please run `flutter analyze` and
`flutter test` before opening a PR, and do not include real credentials,
tokens, or customer numbers in logs, fixtures or screenshots.
