# Tikaddis

Tikaddis is a Flutter mobile app that connects businesses with social-media
creators. Businesses browse creator channels (Telegram, YouTube, TikTok,
Facebook, Instagram), see audience size and pricing, and send promotion
requests; creators list their channels, set prices, and manage incoming
requests. Admins review creator applications, channels, and promotions.

## Getting started

```bash
flutter pub get
flutter run
```

The app talks to the Tikaddis backend. The API base URL is configured in
`lib/core/api_service.dart` (defaults to the Android emulator loopback
`http://10.0.2.2:8081`). Point it at your backend host when running on a
physical device or against a deployed environment.

## Project layout

- `lib/screens/` – feature screens (auth, dashboard, browse, influencer, admin)
- `lib/widgets/` – shared UI (e.g. the animated `HexPattern` header background)
- `lib/providers/` – Riverpod state (auth, data providers)
- `lib/core/` – theme, formatting, and the API client

## Flutter resources

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter documentation](https://docs.flutter.dev/)
