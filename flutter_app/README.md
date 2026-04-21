# Monev Flutter App

Flutter mobile client untuk Monev yang terhubung ke backend Next.js melalui `/api/mobile/*`.

## Status

MVP internal / QA build. Belum final untuk store release sampai bundle ID, signing, dan build pipeline dirapikan.

## Jalankan lokal

Prasyarat:
- Flutter SDK 3.3+
- Android Studio / Xcode sesuai target device

Contoh jalan di Android emulator dengan backend lokal Next.js:

```bash
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Contoh ke server live:

```bash
flutter run --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://monev.app
```

## Konfigurasi penting

Lokasi config utama:
- `lib/core/config/app_config.dart`
- `lib/core/network/api_client.dart`

Auth mobile memakai endpoint backend:
- `/api/mobile/auth/login`
- `/api/mobile/auth/refresh`
- `/api/mobile/auth/logout`
- `/api/mobile/profile`

## Sebelum release

Wajib dibereskan:
- ganti Android `applicationId` / namespace final
- ganti iOS bundle identifier final
- setup release signing Android
- jalankan `flutter analyze`
- jalankan `flutter test`
- validasi `flutter build apk` / `flutter build appbundle`

## Catatan

Default production API saat ini diarahkan ke `https://monev.app`, tapi sebaiknya tetap eksplisit pakai `--dart-define=API_BASE_URL=...` saat build CI/release.
