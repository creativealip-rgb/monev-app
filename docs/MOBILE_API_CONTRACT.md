# Mobile API Contract (Flutter App)

Base path: `/api/mobile`

Semua response memakai pola:
- Success: `{ "success": true, "data": ... }`
- Error: `{ "success": false, "code": "...", "error": "..." }`

Auth:
- Gunakan header `Authorization: Bearer <accessToken>`
- Refresh flow via `POST /api/mobile/auth/refresh`

## Auth

### POST `/auth/login`
Request:
```json
{ "email": "user@mail.com", "password": "secret" }
```
Response `200`:
```json
{
  "success": true,
  "data": {
    "accessToken": "jwt",
    "refreshToken": "opaque-token",
    "user": { "id": 1, "email": "user@mail.com", "tier": "starter" }
  }
}
```

### POST `/auth/refresh`
Request:
```json
{ "refreshToken": "opaque-token" }
```
Response `200`: token pair baru.

### POST `/auth/logout`
Request:
```json
{ "refreshToken": "opaque-token" }
```
Response `200`: `{ "success": true }`

Logout semua sesi (opsional):
```json
{ "allSessions": true }
```
Catatan:
- `refreshToken` saja -> logout sesi/perangkat saat ini.
- `allSessions: true` + bearer token valid -> revoke semua sesi user di semua perangkat.

### GET `/auth/me`
Response `200`: data user mobile.

## Profile

### GET `/profile`
Response `200`:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@mail.com",
      "firstName": "Ali",
      "lastName": "Pratama",
      "username": "alip",
      "whatsappId": "628123...",
      "tier": "starter"
    },
    "settings": {
      "hideBalance": false,
      "notificationsEnabled": true,
      "reportLocale": "auto"
    }
  }
}
```

### PATCH `/profile`
Request (partial update, semua optional):
```json
{
  "firstName": "Ali",
  "lastName": "Pratama",
  "username": "alip",
  "whatsappId": "628123...",
  "hideBalance": true,
  "notificationsEnabled": false,
  "reportLocale": "id"
}
```
Response `200`: `{ "success": true }`

## Dashboard

### GET `/dashboard/summary`
Response `200`: ringkasan statistik dashboard (income, expense, balance, totals).

## Master

### GET `/categories`
Response `200`: daftar kategori user.

## Transactions

### GET `/transactions?limit=20&offset=0&search=...`
Response `200`:
```json
{
  "success": true,
  "data": [],
  "pagination": {
    "total": 0,
    "limit": 20,
    "offset": 0,
    "hasMore": false
  }
}
```

### POST `/transactions`
Request:
```json
{
  "amount": 100000,
  "description": "Makan siang",
  "categoryId": 1,
  "type": "expense",
  "paymentMethod": "cash",
  "accountId": 1
}
```
Response `201`: transaksi baru.

### POST `/transactions/import`
Request:
```json
{
  "transactions": [
    {
      "amount": 25000,
      "description": "Makan siang",
      "type": "expense",
      "category": "Makan & Minuman",
      "date": "2026-04-20"
    }
  ]
}
```
Response `200`:
```json
{
  "success": true,
  "data": {
    "total": 1,
    "imported": 1,
    "failed": 0
  }
}
```

### GET `/transactions/{id}` / PATCH `/transactions/{id}` / DELETE `/transactions/{id}`
- GET `200`: detail transaksi
- PATCH `200`: transaksi terupdate
- DELETE `200`: `{ "success": true }`

## Budgets

### GET `/budgets?month=4&year=2026`
Response `200`: daftar budget + progress spent.

### POST `/budgets`
Request:
```json
{
  "categoryId": 1,
  "amount": 2000000,
  "month": 4,
  "year": 2026,
  "enableRollover": false
}
```
Response `201`: budget baru.

### PATCH `/budgets/{id}` / DELETE `/budgets/{id}`
- PATCH `200`: budget terupdate
- DELETE `200`: `{ "success": true }`

## Goals

### GET `/goals`
Response `200`: daftar goals.

### POST `/goals`
Request:
```json
{
  "name": "Dana Darurat",
  "targetAmount": 10000000,
  "currentAmount": 1000000
}
```
Response `201`: goal baru.

### GET `/goals/{id}` / PATCH `/goals/{id}` / DELETE `/goals/{id}`
- GET `200`: detail goal
- PATCH `200`: goal terupdate
- DELETE `200`: `{ "success": true }`

## Accounts

### GET `/accounts`
Response `200`: daftar akun user.

### POST `/accounts`
Request:
```json
{
  "name": "BCA",
  "type": "bank",
  "balance": 5000000,
  "isActive": true
}
```
Response `201`: akun baru.

### GET `/accounts/{id}` / PATCH `/accounts/{id}` / DELETE `/accounts/{id}`
- GET `200`: detail akun
- PATCH `200`: akun terupdate
- DELETE `200`: `{ "success": true }`

## Bills

### GET `/bills`
Response `200`: daftar tagihan user.

### POST `/bills`
Request:
```json
{
  "name": "Listrik PLN",
  "amount": 350000,
  "dueDate": 20,
  "frequency": "monthly",
  "notes": "Tagihan rutin"
}
```
Response `201`: tagihan baru.

### GET `/bills/{id}` / PATCH `/bills/{id}` / DELETE `/bills/{id}`
- GET `200`: detail tagihan
- PATCH `200`: update tagihan (termasuk toggle lunas via `{ "action": "toggle" }`)
- DELETE `200`: `{ "success": true }`

## Debts

### GET `/debts`
Response `200`: daftar hutang + piutang.

### POST `/debts`
Request:
```json
{
  "debtorName": "Budi",
  "amount": 500000,
  "description": "Pinjam sementara",
  "direction": "owe"
}
```
Response `201`: data debt baru.

### PATCH `/debts/{id}` / DELETE `/debts/{id}`
- PATCH `200`: update debt (status paid/unpaid atau field lainnya)
- DELETE `200`: `{ "success": true }`

## Investments

### GET `/investments`
Response `200`: ringkasan investasi + list item (`totalValue`, `totalProfit`, `items`).

### POST `/investments`
Request:
```json
{
  "name": "BBCA",
  "type": "stock",
  "quantity": 100,
  "avgBuyPrice": 9200,
  "currentPrice": 10500
}
```
Response `201`: investasi baru.

### GET `/investments/{id}` / PATCH `/investments/{id}` / DELETE `/investments/{id}`
- GET `200`: detail investasi
- PATCH `200`: investasi terupdate
- DELETE `200`: `{ "success": true }`

## Recurring Transactions

### GET `/recurring`
Response `200`: daftar recurring transactions user.

### POST `/recurring`
Request:
```json
{
  "amount": 1500000,
  "description": "Gaji bulanan",
  "type": "income",
  "frequency": "monthly",
  "isActive": true
}
```
Response `201`: recurring baru.

### GET `/recurring/{id}` / PATCH `/recurring/{id}` / DELETE `/recurring/{id}`
- GET `200`: detail recurring transaction
- PATCH `200`: recurring terupdate
- DELETE `200`: `{ "success": true }`

## Reports & Export

### GET `/reports/history`
Response `200`: riwayat laporan user.

### GET `/reports/export?format=csv|json`
Response `200`:
- `csv` -> plain text CSV transaksi
- `json` -> object export transaksi

## AI Insight

### GET `/ai/insight`
Response `200`:
```json
{
  "success": true,
  "data": {
    "insight": "teks insight",
    "type": "success|warning|info",
    "source": "openai|fallback"
  }
}
```

## AI Chat

### GET `/ai/history?limit=50`
Response `200`:
```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "userId": 1,
      "role": "user|assistant",
      "content": "teks chat",
      "createdAt": "2026-01-01T10:00:00.000Z"
    }
  ]
}
```

### POST `/ai/chat`
Request:
```json
{
  "message": "gimana kondisi keuangan bulan ini?",
  "history": [
    { "role": "user", "content": "halo" },
    { "role": "assistant", "content": "halo juga" }
  ]
}
```
Response `200`:
```json
{
  "success": true,
  "data": {
    "reply": "jawaban AI",
    "source": "openai|fallback",
    "usageToday": 3,
    "generatedAt": "2026-01-01T10:05:00.000Z"
  }
}
```

## Error Code Umum

- `UNAUTHORIZED` -> token invalid/expired
- `INVALID_INPUT` -> input/query param tidak valid
- `VALIDATION_ERROR` -> validasi payload gagal
- `NOT_FOUND` -> data tidak ditemukan
- `FORBIDDEN` -> melewati batas tier/akses
- `SERVER_ERROR` -> error internal

