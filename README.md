# Education ERP – Student Portal

Flutter mobile app for students of the Education ERP. Students sign in with the
credentials their school or college issued and see only their own academic data,
served by the existing ERP backend.

## Features

- **Sign-in** – login, forgot password, secure logout; tokens kept in secure storage
  with automatic refresh on expiry.
- **Dashboard** – today's timetable and attendance, upcoming exams, recent notices,
  latest results and fee status.
- **Timetable**, **Attendance**, **Results** (with report card view)
- **Notices**, **Notifications**, **Fees**
- **Profile** and **Help & Support** (raise and follow support tickets)

## Tech stack

| Concern    | Package                  |
|------------|--------------------------|
| State      | `flutter_riverpod`       |
| HTTP       | `dio`                    |
| Routing    | `go_router`              |
| Tokens     | `flutter_secure_storage` |
| Formatting | `intl`                   |
| Testing    | `flutter_test`, `mocktail` |

## Project layout

```
lib/
  main.dart, app.dart     App entry and root widget
  core/
    config/               Build-time config (API address, timeouts)
    network/              Dio client, auth interceptor, errors, pagination
    router/               go_router routes and auth redirects
    storage/              Secure token storage
    theme/, widgets/      Theme and shared UI (loading/error/empty states, paged lists)
    utils/                JSON and formatting helpers
  features/<feature>/     Screen(s) + repository per feature
test/                     Unit and widget tests
```

## Getting started

Requires Flutter with Dart SDK `^3.12.2`.

```sh
flutter pub get
```

### Pointing the app at the backend

The API address is set at build time with `--dart-define=API_BASE_URL=...`
(the backend's `/api/v1` root).

- **Debug** builds default to `http://10.0.2.2:8000/api/v1` — the Android
  emulator's alias for the host's `localhost:8000`.
- **Release** builds must set `API_BASE_URL`, and it must be `https://`.

```sh
# Android emulator, backend on your machine (default)
flutter run

# iOS simulator, backend on your machine
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1

# Physical device on the same network
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:8000/api/v1

# Release build
flutter build apk --dart-define=API_BASE_URL=https://erp.example.com/api/v1
```

Plain HTTP is only allowed for development: Android permits cleartext in debug
builds only, and iOS allows local-network HTTP only. Remote servers need HTTPS.

## Tests

```sh
flutter test
flutter analyze
```
