# QRSafe Mobile (Flutter)

[![Build Android APK](https://github.com/Overover1400/qrsafe/actions/workflows/mobile.yml/badge.svg)](https://github.com/Overover1400/qrsafe/actions/workflows/mobile.yml)
[![Build Web](https://github.com/Overover1400/qrsafe/actions/workflows/web.yml/badge.svg)](https://github.com/Overover1400/qrsafe/actions/workflows/web.yml)

The Flutter client for QRSafe — scan a QR code, check the destination URL's
safety against the backend, then decide whether to open it. On first launch the
app silently bootstraps a guest account; there is no sign-up screen.

## Running locally

```bash
cd mobile
flutter pub get

# Against a backend running on your machine (Android emulator → host localhost):
flutter run

# Against the production API:
flutter run --dart-define=API_BASE_URL=https://api.qrsafe.flemby.com
```

To build the debug APK exactly as CI does:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://api.qrsafe.flemby.com
# → build/app/outputs/flutter-apk/app-debug.apk
```

Checks before pushing:

```bash
flutter analyze   # must be clean
flutter test      # must be green
```

## How the API URL is configured

The base URL is a compile-time constant read from `--dart-define`, defined in
[`lib/core/config/env.dart`](lib/core/config/env.dart):

```dart
static const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080', // Android emulator → host localhost
);
```

- **Local dev**: omit the flag and the default targets the emulator's
  host-loopback address (`10.0.2.2`), i.e. a backend on your machine.
- **CI / release**: `.github/workflows/mobile.yml` passes
  `--dart-define=API_BASE_URL=https://api.qrsafe.flemby.com`, so the produced
  APK is hard-wired to production.

The current value is visible at runtime on the Settings screen.

## Architecture & conventions

- **State**: `flutter_riverpod`. All async flows go through `AsyncValue` /
  `AsyncNotifier`; no raw `FutureBuilder`s in widgets. Every provider has a
  comment saying what it provides and who consumes it.
- **HTTP**: a single `Dio` instance ([`core/api/api_client.dart`](lib/core/api/api_client.dart))
  with an auth interceptor (attaches the bearer token), a debug-only logging
  interceptor, and an error interceptor that maps failures to typed
  `ApiException`s (`AuthException` / `ClientException` / `ServerException` /
  `NetworkException`). Data-layer calls wrap requests in `mapDioErrors` to
  surface those typed errors.
- **Auth**: the guest JWT lives in `flutter_secure_storage`. On startup
  `AuthController` reuses a stored, unexpired token (expiry read locally from the
  JWT `exp` claim — no server round-trip) or provisions a fresh guest.
- **Routing**: `go_router`. `/` is a splash that gates the app on the auth
  bootstrap, then hands off to `/home`. Routes: `/home`, `/scan`, `/settings`.
- **Theme**: the peach palette lives in `core/theme/`. Widgets read colors via
  `context.qrColors` (a `ThemeExtension`, `QRSafeColors`) rather than touching
  raw constants, so the theme stays swappable. User-facing strings are inline
  for now (intl arrives with a second language).
- **Errors**: surface via peach `SnackBar`s, not dialogs.
- **Widget size**: keep files under ~250 lines; extract sub-widgets into the
  feature's `widgets/` folder.

### Backend contract note

`POST /api/v1/scan/check` returns one of `safe | suspicious | malicious`. The UI
uses a four-state vocabulary, mapped in `Verdict.parse`
([`features/scan/data/scan_models.dart`](lib/features/scan/data/scan_models.dart)):
`suspicious → caution`, `malicious → danger`, anything unrecognized → `unknown`.

## Folder structure (feature-first)

```
lib/
├── main.dart                  # entry → runApp(ProviderScope(QRSafeApp()))
├── app.dart                   # MaterialApp.router + theme
├── core/                      # cross-feature infrastructure
│   ├── config/                # Env (dart-define values)
│   ├── theme/                 # palette + ThemeData + QRSafeColors extension
│   ├── api/                   # Dio client, interceptors, providers, exceptions
│   ├── storage/               # SecureTokenStore
│   └── widgets/               # shared widgets (PrimaryButton, VerdictPill, …)
├── features/
│   ├── auth/      {data, application}
│   ├── home/      {presentation/widgets}
│   ├── scan/      {data, application, presentation/widgets}
│   ├── settings/  {presentation}
│   └── splash/    {presentation}
└── routing/                   # go_router config
test/                          # mirrors lib/ structure
```

## Adding a new feature module

1. Create `lib/features/<name>/` with the layers you need:
   - `data/` — models (plain Dart, `fromJson`/`toJson`) and API clients that
     take a `Dio` and wrap calls in `mapDioErrors`.
   - `application/` — Riverpod controllers (`AsyncNotifier`/`Notifier`) plus the
     providers that expose them. Comment each provider.
   - `presentation/` — screens, with sub-widgets under `presentation/widgets/`.
2. Read colors via `context.qrColors`; reuse `PrimaryButton` / `VerdictPill`.
3. Add routes in [`routing/app_router.dart`](lib/routing/app_router.dart).
4. Mirror the module under `test/` and cover controllers + key widgets with
   `mocktail` (see existing tests for the `ProviderContainer` + mocked-`Dio`
   pattern).

## Code generator + dashboard

Two feature modules cover creating and managing QR codes.

### `features/generator/` — create flow

Pick a type, fill a form, watch the QR update live (debounced 200ms), then
**Save & Download**. On save it `POST`s to `/api/v1/codes`, shows a download
sheet, and routes to the new code's detail screen.

- `data/code_payload.dart` — a sealed `CodePayload` with one variant per type
  (`UrlPayload`, `WifiPayload`, `VCardPayload`, `EmailPayload`, `TextPayload`),
  each with `toJson()` (the backend `payload` object) and an `isValid` gate.
- `data/payload_encoder.dart` — the canonical client-side encoder: turns a
  payload into the exact string a **static** QR encodes (URL, `WIFI:…`, vCard,
  `mailto:…`, text), with WiFi/vCard escaping.
- `application/generator_controller.dart` — form state: selected type, a
  *separate* payload per type (switching tabs preserves each form), dynamic
  flag, foreground color, label.

### `features/codes/` — dashboard

- `data/codes_api.dart` + `data/code_models.dart` — wrap the `/codes` CRUD +
  per-code analytics; `Code.qrContent` returns the redirect URL for dynamic
  codes and the literal encoded payload for static ones.
- `application/codes_list_controller.dart` — paginated `AsyncNotifier` with
  `refresh`/`loadMore` and optimistic `add`/`remove`/`replace`.
- `application/code_detail_controller.dart` — family provider (by id) with
  optimistic `updateLabel`/`updateDestination`/`delete` (rolls back on error).

### Hybrid QR rendering

- **Static** codes render entirely client-side (`qr_flutter`) from the literal
  payload — instant, offline, image never leaves the device.
- **Dynamic** codes (URL only) encode the backend-assigned
  `https://api.qrsafe.flemby.com/r/{slug}` returned in `dynamic.redirect_url`.
- The server `POST /api/v1/qr` endpoint stays available for the web app/embeds
  but the mobile app never calls it.

### Download / share

`core/qr/qr_image.dart` renders the QR to PNG bytes off-screen
(`QrPainter.toImageData`); `download_sheet.dart` saves via `path_provider` or
shares via `share_plus`. SVG/PDF are wired but show "Coming soon".

### Dashboard analytics note

The backend exposes only **per-code, all-time** analytics
(`GET /api/v1/codes/{id}/analytics`) — there is no account-wide or weekly
rollup — so the dashboard stat card shows "—" and the detail screen shows that
code's total/unique scan counts.

### Adding a new code type

1. Add a value to `CodeType` in `features/generator/data/code_payload.dart`
   (its `wire` must match a backend `type`) and a new `CodePayload` variant
   (fields, `toJson`, `isValid`, `fromJson`/`empty` cases).
2. Add an encoding branch in `features/generator/data/payload_encoder.dart`.
3. Add a form widget under `generator/presentation/widgets/` and a case in
   `payload_form.dart`.
4. Add an icon/label in `widgets/code_type_visuals.dart` — the type chip row
   picks it up automatically.
5. Extend `payload_encoder_test.dart` with round-trip + edge-case coverage.
