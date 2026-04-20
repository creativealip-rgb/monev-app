# Checklist Konversi Web App -> Aplikasi Mobile Utuh (Flutter)

Gunakan checklist ini sebagai single source of truth progres.  
Status:
- `[x]` = sudah selesai
- `[ ]` = belum selesai
- `[-]` = tidak perlu / optional

---

## 1) Discovery & Scope

- [x] Tentukan target platform awal (Android dulu, iOS menyusul).
- [x] Tentukan pendekatan arsitektur: Flutter app + existing backend Next.js API.
- [x] Tentukan scope MVP mobile (auth, dashboard, transaksi, budget, goals, akun).
- [x] Definisikan scope non-MVP (bills, debts, investments, AI chat, reports, dll).
- [x] Definisikan acceptance criteria final “aplikasi utuh” per fitur.

## 2) Backend Readiness untuk Mobile

- [x] Siapkan auth mobile berbasis JWT access token + refresh token.
- [x] Simpan refresh token secara aman (hashed + rotasi + revocation).
- [x] Tambahkan endpoint auth mobile:
  - [x] `POST /api/mobile/auth/login`
  - [x] `POST /api/mobile/auth/refresh`
  - [x] `POST /api/mobile/auth/logout`
  - [x] `GET /api/mobile/auth/me`
- [x] Tambahkan auth guard reusable untuk endpoint mobile (`Bearer`).
- [x] Update middleware/proxy agar request `/api/mobile/*` dengan bearer token lolos.
- [x] Tambahkan endpoint data MVP mobile:
  - [x] Profile (`GET/PATCH /api/mobile/profile`)
  - [x] Dashboard summary (`GET /api/mobile/dashboard/summary`)
  - [x] Categories (`GET /api/mobile/categories`)
  - [x] Transactions CRUD (`/api/mobile/transactions`, `/api/mobile/transactions/[id]`)
  - [x] Budgets CRUD (`/api/mobile/budgets`, `/api/mobile/budgets/[id]`)
  - [x] Goals CRUD (`/api/mobile/goals`, `/api/mobile/goals/[id]`)
  - [x] Accounts CRUD (`/api/mobile/accounts`, `/api/mobile/accounts/[id]`)
- [x] Tambahkan endpoint mobile untuk fitur non-MVP yang dibutuhkan (jika belum ada).
- [x] Tambahkan API contract doc khusus mobile (request/response/error code).

## 3) Flutter Project Foundation

- [x] Inisialisasi `flutter_app` dan dependencies inti.
- [x] Buat base networking (`Dio`) + interceptor auth + auto refresh token.
- [x] Buat secure token storage.
- [x] Setup routing dasar (`go_router`).
- [x] Setup app shell + bottom navigation (`MobileScaffold`).
- [x] Setup environment config per flavor (dev/staging/prod) dengan jelas.
- [x] Setup centralized theme + design tokens agar konsisten dengan web brand.

## 4) Implementasi Fitur UI Mobile (MVP)

- [x] Login screen terhubung ke mobile auth API.
- [x] Dashboard screen terhubung ke summary API.
- [x] Transactions screen: list + create + update + delete.
- [x] Budgets screen: list + create + update + delete.
- [x] Goals screen: list + create + update + delete.
- [x] Accounts screen: list + create + update + delete.
- [x] Profile/settings screen mobile lengkap.
- [x] Route guard startup (auto-login jika token valid, redirect jika invalid).
- [x] Empty/error/loading state yang rapi dan konsisten di semua screen.
- [x] UX polish (form validation UX, toast/snackbar, confirm dialogs yang konsisten).

## 5) Integrasi Fitur Lanjutan (Menuju “Aplikasi Utuh”)

- [x] Prioritasi dan implement fitur utama non-MVP:
  - [x] Bills
  - [x] Debts
  - [x] Investments
  - [x] Recurring transactions
  - [x] Reports/export
  - [x] AI chat/insight
- [ ] Sinkronisasi behavior web vs mobile (business rules dan edge cases sama).
- [x] Tambahkan upload/import flow jika diperlukan di mobile.

## 6) Security, Reliability, dan Observability

- [x] Hardening auth flow (token expiry policy, logout-all-session opsional).
- [x] Rate limit & abuse handling di endpoint mobile final.
- [x] Audit error handling (backend + mobile), hindari silent failure.
- [x] Tambahkan logging/monitoring untuk endpoint mobile penting.
- [x] Review keamanan penyimpanan lokal dan data sensitif.

## 7) Testing & QA

- [x] Regression web backend dasar (test + build existing repo).
- [ ] Jalankan Flutter checks lokal:
  - [x] `flutter pub get`
  - [x] `flutter analyze`
  - [x] `flutter test`
  - [x] `flutter run` (debug device/emulator)
- [x] Tambahkan widget/integration test untuk alur kritikal mobile.
- [x] End-to-end QA checklist (auth, CRUD, network error, token refresh, logout).
- [ ] UAT dengan skenario user nyata.

## 8) Release Engineering

- [ ] Setup app id/bundle id final + app name + icon + splash.
- [ ] Setup signing Android (keystore) dan iOS signing (cert/profile).
- [x] Setup CI/CD mobile (build APK/AAB, release workflow).
- [ ] Build internal testing artifact:
  - [x] Android APK/AAB
  - [ ] iOS TestFlight build
- [ ] Persiapan store listing (screenshots, description, privacy policy).
- [ ] Publish bertahap (internal -> closed beta -> public release).

## 9) Post-Launch

- [ ] Setup crash reporting + analytics event penting.
- [ ] Monitoring performa (startup time, API latency, ANR/crash rate).
- [ ] Feedback loop user + bugfix backlog.
- [ ] Rencana iterasi fitur pasca rilis.

---

## Ringkasan Progres Saat Ini

- **Backend mobile API core:** mayoritas **sudah siap**.
- **Flutter MVP core screens:** **sudah ada** (Login, Dashboard, Transactions, Budgets, Goals, Accounts).
- **Gap utama sebelum “aplikasi utuh”:** full QA Flutter di device nyata, signing Android/iOS, build artifact release, UAT, dan distribusi store.

## Acceptance Criteria “Aplikasi Utuh” (Final)

- [x] **Auth & Session:** login/refresh/logout (single device + all sessions) stabil, token tersimpan aman, unauthorized flow jelas.
- [x] **Core CRUD Mobile:** transaksi, budget, goals, akun, profile/settings berjalan end-to-end dengan validasi + feedback error.
- [x] **Advanced Features:** bills, debts, investments, recurring, reports/export, AI insight/chat tersedia di API + UI mobile.
- [x] **Import/Export:** user bisa export data dan import transaksi massal dari mobile.
- [x] **Runtime Quality Gate:** lulus `flutter analyze`, `flutter test`, dan smoke run di device/emulator.
- [ ] **Release Gate:** signing Android/iOS selesai, CI/CD build artifact jalan, siap distribusi internal/store.

## E2E QA Checklist (Ready to Execute)

- [x] Login valid, login invalid, logout current session, logout semua perangkat.
- [x] Token refresh otomatis saat access token expired.
- [x] CRUD transaksi/budget/goals/accounts dari mobile tanpa mismatch API.
- [x] Alur features lanjutan: bills, debts, investments, recurring, reports/export, AI chat/insight.
- [x] Import transaksi bulk + verifikasi data hasil import.
- [x] Simulasi network error (timeout/401/500) dan verifikasi feedback error ke user.

