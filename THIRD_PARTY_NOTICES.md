# Third-party notices

CallNusa Mobile is distributed under **GPL-3.0-only**. Every dependency below is
GPL-3.0 compatible. Adding a dependency under a GPL-incompatible licence (for
example Apache-2.0-with-additional-restrictions, CDDL, or any proprietary SDK)
is not permitted — see [docs/SECURITY.md](docs/SECURITY.md#licensing-constraints).

## Native SIP stack

| Component | Licence | Notes |
|---|---|---|
| [Liblinphone / linphone-sdk](https://gitlab.linphone.org/BC/public/liblinphone) | AGPL-3.0-or-later | Belledonne Communications SARL. The reason this application is GPL-3.0-only. A commercial licence from Belledonne is the only alternative. |
| bctoolbox, mediastreamer2, ortp, belle-sip (bundled in linphone-sdk) | AGPL-3.0-or-later | Belledonne Communications SARL |
| srtp2, bzrtp | BSD-3-Clause / AGPL-3.0 | bundled by linphone-sdk |
| Opus codec | BSD-3-Clause | Xiph.Org / Broadcom |

## Flutter and Dart packages

| Package | Licence |
|---|---|
| Flutter SDK, Dart SDK | BSD-3-Clause |
| flutter_riverpod, riverpod | MIT |
| go_router | BSD-3-Clause |
| dio | MIT |
| connectivity_plus, package_info_plus | BSD-3-Clause |
| flutter_secure_storage | BSD-3-Clause |
| hive_ce, hive_ce_flutter | Apache-2.0 |
| firebase_core, firebase_messaging | BSD-3-Clause |
| flutter_callkit_incoming | MIT |
| permission_handler | MIT |
| url_launcher, path_provider | BSD-3-Clause |
| flutter_dotenv | MIT |
| uuid | MIT |
| intl, meta | BSD-3-Clause |
| cupertino_icons | MIT |
| mocktail, flutter_lints (dev only) | MIT / BSD-3-Clause |

Regenerate the transitive list with:

```bash
flutter pub deps --style=compact --no-dev
```

The in-app **Settings → Open-source notices** screen renders the licences that
Flutter collects at runtime.
