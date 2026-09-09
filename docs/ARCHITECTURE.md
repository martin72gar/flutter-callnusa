# Architecture

## Layers

| Layer | Location | May depend on |
|---|---|---|
| Presentation | `lib/features/**`, `lib/app/**` | application services, domain models |
| Application | `lib/core/auth`, `lib/core/sip`, `lib/features/provisioning` | domain models, infrastructure adapters |
| Domain | `lib/shared/models/**` | nothing (pure Dart) |
| Infrastructure | `lib/core/api`, `lib/core/database`, `lib/core/notification`, `lib/core/sip/linphone_service.dart` | domain models |

Two rules keep this honest:

1. **Only `core/sip/linphone_service.dart` imports the SIP binding.** Everything
   else, including `SipService`, talks to the `LinphoneBinding` interface. That
   is what makes the call state machine testable without a device.
2. **Only `core/api/api_client.dart` imports Dio.** Repositories receive an
   `ApiClient` and get back plain maps or `AppException`s.

## Object graph

`AppDependencies.create()` (`lib/app/bootstrap.dart`) builds every singleton once
at startup and the result is injected into Riverpod through
`dependenciesProvider`. Building it eagerly, in one place, makes the two genuine
dependency cycles explicit:

- the API client must sign the user out when a refresh fails, but `AuthService`
  is built from the API client;
- `SipService` re-provisions on registrar auth failure, and `ProvisioningService`
  applies its result to `SipService`.

Both are resolved with `late final` bindings that are assigned before any request
or SIP event can run.

## Session flow

```text
login ──► AuthRepository.login ──► tokens to secure storage
                                    │
                                    ▼
                        ProvisioningService.fetch()
                        ├─ SIP credentials to secure storage
                        └─ SipService.apply(config)
                                    │
                                    ▼
                        LinphoneService.setAccount ──► REGISTER (TLS)
                                    │
                                    ▼
                        PushService.start() ──► PUT /api/v1/devices/current
```

On a cold start `AuthService.restore()` registers from the **cached** SIP config
first, so an incoming call can be answered before the provisioning round trip
completes; the fresh config is fetched immediately afterwards.

## Registration state machine

`SipService` owns registration:

```text
initial ─apply()─► connecting ──ok──► registered
                        │                 │
                        │              refreshing
                        ▼
                     failed ──auth failure──► re-provision (no retry)
                        │
                        └─transport failure──► retry after 1,2,4,8,16…60s
network lost ─────────► unregistered ──network back──► connecting (backoff reset)
```

Auth failures (401/403/407) never enter the backoff loop: the device secret has
been rotated or revoked, so retrying with it can only fail. The service calls
back into provisioning instead.

## Call state machine

`CallController` (`lib/core/sip/call_controller.dart`) is a Riverpod `Notifier`
holding `ActiveCallState`. It has exactly two inputs:

- Liblinphone call events (`SipService.callEvents`)
- native call-UI commands (`CallKitService.commands`)

and it guarantees three invariants:

1. an action from either side is applied to the other exactly once;
2. a terminal SIP state ends the OS call exactly once (the mapping is removed
   before `endCall`, so a hangup arriving from both directions is idempotent);
3. exactly one history row is written per call — Liblinphone reports both `End`
   and `Released`, so the write is guarded by a flag.

```text
idle ──startCall()──► outgoingInitiated ──► outgoingRinging ──► connected ⇄ held
idle ──INVITE───────► incomingRinging ──accept──► connected ──► ending ──► ended
                                       └─decline/timeout───────────────► ended
```

MVP scope is one call at a time; a second INVITE is declined by the stack.

## Routing

`lib/app/router.dart` derives the route from state rather than pushing
imperatively:

- auth unresolved → splash
- unauthenticated → login
- an active call → call screen (wins over everything)
- otherwise → home shell

That is what makes a cold start from a push notification land on the call screen
without any special-case navigation code.

## Storage split

| Data | Where | Why |
|---|---|---|
| Access/refresh token, SIP password, cached user, device id | `flutter_secure_storage` | OS keystore/keychain; excluded from backups |
| Call history cache, settings | Hive CE boxes | Non-secret, needs fast synchronous reads |
| Redacted diagnostic log | Application-support file, capped at 1 MB | Support without a network round trip |

Call history is cleared on logout; the device id survives so the backend can
still recognise the installation.

## Platform channel contract

`id.callnusa/linphone` (method) and `id.callnusa/linphone/events` (event).

| Method | Arguments | Returns |
|---|---|---|
| `initialize` | `userAgent`, `verbose` | — |
| `setAccount` | the `SipConfig` JSON | — |
| `clearAccount`, `refreshRegistration`, `dispose` | — | — |
| `setNetworkReachable` | `reachable` | — |
| `startCall` | `destination` | call id |
| `acceptCall`, `declineCall`, `endCall` | `callId` | — |
| `setMuted` / `setHeld` | `callId`, `muted`/`held` | — |
| `setAudioRoute` | `route` | — |
| `sendDtmf` | `callId`, `digit` | — |

Events are maps with `type: registration | call | log`. Liblinphone assigns no
stable call id before connection, so the native side mints a UUID per call and
that id is what Dart, CallKit and Telecom all key on.
