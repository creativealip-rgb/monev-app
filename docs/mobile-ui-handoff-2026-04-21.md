# Monev Mobile UI Handoff

Tanggal: 2026-04-21
Repo: /root/project/monev-app
Branch kerja yang sudah dipush: monev-deploy
Remote branch: https://github.com/creativealip-rgb/monev-app/tree/monev-deploy

Tujuan dokumen ini:
- merangkum apa yang sudah dikerjakan di Flutter app
- menjelaskan apa yang masih perlu dilanjutkan di IDE
- kasih titik masuk file penting supaya lanjutnya cepat

## Ringkasan singkat

Flutter mobile app sudah dipoles cukup besar supaya lebih dekat ke feel web monev.app:
- visual lebih premium / lebih rapi
- hierarchy halaman lebih jelas
- tone copy lebih konsisten Indonesia
- login live ke https://monev.app sudah diarahkan benar
- package ID final sudah diganti ke id.monev.app
- APK debug terbaru berhasil dibuild
- branch perubahan sudah dipush ke GitHub: monev-deploy

## Yang sudah dilakukan

### 1) Environment dan build mobile
Sudah dilakukan:
- install Flutter di VPS
- install Android SDK/cmdline tools/NDK yang diperlukan
- accept Android licenses
- upgrade Android build tooling supaya kompatibel dengan Flutter yang terpasang
- tambah swap agar build APK tidak OOM

Status verifikasi:
- flutter pub get: sukses
- flutter test: sukses
- flutter analyze lib: sukses, no issues found
- flutter build apk --debug --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://monev.app: sukses

Output APK debug terakhir:
- flutter_app/build/app/outputs/flutter-apk/app-debug.apk

### 2) Package / bundle identity
Sudah dilakukan:
- Android applicationId / namespace diubah ke final: id.monev.app
- iOS bundle identifier diubah ke final: id.monev.app
- MainActivity Kotlin dipindah ke path package baru

File yang relevan:
- flutter_app/android/app/build.gradle
- flutter_app/android/app/src/main/kotlin/id/monev/app/MainActivity.kt
- flutter_app/ios/Runner.xcodeproj/project.pbxproj

### 3) Fix API base URL mobile
Masalah sebelumnya:
- APK sempat kebuild dengan default development host 10.0.2.2:3000, jadi login gagal di HP fisik

Sudah dilakukan:
- default API base diarahkan ke https://monev.app
- build APK terbaru pakai dart define production/live

File relevan:
- flutter_app/lib/core/config/app_config.dart
- flutter_app/lib/core/network/api_client.dart

Catatan:
- meski default sekarang aman ke live, tetap lebih bagus build release/CI selalu pakai explicit dart-define

### 4) Sinkronisasi backend mobile auth ke live server
Sudah dilakukan di sisi backend/live sebelumnya:
- mobile auth endpoints live sudah jalan
- middleware/live route yang perlu untuk /api/mobile/* sudah dibereskan
- akun test admin sudah dibuat untuk login mobile

Credential test yang sempat dipakai:
- Email: admin@monevapp.web.id
- Password: Monev@2026!

Catatan:
- ini akun test, kalau mau dipakai jangka panjang sebaiknya nanti diganti/rapikan lagi

### 5) Pass UI/UX besar di Flutter app
Sudah dilakukan pass visual supaya mobile lebih dekat ke monev.app web.

Shared layer yang diubah:
- flutter_app/lib/core/theme/app_theme.dart
- flutter_app/lib/core/presentation/mobile_scaffold.dart
- flutter_app/lib/core/presentation/async_state_views.dart

Perubahan shared:
- theme lebih premium sky/blue finance feel
- card, button, input, dialog, snackbar, nav lebih rapi
- loading / empty / error states lebih polished
- authenticated shell lebih konsisten

Halaman yang sudah dipoles:
- flutter_app/lib/features/auth/presentation/login_page.dart
- flutter_app/lib/features/dashboard/presentation/dashboard_page.dart
- flutter_app/lib/features/transactions/presentation/transactions_page.dart
- flutter_app/lib/features/accounts/presentation/accounts_page.dart
- flutter_app/lib/features/budgets/presentation/budgets_page.dart
- flutter_app/lib/features/goals/presentation/goals_page.dart
- flutter_app/lib/features/bills/presentation/bills_page.dart
- flutter_app/lib/features/debts/presentation/debts_page.dart
- flutter_app/lib/features/investments/presentation/investments_page.dart
- flutter_app/lib/features/recurring/presentation/recurring_page.dart
- flutter_app/lib/features/reports/presentation/reports_page.dart
- flutter_app/lib/features/ai/presentation/ai_chat_page.dart
- flutter_app/lib/features/ai/presentation/ai_insight_page.dart
- flutter_app/lib/features/profile/presentation/profile_page.dart

### 6) Halaman Profile
Halaman profile sudah sempat dipoles duluan lalu diselaraskan lagi.

Perubahan utamanya:
- title jadi "Profil"
- header card user lebih proper
- chip tier / username
- section dikelompokkan, tidak lagi list tombol flat panjang
- copy lebih konsisten Indonesia
- edit dialog ikut dirapikan

File utama:
- flutter_app/lib/features/profile/presentation/profile_page.dart

### 7) Git / branch
Status git saat dokumen ini dibuat:
- perubahan sudah di-commit dan dipush ke branch monev-deploy

Commit penting terakhir:
- 54ef7ec feat: polish Flutter mobile UI
- 041e5ea chore: remove temporary GitHub write test file

Catatan:
- file APK besar tidak ikut dipertahankan di git commit terakhir supaya repo tidak berat
- APK tetap ada di local build output dan sempat diupload ke Drive

## Yang masih perlu dilakukan

Berikut prioritas paling masuk akal untuk lu lanjut di IDE.

### Prioritas A — Review visual pass kedua
Meskipun UI sudah jauh lebih proper, mobile belum 100% setara design language web.

Paling penting untuk dilanjutkan:
1. Dashboard
2. Transactions
3. Login

Kenapa 3 ini dulu:
- paling ngaruh ke first impression
- paling keliatan bedanya dibanding web
- kalau 3 ini matang, app terasa jauh lebih "jadi"

Checklist review visual:
- samakan spacing rhythm dengan web
- samakan radius/elevation/card grouping
- samakan hierarchy heading/subheading/CTA
- pastikan bottom nav lebih rapi dan tidak terlalu generic Flutter
- kurangi elemen yang masih terasa CRUD/admin panel

File fokus:
- flutter_app/lib/features/dashboard/presentation/dashboard_page.dart
- flutter_app/lib/features/transactions/presentation/transactions_page.dart
- flutter_app/lib/features/auth/presentation/login_page.dart
- flutter_app/lib/core/theme/app_theme.dart
- flutter_app/lib/core/presentation/mobile_scaffold.dart

### Prioritas B — QA manual per halaman di device
Perlu dicek manual di HP/emulator setelah pass UI:
- login
- dashboard
- transaksi list + create/edit/delete
- accounts CRUD
- budgets CRUD
- goals CRUD
- bills/debts/investments/recurring CRUD
- reports page actions
- AI chat dan AI insight states
- profile + edit settings

Checklist QA:
- overflow text di layar kecil
- tombol terlalu rapat / terlalu kecil
- dialog keyboard overlap
- FAB/tab/nav tidak nutup konten
- empty state / loading state konsisten
- copy bahasa masih campur atau belum enak

### Prioritas C — Release prep
Belum final store-ready. Yang masih perlu:
- setup Android signing config release
- build appbundle/release APK
- pastikan icon/splash/final branding rapi
- review iOS signing kalau mau rilis iOS
- siapkan release pipeline yang explicit pakai dart define live

File / area yang relevan:
- flutter_app/android/app/build.gradle
- flutter_app/android/gradle.properties
- flutter_app/ios/Runner.xcodeproj/project.pbxproj

### Prioritas D — Rapihin data/account test
Sebaiknya bereskan juga nanti:
- cek lagi akun admin test / akun demo
- kalau tidak mau tetap ada di live, ganti atau bersihkan
- rapikan duplicate/legacy user kalau masih ada

## Saran alur kerja lanjut di IDE

Kalau mau lanjut sendiri dengan aman, saran gw begini:

1. checkout branch kerja
- git checkout monev-deploy
- git pull origin monev-deploy

2. fokus dulu ke 3 halaman inti
- login
- dashboard
- transactions

3. setiap batch perubahan, jalankan:
- cd flutter_app
- flutter analyze lib
- flutter test
- flutter build apk --debug --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://monev.app

4. install ulang APK ke HP untuk cek visual nyata

5. kalau visual udah mantap baru lanjut release build/signing

## Command yang kepakai dan masih relevan

Run live local test:
- cd flutter_app
- flutter run --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://monev.app

Analyze:
- cd flutter_app
- flutter analyze lib

Test:
- cd flutter_app
- flutter test

Build debug APK:
- cd flutter_app
- flutter build apk --debug --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://monev.app

## Catatan penting teknis

- Default API sekarang aman ke https://monev.app, tapi jangan terlalu bergantung ke default untuk release
- APK lama yang sempat gagal login adalah build yang masih kebawa host development; APK terbaru sudah dibenerin
- Page styling sekarang lebih baik, tapi masih ada ruang buat pass design yang lebih ketat ke web
- Jangan lupa cek lagi public/live UX dari perspektif user biasa, bukan cuma developer CRUD flow

## File entry points paling penting

Kalau mau cepat paham struktur, buka file ini dulu:
- flutter_app/lib/core/theme/app_theme.dart
- flutter_app/lib/core/presentation/mobile_scaffold.dart
- flutter_app/lib/core/presentation/async_state_views.dart
- flutter_app/lib/features/auth/presentation/login_page.dart
- flutter_app/lib/features/dashboard/presentation/dashboard_page.dart
- flutter_app/lib/features/transactions/presentation/transactions_page.dart
- flutter_app/lib/features/profile/presentation/profile_page.dart
- flutter_app/lib/core/config/app_config.dart

## Status akhir saat handoff

- branch remote siap dilanjutkan: monev-deploy
- Flutter analyze: bersih
- debug APK build: sukses
- UI sudah jauh lebih proper dibanding awal
- paling layak dilanjutkan sekarang: visual tightening + QA manual + release prep
