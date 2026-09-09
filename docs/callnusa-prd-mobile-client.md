# CallNusa Mobile Client — Product Requirements Document

> **Audience:** AI coding agents and engineering team
>
> **Domain:** Mobile softphone application
>
> **Repository:** `callnusa-mobile` (public)
>
> **License:** GPL-3.0-only
>
> **Status:** MVP specification
>
> **Updated:** 2026-09-08

---

## 1. Domain Purpose

Build an Android and iOS softphone that:
- Authenticates against CallNusa API
- Obtains a user-scoped SIP configuration
- Registers to the CallNusa telephony endpoint (Asterisk PJSIP)
- Handles inbound and outbound audio calls with native UX
- Operates as an open-source GPL-3.0-only application

---

## 2. System Context

```text
┌────────────────────────────────────────────────────────────────┐
│                       CallNusa Mobile                           │
│ Flutter + Liblinphone                                           │
│ Android / iOS                                                   │
└───────────────────────┬─────────────────────────────────────────┘
                        │ HTTPS REST API (provisioning, auth)
                        │ SIP/TLS 5061 (media + signaling)
                        │ FCM/APNS (push)
                        v
┌────────────────────────────────────────────────────────────────┐
│                    CallNusa API + Telephony                     │
│ Laravel + Asterisk PJSIP                                        │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 Repository boundaries

| Aspect | Mobile responsibility | Backend responsibility |
|---|---|---|
| Authentication | Token storage, refresh logic | Identity, session, RBAC |
| Provisioning | Fetch and apply config | Generate SIP credentials, policies |
| SIP signaling | Register, call setup/teardown | PJSIP endpoints, dialplan, routing |
| Media | RTP send/receive, codec negotiation | RTP termination, recording |
| Push | Token registration, wake-up handling | Push gateway integration |
| Call history | Local cache, UI display | CDR storage, reporting |
| Security | Secure storage, TLS/SRTP | Credential encryption, access control |

---

## 3. Technology Decisions

| Area | Decision | Rationale |
|---|---|---|
| Framework | Flutter 3.x, Dart 3.x | Cross-platform, single codebase |
| SIP/media stack | Liblinphone (Linphone SDK) | Proven SIP stack, TLS/SRTP support, matches backend PJSIP |
| Platforms | Android API 23+, iOS 13+ | Modern platform support, VoIP APIs available |
| State management | Riverpod | Testable, explicit dependencies, good for SIP state machines |
| HTTP client | Dio | Interceptors, retry logic, cancellation |
| Secure secrets | `flutter_secure_storage` | OS keystore/keychain encryption |
| Non-secret data | Drift (SQLite) or Hive | Persistent local cache for history/settings |
| Push | Firebase Cloud Messaging + APNS | Platform-native push for incoming calls |
| Native call UX | Android ConnectionService, iOS CallKit | System call UI, background call handling |
| Localization | Indonesian (id) and English (en) | Target market + international |
| License | GPL-3.0-only | Required by Liblinphone unless commercial license purchased |

---

## 4. User Roles

| Role | Mobile permissions |
|---|---|
| **Agent** | Login, register SIP, make/receive calls, view own history, configure settings |
| **Supervisor** | Agent permissions; supervisor features are web-first (future mobile expansion) |
| **Tenant admin** | Agent permissions when assigned an extension |

---

## 5. MVP User Stories

### 5.1 Authentication

- As a user, I can log in using email and password to access my assigned extension.
- As a user, I remain logged in after app restart until I explicitly log out or my session is revoked.
- As a user, I can log out, which clears local secrets and unregisters the SIP account.
- As a user, I see a clear error if login fails, my account is inactive, or no extension is assigned.

### 5.2 Provisioning and Registration

- As a logged-in user, the app retrieves device-specific provisioning after login and on app resume.
- As a logged-in user, the app registers to SIP automatically when network access is available.
- As a user, I can see the registration state: `connecting`, `registered`, `failed`, `unregistered`.
- As a user, the app retries registration with bounded exponential backoff when connectivity returns.

### 5.3 Calling

- As a user, I can dial an internal extension or an allowed external number.
- As a user, I can receive an incoming call in foreground, background, and (where supported) terminated state.
- As a user, I can accept or reject an incoming call from the native call interface.
- As a user during an active call, I can mute/unmute, hold/resume, select earpiece/speaker/Bluetooth, and end the call.
- As a user, I see call status and elapsed duration while connected.

### 5.4 History and Settings

- As a user, I can view my recent inbound, outbound, answered, and missed calls.
- As a user, I can redial an entry from call history.
- As a user, I can configure default speaker, ringtone, vibration, and language.
- As a user, I can view app version, open-source notices, GPL-3.0 license, and source repository URL.

---

## 6. Functional Requirements

### 6.1 Authentication

**Endpoint:** `POST /api/v1/auth/login`

**Requirements:**
- Store access token and refresh token only in secure storage
- Implement token refresh before retrying a failed authenticated request caused by expired access token
- Never store plaintext password after login
- On `401` after refresh failure, clear session and navigate to login
- Handle network errors with user-friendly messages

**State machine:**
```dart
enum AuthState {
  initial,
  authenticating,
  authenticated,
  refreshing,
  unauthenticated,
  error,
}
```

### 6.2 Provisioning

**Endpoint:** `GET /api/v1/provisioning/device`

**Request headers:**
```http
Authorization: Bearer <access-token>
X-Client-Platform: android|ios
X-Client-Version: 1.0.0
X-Device-Id: <stable-app-generated-uuid>
```

**Response shape:**
```json
{
  "data": {
    "account": {
      "id": "ext_8f4f24d1",
      "display_name": "Agent CallNusa",
      "extension": "1001"
    },
    "sip": {
      "domain": "sip.example.callnusa.id",
      "username": "1001",
      "password": "device-scoped-secret",
      "transport": "tls",
      "port": 5061,
      "srtp": "mandatory",
      "codecs": ["opus", "pcmu", "pcma"]
    },
    "features": {
      "outbound_calling": true,
      "call_recording_notice": true,
      "video": false,
      "chat": false
    },
    "policy": {
      "default_speaker": false,
      "max_registered_devices": 2
    }
  }
}
```

**Implementation rules:**
- Treat `sip.password` as a secret; redact in all diagnostic output
- Persist SIP credential material in secure storage, encrypted by OS keystore/keychain
- Do not write SIP secret, auth token, full provisioning response, or push token to log output
- Re-fetch provisioning after registration authentication failure (backend may rotate credentials)
- Fetch provisioning on every login and app foreground transition with rate limiting

### 6.3 SIP Registration

**Transport and security:**
- Use SIP over TLS; production configuration must reject plaintext UDP/TCP transport
- Require SRTP for production accounts
- Prefer codecs in order: Opus, PCMU, PCMA
- Set registration expiry according to backend policy; default target: 600 seconds

**Liblinphone integration:**
- Call `iterate` / event loop required by Liblinphone reliably in foreground and background within platform limits
- Use a single dedicated SIP service abstraction; UI must never call Liblinphone directly
- Handle Liblinphone events: registration state changed, call state changed, DTMF received, etc.

**Registration state model:**
```dart
enum SipRegistrationStatus {
  initial,
  connecting,
  registered,
  refreshing,
  failed,
  unregistered,
}
```

**Retry policy:**
- On network loss: pause registration, show `unregistered`
- On network restore: retry with exponential backoff (1s, 2s, 4s, 8s, 16s, max 60s)
- On authentication failure (401/403/407): trigger re-provisioning flow

### 6.4 Calls

**Call lifecycle states:**
```dart
enum CallStatus {
  idle,
  incomingRinging,
  outgoingInitiated,
  outgoingRinging,
  connected,
  held,
  ending,
  ended,
  failed,
}
```

**Required call actions:**
- `startCall(destination)`
- `acceptCall(callId)`
- `declineCall(callId)`
- `endCall(callId)`
- `setMuted(callId, value)`
- `setHeld(callId, value)`
- `setAudioRoute(route)`

**Implementation rules:**
- Normalize dialed numbers only according to backend-provided dialing policy; do not assume all numbers are domestic Indonesian numbers
- Disable duplicate call buttons while a call start request is pending
- Ensure end-call from CallKit/ConnectionService ends the corresponding Liblinphone call
- Ensure SIP call termination updates native call UI exactly once
- Persist local call history after terminal call states; sync server history as a separate operation
- Handle call failures with appropriate SIP response codes mapped to user-friendly messages

**In-call features (MVP):**
- Mute/unmute microphone
- Hold/resume call
- Toggle speaker/earpiece/Bluetooth
- Display call duration timer
- End call

**Future features (post-MVP):**
- Transfer (blind/attended)
- Conference
- DTMF keypad during call
- Call recording indicator

### 6.5 Push and Native Call Integration

**Push token management:**
- Send current device push token to backend after login and whenever token refreshes
- Endpoint: `PUT /api/v1/devices/current`

**Push payload handling:**
- Validate push payload signature or use opaque call wake-up identifiers
- Do not include SIP password in push payload
- On incoming-call push: wake application, refresh provisioning if required, initialize SIP stack, and report call through native interface

**Native call integration:**
- Use CallKit on iOS (CXProvider, CXCallController)
- Use ConnectionService on Android (ConnectionService, TelecomManager)
- Ensure native UI shows caller ID (number/display name)
- Handle accept/reject from native UI and propagate to Liblinphone call
- Handle system call events (incoming from PSTN, app call becomes held/ended)

**iOS-specific:**
- Use PushKit for VoIP pushes (required for background call wake-up)
- Implement `PKPushRegistryDelegate` and handle `pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:`
- Report incoming call via `CXProvider.reportNewIncomingCall` within completion handler deadline

**Android-specific:**
- Register ConnectionService in manifest
- Use `TelecomManager` to check default dialer status (optional for MVP)
- Handle `onCreateIncomingConnection` and `onCreateOutgoingConnection`

### 6.6 Call History

**Local cache:**
- Keep a local history cache for instant UI response
- Store: call ID, direction, counterparty display name, counterparty number, status, started time, answered time, ended time, duration
- Sync strategy: fetch from server on app foreground, append local entries for unsynced calls

**Server history:**
- Backend is authoritative for CDR and organization reporting
- Endpoint: `GET /api/v1/calls` with pagination and filters
- Filters: all, inbound, outbound, missed
- Pagination target: 50 items per request

**Data model:**
```dart
class CallHistoryEntry {
  final String id;
  final CallDirection direction;
  final String? counterpartyName;
  final String counterpartyNumber;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final bool isLocal; // true if not yet synced to server
}

enum CallDirection { inbound, outbound }
enum CallStatus { answered, missed, rejected, failed }
```

### 6.7 Settings

**User-configurable settings:**
- Default speaker: boolean (default false)
- Vibration on incoming call: boolean (default true)
- Ringtone selection: platform-supported values
- Language: `id` or `en` (follow system default initially)
- Diagnostics: SIP registration status, app version, non-sensitive network status

**Settings storage:**
- Persist in local database (Drift/Hive)
- Do not store in secure storage unless sensitive

**Logout behavior:**
- Unregister SIP account
- Remove locally stored SIP credentials from secure storage
- Revoke device session if API supports it (optional for MVP)
- Clear authentication tokens
- Navigate to login screen

### 6.8 Error Handling

**Error categories:**
- Network errors: timeout, no connectivity, DNS failure
- Authentication errors: invalid credentials, session expired, account disabled
- SIP errors: registration failed, call failed, codec mismatch
- Provisioning errors: no extension assigned, invalid config
- Platform errors: CallKit/ConnectionService unavailable, push registration failed

**User-facing messages:**
- Show friendly, actionable messages (avoid technical jargon)
- Provide retry option where appropriate
- Log detailed error internally for debugging (redact secrets)

**Logging:**
- Use structured logging with log levels (debug, info, warning, error)
- Redact secrets (passwords, tokens, SIP credentials) from all logs
- Optionally send non-sensitive diagnostics to backend for support (with user consent)

---

## 7. Architecture

### 7.1 Folder Structure

```text
lib/
├── main_development.dart
├── main_staging.dart
├── main_production.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── providers.dart
├── config/
│   ├── env.dart
│   └── constants.dart
├── core/
│   ├── api/
│   │   ├── api_client.dart
│   │   ├── api_interceptors.dart
│   │   └── api_endpoints.dart
│   ├── auth/
│   │   ├── auth_service.dart
│   │   ├── auth_state.dart
│   │   └── auth_repository.dart
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── tables/
│   │   └── daos/
│   ├── diagnostics/
│   │   ├── logger.dart
│   │   └── crash_reporter.dart
│   ├── notification/
│   │   ├── push_service.dart
│   │   ├── callkit_service.dart (iOS)
│   │   └── connection_service.dart (Android)
│   ├── secure_storage/
│   │   └── secure_storage_service.dart
│   └── sip/
│       ├── linphone_service.dart
│       ├── sip_service.dart
│       ├── sip_registration_controller.dart
│       ├── call_controller.dart
│       └── audio_route_service.dart
├── features/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── login_view_model.dart
│   │   └── login_widgets.dart
│   ├── provisioning/
│   │   ├── provisioning_service.dart
│   │   └── provisioning_state.dart
│   ├── dialer/
│   │   ├── dialer_screen.dart
│   │   ├── dialer_view_model.dart
│   │   └── dial_pad_widget.dart
│   ├── calls/
│   │   ├── active_call_screen.dart
│   │   ├── active_call_view_model.dart
│   │   ├── incoming_call_screen.dart
│   │   └── call_controls_widget.dart
│   ├── call_history/
│   │   ├── call_history_screen.dart
│   │   ├── call_history_view_model.dart
│   │   └── call_history_item_widget.dart
│   └── settings/
│       ├── settings_screen.dart
│       ├── settings_view_model.dart
│       └── settings_widgets.dart
├── shared/
│   ├── models/
│   │   ├── user.dart
│   │   ├── sip_config.dart
│   │   ├── call_history_entry.dart
│   │   └── device.dart
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── loading_indicator.dart
│   │   └── error_message.dart
│   └── utils/
│       ├── extensions.dart
│       ├── validators.dart
│       └── formatters.dart
└── l10n/
    ├── app_localizations.dart
    ├── app_localizations_id.dart
    └── app_localizations_en.dart
```

### 7.2 Layer Rules

| Layer | Responsibility | Dependencies |
|---|---|---|
| **Presentation** (features/*) | UI, user interaction, state display | Application layer only |
| **Application** (core/*) | Business logic, orchestration, state machines | Domain models, infrastructure adapters |
| **Domain** (shared/models/*) | Pure Dart models, interfaces, business rules | None (pure Dart) |
| **Infrastructure** (core/api, database, sip, notification) | External system adapters, Liblinphone binding, HTTP client, database | Domain interfaces |

**Key rules:**
- Presentation depends on application/domain abstractions, never directly on Liblinphone or Dio
- The SIP adapter (`linphone_service.dart`) is the only layer permitted to import Linphone bindings
- Repository interfaces belong in application; implementations belong in infrastructure
- Use immutable models and explicit error types
- Add unit tests for mappers, controllers, repositories, and call state transitions

### 7.3 State Management (Riverpod)

**Providers:**
- `authStateProvider`: StreamProvider<AuthState>
- `sipStateProvider`: StreamProvider<SipRegistrationStatus>
- `activeCallProvider`: StateNotifierProvider<ActiveCallStateNotifier, ActiveCallState>
- `callHistoryProvider`: StreamProvider<List<CallHistoryEntry>>
- `settingsProvider`: StateNotifierProvider<SettingsStateNotifier, SettingsState>
- `provisioningProvider`: FutureProvider<ProvisioningConfig>

**State update flow:**
1. User action (login, dial, accept call) triggers method on service/repository
2. Service updates state via StateNotifier/Stream
3. UI rebuilds based on new state
4. Side effects (API calls, SIP commands) handled in service layer

---

## 8. API Contract

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/api/v1/auth/login` | POST | No | Create authenticated session |
| `/api/v1/auth/refresh` | POST | Refresh token | Refresh session |
| `/api/v1/auth/logout` | POST | Yes | Revoke current session |
| `/api/v1/provisioning/device` | GET | Yes | Get SIP configuration and policies |
| `/api/v1/devices` | PUT | Yes | Register/update current device and push token |
| `/api/v1/calls` | GET | Yes | Retrieve user-visible call history |
| `/api/v1/client-events` | POST | Yes | Optional non-sensitive client diagnostics |

### 8.1 Error Responses

**Standard error shape:**
```json
{
  "error": {
    "code": "AUTH_INVALID_CREDENTIALS",
    "message": "Email or password is incorrect",
    "details": {}
  }
}
```

**Common error codes:**
- `AUTH_INVALID_CREDENTIALS`
- `AUTH_SESSION_EXPIRED`
- `AUTH_ACCOUNT_DISABLED`
- `PROVISIONING_NO_EXTENSION`
- `PROVISIONING_INVALID_CONFIG`
- `DEVICE_LIMIT_EXCEEDED`
- `NETWORK_UNAVAILABLE`
- `SERVER_ERROR`

---

## 9. Acceptance Criteria

### 9.1 Functional

- [ ] User can log in and is provisioned with a valid assigned extension
- [ ] On a stable network, the app reaches `registered` state after login
- [ ] User can place an internal extension call and end it successfully
- [ ] User can receive, accept, and reject calls in foreground and supported background states
- [ ] Native in-call UI and Flutter in-call UI remain consistent for accept, decline, and hangup
- [ ] SIP/auth secrets are absent from application logs and UI
- [ ] Logout clears local credentials and SIP registration
- [ ] Call history shows correct entries after calls
- [ ] Settings persist across app restarts

### 9.2 Security

- [ ] All API communication uses HTTPS
- [ ] SIP uses TLS transport and SRTP media encryption
- [ ] SIP credentials stored only in secure storage (keystore/keychain)
- [ ] No secrets logged to console or crash reports
- [ ] Token refresh implemented correctly; session cleared on refresh failure

### 9.3 Performance

- [ ] App launches to login or home screen in < 2 seconds on mid-range device
- [ ] SIP registration completes in < 3 seconds on stable network
- [ ] Call setup (dial to ringing) completes in < 3 seconds for internal calls
- [ ] UI remains responsive during SIP events and network operations

### 9.4 Compliance

- [ ] GPL-3.0 license file included
- [ ] NOTICE file with Liblinphone attribution included
- [ ] Source code repository URL visible in app (About screen)
- [ ] Build instructions documented in README
- [ ] All dependencies are GPL-3.0-compatible

---

## 10. Non-Functional Requirements

### 10.1 Reliability

- Target registration success rate: >= 98% on supported networks
- Call drop rate: < 2% under normal network conditions
- Automatic reconnection on network transition (WiFi <-> 4G)

### 10.2 Security

- TLS 1.2+ for all API communication
- SIP over TLS, SRTP mandatory for media
- Secure storage for all credentials and tokens
- No hardcoded secrets in code or config files

### 10.3 Compatibility

- Android API 23+ (Android 6.0+)
- iOS 13+
- Support common screen sizes and orientations
- Handle background/foreground transitions gracefully

### 10.4 Observability

- Structured logging with log levels
- Crash reporting (with user consent and secret redaction)
- Optional diagnostic upload to backend for support

---

## 11. Testing Strategy

### 11.1 Unit Tests

**Coverage targets:**
- Auth service and state machine
- SIP service wrapper (mocked Liblinphone)
- Call controller state transitions
- Provisioning service and config parsing
- Settings repository
- Formatters and validators

### 11.2 Integration Tests

- Login flow with mocked API
- Provisioning fetch and apply
- SIP registration with test SIP server
- Outgoing call flow (mocked SIP)
- Incoming call flow (mocked SIP + push)
- Call history sync

### 11.3 Manual Testing

**Device matrix:**
- Android: Samsung, Xiaomi, Oppo (mid-range and flagship)
- iOS: iPhone 8+, latest iOS version

**Network scenarios:**
- WiFi only
- 4G only
- WiFi to 4G transition
- Poor network (high latency, packet loss)
- Network loss and recovery

**Call scenarios:**
- Internal extension to extension
- Inbound from PSTN via DID
- Outbound to PSTN via trunk
- Call hold/resume
- Mute/unmute
- Speaker/earpiece/Bluetooth toggle
- Incoming call during active call

---

## 12. Delivery Checklist

### 12.1 Pre-development

- [ ] Repository created with GPL-3.0 LICENSE
- [ ] NOTICE file with Liblinphone attribution
- [ ] README with setup and build instructions
- [ ] `.env.example` with public variables only
- [ ] CI/CD pipeline configured (format, analyze, test, build)

### 12.2 MVP Development

- [ ] Authentication flow complete
- [ ] Provisioning integration complete
- [ ] SIP registration working
- [ ] Outgoing call working
- [ ] Incoming call with native UI working
- [ ] Call history display working
- [ ] Settings screen working
- [ ] Push notification integration working

### 12.3 Pre-release

- [ ] All acceptance criteria met
- [ ] Unit test coverage >= 70%
- [ ] Integration tests passing
- [ ] Manual testing on device matrix complete
- [ ] Security review (no secrets in logs/code)
- [ ] Performance testing (launch time, call setup)
- [ ] GPL compliance check (license, notices, source URL)
- [ ] App store assets prepared (screenshots, descriptions)

### 12.4 Post-release

- [ ] Crash monitoring enabled
- [ ] User feedback channel established
- [ ] Bug triage process defined
- [ ] Release cadence established (bi-weekly or monthly)

---

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Liblinphone complexity | High development time | Use `sip_voip_plugin` wrapper initially, create internal documentation |
| Push notification inconsistency | Missed incoming calls | Test intensively on device matrix, implement fallback polling for critical scenarios |
| Fork by competitors | Reduced differentiation | Focus differentiation on backend quality, integrations, support, and SLA |
| GPL-3.0 compliance complexity | Legal risk | Audit all dependencies, maintain THIRD_PARTY_NOTICES.md, consult legal if uncertain |
| NAT/firewall issues | Call failures | Implement STUN/TURN strategy, document network requirements, test in various network conditions |
| Battery drain | Poor user experience | Optimize SIP keepalive intervals, use platform push APIs correctly, profile battery usage |

---

## 14. Future Enhancements (Post-MVP)

- Video calling support
- Chat/messaging (SIP SIMPLE or backend-mediated)
- Call transfer (blind/attended)
- Conference calling
- CRM integration (click-to-call from web)
- AI voice features (transcription, summaries)
- White-label tenant branding
- Advanced call analytics (MOS, jitter, packet loss display)
- Offline mode with queued actions

---

## Appendix A — Example Liblinphone Integration

```dart
// lib/core/sip/linphone_service.dart

import 'package:flutter_linphone/flutter_linphone.dart';

class LinphoneService {
  LinphoneCore? _core;
  final _registrationStatusController = StreamController<SipRegistrationStatus>.broadcast();
  
  Stream<SipRegistrationStatus> get registrationStatusStream => _registrationStatusController.stream;
  
  Future<void> initialize() async {
    _core = await LinphoneCore.create(
      config: LinphoneCoreConfig(
        userAgent: 'CallNusa Mobile 1.0.0',
        // Additional config...
      ),
      listener: LinphoneCoreListener(
        onRegistrationStateChanged: _onRegistrationStateChanged,
        onCallStateChanged: _onCallStateChanged,
        // Additional listeners...
      ),
    );
    
    await _core?.start();
  }
  
  Future<void> registerAccount(SipConfig config) async {
    final authInfo = AuthInfo(
      username: config.username,
      password: config.password,
      realm: config.domain,
    );
    
    await _core?.addAuthInfo(authInfo);
    
    final proxyConfig = ProxyConfig(
      serverAddress: 'sip:${config.domain}:${config.port};transport=tls',
      identity: 'sip:${config.username}@${config.domain}',
      register: true,
      expires: 600,
    );
    
    proxyConfig.setTransport(TransportType.TLS);
    await _core?.addProxyConfig(proxyConfig);
  }
  
  void _onRegistrationStateChanged(ProxyConfig cfg, RegistrationState state) {
    SipRegistrationStatus status;
    switch (state) {
      case RegistrationState.Ok:
        status = SipRegistrationStatus.registered;
        break;
      case RegistrationState.Failed:
        status = SipRegistrationStatus.failed;
        break;
      case RegistrationState.Cleared:
        status = SipRegistrationStatus.unregistered;
        break;
      default:
        status = SipRegistrationStatus.connecting;
    }
    _registrationStatusController.add(status);
  }
  
  // Additional methods: makeCall, acceptCall, endCall, mute, hold, etc.
}
```

---

## Appendix B — Example Call State Machine

```dart
// lib/features/calls/active_call_state.dart

enum CallStatus {
  idle,
  incomingRinging,
  outgoingInitiated,
  outgoingRinging,
  connected,
  held,
  ending,
  ended,
  failed,
}

class ActiveCallState {
  final String? callId;
  final CallStatus status;
  final String? remoteNumber;
  final String? remoteDisplayName;
  final bool isMuted;
  final bool isOnHold;
  final AudioRoute audioRoute;
  final Duration elapsedDuration;
  
  const ActiveCallState({
    this.callId,
    this.status = CallStatus.idle,
    this.remoteNumber,
    this.remoteDisplayName,
    this.isMuted = false,
    this.isOnHold = false,
    this.audioRoute = AudioRoute.earpiece,
    this.elapsedDuration = Duration.zero,
  });
  
  ActiveCallState copyWith({
    String? callId,
    CallStatus? status,
    String? remoteNumber,
    String? remoteDisplayName,
    bool? isMuted,
    bool? isOnHold,
    AudioRoute? audioRoute,
    Duration? elapsedDuration,
  }) {
    return ActiveCallState(
      callId: callId ?? this.callId,
      status: status ?? this.status,
      remoteNumber: remoteNumber ?? this.remoteNumber,
      remoteDisplayName: remoteDisplayName ?? this.remoteDisplayName,
      isMuted: isMuted ?? this.isMuted,
      isOnHold: isOnHold ?? this.isOnHold,
      audioRoute: audioRoute ?? this.audioRoute,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
    );
  }
}
```

---

## Appendix C — GPL-3.0 Compliance Checklist

- [ ] LICENSE file contains full GPL-3.0 text
- [ ] NOTICE file attributes Liblinphone and other GPL components
- [ ] README includes link to source repository
- [ ] README includes build instructions
- [ ] App "About" screen shows license and source URL
- [ ] All dependencies checked for GPL compatibility
- [ ] THIRD_PARTY_NOTICES.md lists all dependencies with licenses
- [ ] No closed-source dependencies that conflict with GPL-3.0
- [ ] Build process is reproducible from source