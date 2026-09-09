# Security notes

## Transport

- **API**: HTTPS only. `Env._validate()` refuses to start with a non-`https`
  `API_BASE_URL` unless `ALLOW_INSECURE_TRANSPORT=true`, which is itself ignored
  in production builds.
- **SIP signalling**: TLS (default port 5061). The transport comes from
  provisioning; production accounts must not be issued UDP/TCP.
- **Media**: SRTP, mandatory by default. `SrtpPolicy.mandatory` makes the native
  Core fail a call rather than fall back to plain RTP.

## Credential storage

| Secret | Storage |
|---|---|
| Access token, refresh token | `flutter_secure_storage` |
| SIP password | `flutter_secure_storage` |
| Cached user profile | `flutter_secure_storage` |

Android uses the keystore-backed implementation; iOS uses the keychain with
`first_unlock` accessibility, so a VoIP push can register SIP after a reboot but
the values are unreadable while the device is locked for the first time.

Nothing sensitive is written to Hive, `SharedPreferences`, or the log file.

## Logging

Redaction lives in `AppLogger`, not at call sites, so a forgotten
`log.info(token)` still cannot leak:

- values registered with `registerSecret()` (tokens, SIP password) are replaced
  wherever they appear;
- `password`/`token`/`secret`/`authorization`/`ha1` key-value pairs and bare
  `Bearer` tokens are matched by pattern, even when the value was never
  registered.

API request/response **bodies are never logged** — the provisioning response
carries the device SIP secret. `SipConfig.toString()` prints
`password=<redacted>`, which `test/shared/models_test.dart` asserts.

The native layers return only an error *type* to Dart, because Liblinphone error
strings can contain the proxy URI and SIP headers.

## Push payloads

Incoming-call pushes carry opaque identifiers only (`call_id`, `from_number`,
`from_name`). The backend must never place SIP credentials in a push payload —
pushes traverse Google/Apple infrastructure and are visible to the OS.

## Session handling

- A 401 triggers exactly one refresh attempt; concurrent 401s share it, so a
  burst of parallel requests cannot burn several refresh tokens.
- If refresh fails, `AuthService.onSessionExpired()` unregisters SIP, ends any
  native call, deletes the push token, clears history and wipes secure storage.
- Logout does the same and additionally calls `POST /auth/logout` on a
  best-effort basis — a network failure there must not leave credentials behind.

## Permissions

Android requests `RECORD_AUDIO` at first call, plus `MANAGE_OWN_CALLS`,
`USE_FULL_SCREEN_INTENT` and `POST_NOTIFICATIONS` for the native call UI. iOS
declares `voip`, `audio` and `remote-notification` background modes.
Microphone permission is requested immediately before a call is placed, not at
launch.

## Threat notes for operators

- Provisioning is per device: revoking one device must not require rotating the
  extension's password for the others.
- `max_registered_devices` is enforced by the backend; the client only surfaces
  `DEVICE_LIMIT_EXCEEDED`.
- The device id is app-generated and resets on reinstall by design — do not use
  it as a security boundary.

## Licensing constraints

Liblinphone is AGPL-3.0, which is why this app is GPL-3.0-only. Adding a
dependency under a GPL-incompatible licence (proprietary SDKs, analytics
libraries with restrictive terms) makes the whole binary undistributable. Check
the licence of any new dependency before adding it and record it in
`THIRD_PARTY_NOTICES.md`.
