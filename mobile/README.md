# Ringly mobile (Flutter)

The native client for [Ringly](../README.md). The Next.js app under
[`src/`](../src) is a headless API — this Flutter app is the only user-facing
surface. It talks to that API over HTTP and never holds any secret itself.

See [`docs/flutter-migration-plan.md`](../docs/flutter-migration-plan.md) for
the full architecture decision record and the page-by-page feature map.

## What's built so far

The app currently ships the auth flow, the app shell, and a dashboard. The
four feature tabs (Today, Pipeline, Record, Models) are still placeholders
wired into the nav bar, to be filled in per the migration plan.

- **Login screen** (the default screen on launch) — email + password, with a
  "Don't have an account? Sign up" link that routes to signup.
- **Signup screen** — name / email / password / confirm, with an "Already have
  an account? Log in" link back to login. The two screens toggle between each
  other.
- **Dashboard** — a grid of placeholder cards plus a recent-activity panel,
  shown after a successful login.
- **App shell** — a white bottom navigation bar (Today / Pipeline / Record /
  Models) and a circular white menu button in the top-left that opens a drawer.

### Mock authentication

There is **no real auth yet** — the backend has no login endpoint. Login is
gated on a single hardcoded demo credential purely so the dashboard can be
reached during a demo:

| Field | Value |
|---|---|
| Email | `test123@gmail.com` |
| Password | `test123` |

Anything else shows an "Incorrect email or password" message. The credentials
live in `lib/features/auth/screens/login_screen.dart` and are meant to be
replaced with a real API call once an auth endpoint exists.

## Theme

A deliberately soft, off-white look — defined once in
`lib/core/theme/`:

- Background: off-white / grayish-white (`#F4F4F2`), not pure white.
- Cards, the nav bar, and the menu button: pure white, lifted off the
  background by soft gray borders rather than heavy shadows.
- Accent: indigo (`#4F46E5`), carried over from the web app.

All colours are tokens in `app_colors.dart`; the Material 3 `ThemeData` is
assembled in `app_theme.dart`. No screen hardcodes a hex value.

## Project structure

```
lib/
  app.dart                    # go_router routes + RinglyApp root widget
  core/
    env.dart                  # emulator vs production base URL
    theme/
      app_colors.dart         # off-white palette tokens
      app_theme.dart          # Material 3 ThemeData
  features/
    auth/
      screens/
        login_screen.dart     # default screen; demo-credential gate
        signup_screen.dart
      widgets/
        app_text_field.dart   # shared labelled text field
        primary_button.dart   # full-width accent button
    dashboard/
      screens/
        dashboard_screen.dart # placeholder card grid
      widgets/
        dashboard_card.dart
    shared/
      widgets/
        app_shell.dart        # white bottom nav + menu button + drawer
        circular_menu_button.dart
        nav_destinations.dart # the four nav tabs
  main_dev.dart               # entrypoint pointed at 10.0.2.2 (emulator)
  main_prod.dart              # entrypoint pointed at the deployed URL
```

## Running it

Requires the Flutter SDK (developed against Flutter 3.32 / Dart 3.8).

```bash
flutter pub get
flutter run -t lib/main_dev.dart
```

`main_dev.dart` points at `http://10.0.2.2:3000` — the Android emulator's alias
for the host machine — so run the Next.js dev server (`npm run dev` in the repo
root) alongside it for any screen that hits the API. The login and signup
screens are mock-only and work without the backend running.

For a release build against the deployed API, use `main_prod.dart`, whose
`Env.productionBaseUrl` points at the backend deployed on Render (see the
root [`render.yaml`](../render.yaml)).

## Verifying

```bash
flutter analyze
flutter build web -t lib/main_dev.dart   # or: flutter build apk -t lib/main_prod.dart
```
