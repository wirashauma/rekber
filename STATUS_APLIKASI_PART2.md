# LAPORAN AUDIT TEKNIS INDEPENDEN: APLIKASI REKBER (BAGIAN 2)
# BAGIAN 6: DETAIL LENGKAP 73 ENDPOINT BACKEND

> **Dokumen Pendamping Audit Teknis & Status Kesiapan Aplikasi**  
> **Tanggal Audit:** 22 November 2026  
> **Auditor:** Senior Technical Auditor & Software Architect  
> **Dokumen Terkait:** `STATUS_APLIKASI.md` (Dokumen Utama: Bagian 1–5 dan 7–15)  
> **File:** `STATUS_APLIKASI_PART2.md`

---

Dokumen ini memuat analisis teknis mendalam terhadap **seluruh 73 endpoint API** yang tersedia pada backend Rekber (Express.js + Prisma 7 + PostgreSQL 16). Setiap entri mendokumentasikan method, path, berkas route/controller, skema autentikasi, validasi input, payload request/response, logika bisnis langkah demi langkah, penggunaan transaksi DB atomik, kontrol kepemilikan, dan status fungsionalnya.

---

## DAFTAR ISI KATALOG ENDPOINT
1. [Grup 1: Autentikasi dan Profil Pengguna (13 Endpoint)](#1-grup-1-autentikasi-dan-profil-pengguna-13-endpoint)
2. [Grup 2: Transaksi Escrow & Chat Realtime (11 Endpoint)](#2-grup-2-transaksi-escrow--chat-realtime-11-endpoint)
3. [Grup 3: Dompet, Top-Up & Penarikan Saldo (10 Endpoint)](#3-grup-3-dompet-top-up--penarikan-saldo-10-endpoint)
4. [Grup 4: Rekening Bank Pengguna (3 Endpoint)](#4-grup-4-rekening-bank-pengguna-3-endpoint)
5. [Grup 5: Konfigurasi Publik Platform (1 Endpoint)](#5-grup-5-konfigurasi-publik-platform-1-endpoint)
6. [Grup 6: Manajemen File & Media (3 Endpoint)](#6-grup-6-manajemen-file--media-3-endpoint)
7. [Grup 7: Sengketa Transaksi Pengguna (2 Endpoint)](#7-grup-7-sengketa-transaksi-pengguna-2-endpoint)
8. [Grup 8: Kotak Masuk Notifikasi (4 Endpoint)](#8-grup-8-kotak-masuk-notifikasi-4-endpoint)
9. [Grup 9: Verifikasi Identitas Pengguna / KYC (2 Endpoint)](#9-grup-9-verifikasi-identitas-pengguna--kyc-2-endpoint)
10. [Grup 10: Webhook Pembayaran Masuk (1 Endpoint)](#10-grup-10-webhook-pembayaran-masuk-1-endpoint)
11. [Grup 11: Observabilitas, Health & Metrik (3 Endpoint)](#11-grup-11-observabilitas-health--metrik-3-endpoint)
12. [Grup 12: Admin - Moderasi Penarikan Dana (3 Endpoint)](#12-grup-12-admin---moderasi-penarikan-dana-3-endpoint)
13. [Grup 13: Admin - Resolusi Sengketa Escrow (4 Endpoint)](#13-grup-13-admin---resolusi-sengketa-escrow-4-endpoint)
14. [Grup 14: Admin - Moderasi KYC (4 Endpoint)](#14-grup-14-admin---moderasi-kyc-4-endpoint)
15. [Grup 15: Admin - Metrik & Analitik Platform (1 Endpoint)](#15-grup-15-admin---metrik--analitik-platform-1-endpoint)
16. [Grup 16: Admin - Pengaturan Platform (2 Endpoint)](#16-grup-16-admin---pengaturan-platform-2-endpoint)
17. [Grup 17: Admin - Pemantauan Transaksi (1 Endpoint)](#17-grup-17-admin---pemantauan-transaksi-1-endpoint)
18. [Grup 18: Admin - Manajemen & Pemblokiran Pengguna (4 Endpoint)](#18-grup-18-admin---manajemen--pemblokiran-pengguna-4-endpoint)
19. [Grup 19: Admin - Jejak Audit Sistem (1 Endpoint)](#19-grup-19-admin---jejak-audit-sistem-1-endpoint)

---

## 1. Grup 1: Autentikasi dan Profil Pengguna (13 Endpoint)

### 1. `POST /api/auth/register`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:31`, `backend/src/controllers/auth.controller.js:25`
* **Autentikasi:** Publik (dilindungi `registerLimiter`: 5 request / 1 jam per IP).
* **Validasi Input (`auth.validator.js:10`):**
  - `name`: String, 2–100 karakter, trim.
  - `email`: Format email valid, dinormalisasi huruf kecil.
  - `password`: Minimal 8 karakter, wajib memuat huruf besar, huruf kecil, dan angka.
* **Request & Response:**
  - *Request Body:* `{"name": "Budi Santoso", "email": "budi@example.com", "password": "Password123"}`
  - *Response Sukses (201 Created):*
    ```json
    {
      "success": true,
      "message": "Registrasi berhasil.",
      "data": {
        "user": {"id": "uuid", "name": "Budi Santoso", "email": "budi@example.com", "role": "USER", "balance": 0},
        "accessToken": "eyJhbG...",
        "refreshToken": "64_char_hex"
      }
    }
    ```
  - *Response Error (409 Conflict):* `{"success": false, "code": "CONFLICT", "message": "Email sudah terdaftar."}`
* **Logika Bisnis:**
  1. Mengecek ketiadaan email di database.
  2. Melakukan hashing password dengan `bcryptjs` (salt rounds 12).
  3. Menyimpan baris `User` baru dengan saldo awal 0.
  4. Menerbitkan access token (15 menit) dan hash SHA-256 refresh token ke tabel `refresh_tokens`.
* **Database Transaction:** Menggunakan `prisma.$transaction` untuk pembuatan User dan RefreshToken.
* **Status:** ✅ BERFUNGSI

---

### 2. `POST /api/auth/login`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:35`, `backend/src/controllers/auth.controller.js:52`
* **Autentikasi:** Publik (dilindungi `loginLimiter`: 10 percobaan / 15 menit per IP).
* **Validasi Input:** `email` format valid, `password` wajib diisi.
* **Request & Response:**
  - *Request Body:* `{"email": "budi@example.com", "password": "Password123"}`
  - *Response Sukses (200 OK):* Mengembalikan data `user`, `accessToken`, `refreshToken`.
  - *Response Error (401 Unauthorized):* `{"success": false, "code": "UNAUTHORIZED", "message": "Email atau kata sandi salah."}`
  - *Response Error (403 Forbidden):* `{"success": false, "code": "ACCOUNT_INACTIVE", "message": "Akun Anda telah dinonaktifkan."}`
* **Logika Bisnis:**
  1. Mencari user berdasarkan email.
  2. Verifikasi status `isActive === true`.
  3. Membandingkan password menggunakan `bcrypt.compare`.
  4. Menerbitkan token baru dan mencatat User Agent serta IP di `refresh_tokens`.
* **Database Transaction:** Tidak diperlukan (single write ke `refresh_tokens`).
* **Status:** ✅ BERFUNGSI

---

### 3. `POST /api/auth/refresh`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:39`, `backend/src/controllers/auth.controller.js:78`
* **Autentikasi:** Publik (memerlukan token refresh mentah, dilindungi `refreshLimiter`).
* **Validasi Input:** `refreshToken` string wajib diisi.
* **Request & Response:**
  - *Request Body:* `{"refreshToken": "hex_string"}`
  - *Response Sukses (200 OK):* `{"success": true, "data": {"accessToken": "...", "refreshToken": "new_hex"}}`
  - *Response Error (401 Unauthorized):* `{"success": false, "code": "TOKEN_THEFT_DETECTED", "message": "Indikasi pencurian token..."}`
* **Logika Bisnis:**
  1. Menghitung SHA-256 dari `refreshToken`.
  2. Mencari data di tabel `refresh_tokens`.
  3. Jika token sudah berstatus `revokedAt != null` (Reuse Detection), sistem seketika membatalkan **SEMUA** refresh token milik user tersebut.
  4. Jika valid dan belum kedaluwarsa, token lama di-revoke dan digantikan token baru (*rotation*).
* **Database Transaction:** Menggunakan `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 4. `POST /api/auth/logout`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:43`, `backend/src/controllers/auth.controller.js:98`
* **Autentikasi:** Publik / Opsional (menerima `refreshToken` di body).
* **Validasi Input:** None.
* **Logika Bisnis:** Mencari hash token dan menandai `revokedAt = new Date()`.
* **Status:** ✅ BERFUNGSI

---

### 5. `POST /api/auth/logout-all`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:47`, `backend/src/controllers/auth.controller.js:112`
* **Autentikasi:** JWT Wajib (`authenticate`).
* **Validasi Input:** None.
* **Logika Bisnis:** Menandai `revokedAt = new Date()` untuk seluruh baris di `refresh_tokens` yang dimiliki `req.user.id`.
* **Status:** ✅ BERFUNGSI

---

### 6. `PUT /api/auth/password`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:51`, `backend/src/controllers/auth.controller.js:125`
* **Autentikasi:** JWT Wajib (`authenticate`).
* **Validasi Input:** `oldPassword` string, `newPassword` minimal 8 karakter (kombinasi huruf besar, kecil, angka).
* **Logika Bisnis:**
  1. Verifikasi `oldPassword` via bcrypt.
  2. Hash `newPassword`.
  3. Update password user di tabel `users`.
  4. Cabut seluruh refresh token lama milik user agar perangkat lain ter-logout paksa.
* **Database Transaction:** Menggunakan `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 7. `POST /api/auth/forgot-password`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:55`, `backend/src/controllers/auth.controller.js:145`
* **Autentikasi:** Publik (dilindungi `forgotPasswordLimiter`: 5 req / 1 jam).
* **Validasi Input:** `email` format valid.
* **Logika Bisnis:**
  1. Mencari user berdasarkan email.
  2. Jika ditemukan, menerbitkan token acak 32-byte berumur 1 jam ke `password_reset_tokens`.
  3. Mengirimkan tautan reset password via `mail.provider.js`.
  4. Respon selalu mengembalikan HTTP 200 generic untuk mencegah *user enumeration attack*.
* **Status:** ✅ BERFUNGSI

---

### 8. `POST /api/auth/reset-password`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:65`, `backend/src/controllers/auth.controller.js:168`
* **Autentikasi:** Publik.
* **Validasi Input:** `token` hex 64 karakter, `newPassword` minimal 8 karakter kuat.
* **Logika Bisnis:**
  1. Verifikasi token di `password_reset_tokens` (belum expired dan `usedAt == null`).
  2. Hash password baru dan update ke tabel `users`.
  3. Tandai `usedAt = new Date()`.
  4. Cabut semua refresh token user.
* **Database Transaction:** Menggunakan `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 9. `POST /api/auth/forgot-email`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:69`, `backend/src/controllers/auth.controller.js:192`
* **Autentikasi:** Publik.
* **Status:** ✅ BERFUNGSI (Mengembalikan `410 Gone` secara sengaja untuk menutup endpoint lama).

---

### 10. `GET /api/auth/me`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:73`, `backend/src/controllers/auth.controller.js:200`
* **Autentikasi:** JWT Wajib (`authenticate`).
* **Logika Bisnis:** Mengambil profil user, saldo dompet, peran, status KYC, dan ketiadaan password hash.
* **Status:** ✅ BERFUNGSI

---

### 11. `PUT /api/auth/profile`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:77`, `backend/src/controllers/auth.controller.js:218`
* **Autentikasi:** JWT Wajib (`authenticate`).
* **Validasi Input:** `name` string 2–100 karakter.
* **Logika Bisnis:** Mengupdate nama pengguna pada tabel `users`.
* **Status:** ✅ BERFUNGSI

---

### 12. `POST /api/auth/update-fcm`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:81`, `backend/src/controllers/auth.controller.js:235`
* **Autentikasi:** JWT Wajib (`authenticate`).
* **Validasi Input:** `fcmToken` string non-empty.
* **Logika Bisnis:** Menyimpan registration token Firebase Cloud Messaging ke kolom `users.fcm_token`.
* **Status:** ✅ BERFUNGSI

---

### 13. `GET /api/auth/search-opponent`
* **File Route & Controller:** `backend/src/routes/auth.routes.js:85`, `backend/src/controllers/auth.controller.js:252`
* **Autentikasi:** JWT Wajib (`authenticate`).
* **Validasi Input:** Query parameter `query` string 2–100 karakter.
* **Logika Bisnis:** Mencari lawan transaksi berdasarkan kecocokan nama atau email (mengecualikan ID diri sendiri).
* **Status:** ✅ BERFUNGSI

---

## 2. Grup 2: Transaksi Escrow & Chat Realtime (11 Endpoint)

### 14. `POST /api/transactions`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:31`, `backend/src/controllers/transaction.controller.js:25`
* **Autentikasi:** JWT Wajib.
* **Validasi Input (`transaction.validator.js:12`):**
  - `sellerEmail`: Email valid penjual (tidak boleh email sendiri).
  - `amount`: Integer positif, minimal Rp 10.000, maksimal `max_transaction_amount` (Rp 5.000.000).
  - `itemDescription`: String 5–1.000 karakter.
  - `feePayer`: Enum opsional (`BUYER`, `SELLER`, `SPLIT`, default dari platform setting).
* **Logika Bisnis:**
  1. Menghitung biaya platform (`fee_percent` & `fee_min`).
  2. Menghasilkan kode unik 8 karakter alphanumeric yang tidak membingungkan (`generateUniqueCode`).
  3. Menyimpan baris `Transaction` berstatus `PENDING` dengan batas kedaluwarsa `expiresAt` 24 jam.
* **Database Transaction:** Prisma write single.
* **Status:** ✅ BERFUNGSI

---

### 15. `GET /api/transactions`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:35`, `backend/src/controllers/transaction.controller.js:55`
* **Autentikasi:** JWT Wajib.
* **Validasi Input:** Query `status`, `role` (buyer/seller), pagination.
* **Logika Bisnis:** Menampilkan seluruh transaksi di mana `buyerId === req.user.id` ATAU `sellerId === req.user.id`.
* **Status:** ✅ BERFUNGSI

---

### 16. `GET /api/transactions/code/:code`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:39`, `backend/src/controllers/transaction.controller.js:80`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Mengambil detail transaksi berdasarkan kode 8-digit. Mengizinkan partisipan atau siapapun yang ingin bergabung/mengecek room.
* **Status:** ✅ BERFUNGSI

---

### 17. `GET /api/transactions/:id`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:43`, `backend/src/controllers/transaction.controller.js:105`
* **Autentikasi:** JWT Wajib.
* **Kontrol Otorisasi (Anti-IDOR):** Hanya dapat diakses jika `buyerId === req.user.id`, `sellerId === req.user.id`, atau `req.user.role === 'ADMIN'`. Penyerang menerima 403 Forbidden.
* **Status:** ✅ BERFUNGSI

---

### 18. `POST /api/transactions/:id/shipment`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:47`, `backend/src/controllers/transaction.controller.js:130`
* **Autentikasi:** JWT Wajib (Hanya Penjual).
* **Validasi Input:** `courier` string, `trackingNumber` string, `fileIds` array UUID tujuan `SHIPMENT_PROOF`.
* **Logika Bisnis:**
  1. Transaksi wajib berstatus `PAID`.
  2. Beralih ke status `SHIPPED`.
  3. Mengisi `shippedAt` dan menghitung `autoReleaseAt` (sekarang + 72 jam).
  4. Menyimpan bukti ke tabel `shipment_proofs`.
  5. Memicu notifikasi FCM ke pembeli.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 19. `POST /api/transactions/:id/dispute`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:55`, `backend/src/controllers/dispute.controller.js:25`
* **Autentikasi:** JWT Wajib (Hanya Pembeli).
* **Validasi Input:** `reason` enum (`NOT_RECEIVED`, `NOT_AS_DESCRIBED`, `DEFECTIVE`, `OTHER`), `description` (20–2.000 karakter), `fileIds` opsional.
* **Logika Bisnis:**
  1. Transaksi wajib berstatus `PAID` atau `SHIPPED`.
  2. Status transaksi beralih ke `DISPUTED`.
  3. Kolom `autoReleaseAt` dikosongkan (`null`).
  4. Membuat baris `Dispute` berstatus `OPEN`.
  5. Menolak pembuatan sengketa ganda dengan HTTP 409 Conflict.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 20. `GET /api/transactions/:id/dispute`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:60`, `backend/src/controllers/dispute.controller.js:65`
* **Autentikasi:** JWT Wajib (Partisipan transaksi atau Admin).
* **Logika Bisnis:** Mengambil data sengketa, kronologi, dan berkas bukti terkait transaksi.
* **Status:** ✅ BERFUNGSI

---

### 21. `PUT /api/transactions/:id/status`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:69`, `backend/src/controllers/transaction.controller.js:165`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Menggerakkan state machine transaksi:
  - Pembeli bayar: `PENDING` -> `PAID` (memotong saldo dan menahan escrow).
  - Pembeli konfirmasi terima: `SHIPPED` -> `COMPLETED` (melepaskan dana ke saldo penjual via `releaseEscrow`).
  - Pembatalan transaksi: `PENDING` -> `CANCELLED`.
* **Database Transaction:** `prisma.$transaction` pada setiap aksi finansial.
* **Status:** ✅ BERFUNGSI

---

### 22. `GET /api/transactions/:id/messages`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:82`, `backend/src/controllers/chat.controller.js:25`
* **Autentikasi:** JWT Wajib (Pembeli & Penjual; Admin hanya jika status `DISPUTED`).
* **Validasi Input:** Query `cursor` (UUID), `limit` (1–50).
* **Logika Bisnis:** Mengambil pesan obrolan terpaginasi kursor secara kronologis menurun.
* **Status:** ✅ BERFUNGSI

---

### 23. `POST /api/transactions/:id/messages`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:86`, `backend/src/controllers/chat.controller.js:60`
* **Autentikasi:** JWT Wajib (Pembeli & Penjual; dibatasi 20 pesan/menit).
* **Validasi Input:** `type` (`TEXT`/`IMAGE`), `body` (maks 2.000 karakter), `fileId` (tujuan `CHAT_IMAGE`).
* **Logika Bisnis:**
  1. Menolak pengiriman pesan jika transaksi telah berstatus terminal (`COMPLETED`, `CANCELLED`, `REFUNDED`).
  2. Menyimpan pesan ke `chat_messages`.
  3. Memancarkan event WebSocket `chat:message` ke room Socket.IO transaksi.
  4. Mengirimkan push notifikasi latar belakang ke lawan bicara jika sedang offline.
* **Status:** ✅ BERFUNGSI

---

### 24. `POST /api/transactions/:id/messages/read`
* **File Route & Controller:** `backend/src/routes/transaction.routes.js:95`, `backend/src/controllers/chat.controller.js:105`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Mengupdate `ChatReadState` (`lastReadAt = new Date()`) dan memancarkan event Socket `chat:read`.
* **Status:** ✅ BERFUNGSI

---

## 3. Grup 3: Dompet, Top-Up & Penarikan Saldo (10 Endpoint)

### 25. `POST /api/wallet/topups`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:23`, `backend/src/controllers/topup.controller.js:25`
* **Autentikasi:** JWT Wajib (dilindungi `topUpLimiter`: 10 req / 15 menit).
* **Validasi Input:** `amount` (min Rp 10.000, max Rp 10.000.000), `method` (`QRIS` / `VIRTUAL_ACCOUNT`), `bankCode` opsional.
* **Logika Bisnis:** Membuat entri `PaymentIntent` berstatus `PENDING` dan menghasilkan instruksi bayar dari gateway Xendit/Fake.
* **Status:** ✅ BERFUNGSI

---

### 26. `GET /api/wallet/topups/:id`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:29`, `backend/src/controllers/topup.controller.js:60`
* **Autentikasi:** JWT Wajib (Hanya pemilik intent).
* **Logika Bisnis:** Mengambil detail status pembayaran dan instruksi QR/VA untuk polling di aplikasi mobile.
* **Status:** ✅ BERFUNGSI

---

### 27. `GET /api/wallet/topups`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:35`, `backend/src/controllers/topup.controller.js:85`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Menampilkan riwayat transaksi top-up pengguna dengan paginasi kursor.
* **Status:** ✅ BERFUNGSI

---

### 28. `GET /api/wallet`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:41`, inline handler memanggil `walletService.getWalletSummary`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Mengembalikan saldo aktif (`balance`) dan saldo yang sedang tertahan di transaksi aktif (`heldEscrow`).
* **Status:** ✅ BERFUNGSI

---

### 29. `GET /api/wallet/ledger`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:58`, inline handler memanggil `walletService.getLedgerHistory`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Mengembalikan daftar mutasi buku besar (`LedgerEntry`) pengguna (tipe, arah, jumlah, saldo setelahnya).
* **Status:** ✅ BERFUNGSI

---

### 30. `POST /api/wallet/withdrawals`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:76`, `backend/src/controllers/withdrawal.controller.js:25`
* **Autentikasi:** JWT Wajib.
* **Validasi Input:** `bankAccountId` UUID, `amount` (minimal `withdraw_min`, maksimal limit harian).
* **Logika Bisnis:**
  1. Memverifikasi status KYC pengguna (`kycStatus === 'APPROVED'`).
  2. Memotong saldo pengguna seketika dan menahan dalam status `PENDING_REVIEW` dengan entri buku besar `WITHDRAWAL_RESERVE`.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 31. `GET /api/wallet/withdrawals`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:82`, `backend/src/controllers/withdrawal.controller.js:65`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Menampilkan riwayat pengajuan penarikan dana milik pengguna.
* **Status:** ✅ BERFUNGSI

---

### 32. `POST /api/wallet/withdrawals/:id/cancel`
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:88`, `backend/src/controllers/withdrawal.controller.js:90`
* **Autentikasi:** JWT Wajib (Hanya pemilik pengajuan).
* **Logika Bisnis:** Membatalkan penarikan yang masih berstatus `PENDING_REVIEW` dan mengembalikan dana tertahan ke saldo pengguna.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 33. `POST /api/wallet/topup` (Legacy)
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:99`
* **Status:** ✅ BERFUNGSI (Mengembalikan `410 Gone` secara sengaja untuk menutup celah manipulasi saldo).

---

### 34. `POST /api/wallet/withdraw` (Legacy)
* **File Route & Controller:** `backend/src/routes/wallet.routes.js:109`
* **Status:** ✅ BERFUNGSI (Mengembalikan `410 Gone` secara sengaja).

---

## 4. Grup 4: Rekening Bank Pengguna (3 Endpoint)

### 35. `GET /api/bank-accounts`
* **File Route & Controller:** `backend/src/routes/bankAccount.routes.js:22`, `backend/src/controllers/bankAccount.controller.js:20`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Menampilkan daftar rekening bank aktif (`deletedAt == null`). Nomor rekening disamarkan (`••••••••1234`).
* **Status:** ✅ BERFUNGSI

---

### 36. `POST /api/bank-accounts`
* **File Route & Controller:** `backend/src/routes/bankAccount.routes.js:28`, `backend/src/controllers/bankAccount.controller.js:45`
* **Autentikasi:** JWT Wajib.
* **Validasi Input:** `bankCode` string 2–20, `accountNumber` numeric 5–30 digit, `accountName` string 2–100.
* **Logika Bisnis:** Mengenkripsi nomor rekening menggunakan AES-256-GCM (`accountNumberEnc`), mengekstrak 4 digit terakhir (`accountLast4`), dan menyimpannya ke database.
* **Status:** ✅ BERFUNGSI

---

### 37. `DELETE /api/bank-accounts/:id`
* **File Route & Controller:** `backend/src/routes/bankAccount.routes.js:34`, `backend/src/controllers/bankAccount.controller.js:80`
* **Autentikasi:** JWT Wajib (Hanya pemilik rekening).
* **Logika Bisnis:** Melakukan soft delete (`deletedAt = new Date()`).
* **Status:** ✅ BERFUNGSI

---

## 5. Grup 5: Konfigurasi Publik Platform (1 Endpoint)

### 38. `GET /api/config/public`
* **File Route & Controller:** `backend/src/routes/config.routes.js:13`
* **Autentikasi:** Publik tanpa token.
* **Logika Bisnis:** Mengambil nilai konfigurasi platform yang di-cache di memori (`fee_percent`, `fee_min`, `fee_payer_default`, `withdraw_min`, `withdraw_fee`, `max_transaction_amount`).
* **Status:** ✅ BERFUNGSI

---

## 6. Grup 6: Manajemen File & Media (3 Endpoint)

### 39. `POST /api/files`
* **File Route & Controller:** `backend/src/routes/file.routes.js:22`, `backend/src/controllers/file.controller.js:25`
* **Autentikasi:** JWT Wajib.
* **Middleware Pemrosesan:** `uploadAndSanitize` (`multer` + `sharp`): memeriksa MIME image (JPEG/PNG/WEBP), ukuran maks 5MB, membersihkan metadata EXIF GPS, dan menghitung SHA-256.
* **Logika Bisnis:** Menyimpan file ke S3 atau folder lokal, dan mencatat `FileAsset` dengan tujuan (`purpose`: `SHIPMENT_PROOF`, `DISPUTE_EVIDENCE`, `KYC_ID`, `KYC_SELFIE`, `CHAT_IMAGE`).
* **Status:** ✅ BERFUNGSI

---

### 40. `GET /api/files/:id/url`
* **File Route & Controller:** `backend/src/routes/file.routes.js:28`, `backend/src/controllers/file.controller.js:65`
* **Autentikasi:** JWT Wajib.
* **Kontrol Otorisasi (`fileAccessPolicies`):**
  - KYC: Hanya pemilik atau Admin.
  - Bukti Resi / Sengketa / Chat: Hanya partisipan transaksi terkait atau Admin.
* **Logika Bisnis:** Menghasilkan URL bertanda tangan berumur pendek (15 menit) dari AWS S3 Presigner atau HMAC local token.
* **Status:** ✅ BERFUNGSI

---

### 41. `GET /api/files/download/{*key}`
* **File Route & Controller:** `backend/src/routes/file.routes.js:16`, `backend/src/controllers/file.controller.js:105`
* **Autentikasi:** Parameter query URL bertanda tangan (`?expires=...&signature=...`).
* **Logika Bisnis:** Memverifikasi tanda tangan HMAC dan timestamp kedaluwarsa sebelum mengalirkan file statis lokal ke klien.
* **Status:** ✅ BERFUNGSI

---

## 7. Grup 7: Sengketa Transaksi Pengguna (2 Endpoint)

### 42. `POST /api/disputes/:id/evidence`
* **File Route & Controller:** `backend/src/routes/dispute.routes.js:17`, `backend/src/controllers/dispute.controller.js:90`
* **Autentikasi:** JWT Wajib (Pembeli atau Penjual transaksi terkait).
* **Validasi Input:** `note` opsional (maks 1.000 karakter), `fileIds` array UUID (maks 10 file per pihak).
* **Logika Bisnis:** Menambahkan bukti baru ke `dispute_evidences` selama status sengketa masih `OPEN` atau `UNDER_REVIEW`.
* **Status:** ✅ BERFUNGSI

---

### 43. `GET /api/disputes/:id`
* **File Route & Controller:** `backend/src/routes/dispute.routes.js:21`, `backend/src/controllers/dispute.controller.js:125`
* **Autentikasi:** JWT Wajib (Partisipan sengketa atau Admin).
* **Logika Bisnis:** Mengambil seluruh detail sengketa beserta daftar bukti yang diajukan kedua belah pihak.
* **Status:** ✅ BERFUNGSI

---

## 8. Grup 8: Kotak Masuk Notifikasi (4 Endpoint)

### 44. `GET /api/notifications`
* **File Route & Controller:** `backend/src/routes/notification.routes.js:19`, `backend/src/controllers/notification.controller.js:20`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Menampilkan daftar notifikasi milik pengguna terurut tanggal terbaru dengan paginasi kursor.
* **Status:** ✅ BERFUNGSI

---

### 45. `GET /api/notifications/unread-count`
* **File Route & Controller:** `backend/src/routes/notification.routes.js:22`, `backend/src/controllers/notification.controller.js:45`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Menghitung jumlah notifikasi yang belum dibaca (`readAt == null`) untuk menampilkan badge merah di UI.
* **Status:** ✅ BERFUNGSI

---

### 46. `POST /api/notifications/:id/read`
* **File Route & Controller:** `backend/src/routes/notification.routes.js:25`, `backend/src/controllers/notification.controller.js:60`
* **Autentikasi:** JWT Wajib (Hanya pemilik notifikasi).
* **Logika Bisnis:** Mengisi `readAt = new Date()` pada baris notifikasi spesifik.
* **Status:** ✅ BERFUNGSI

---

### 47. `POST /api/notifications/read-all`
* **File Route & Controller:** `backend/src/routes/notification.routes.js:28`, `backend/src/controllers/notification.controller.js:80`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Menandai seluruh notifikasi milik pengguna yang belum dibaca menjadi terbaca secara massal.
* **Status:** ✅ BERFUNGSI

---

## 9. Grup 9: Verifikasi Identitas Pengguna / KYC (2 Endpoint)

### 48. `POST /api/kyc`
* **File Route & Controller:** `backend/src/routes/kyc.routes.js:15`, `backend/src/controllers/kyc.controller.js:20`
* **Autentikasi:** JWT Wajib.
* **Validasi Input:** `fullName` string, `nik` 16 digit angka, `idFileId` UUID, `selfieFileId` UUID.
* **Logika Bisnis:**
  1. Memverifikasi bahwa user belum memiliki status KYC `PENDING` atau `APPROVED`.
  2. Mengenkripsi NIK 16-digit menggunakan AES-256-GCM (`nikEnc`).
  3. Menyimpan pengajuan ke `kyc_submissions` berstatus `PENDING`.
  4. Mengubah `User.kycStatus` menjadi `PENDING`.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 49. `GET /api/kyc/me`
* **File Route & Controller:** `backend/src/routes/kyc.routes.js:18`, `backend/src/controllers/kyc.controller.js:65`
* **Autentikasi:** JWT Wajib.
* **Logika Bisnis:** Mengambil riwayat pengajuan KYC pengguna terakhir dan alasan penolakan (jika ada).
* **Status:** ✅ BERFUNGSI

---

## 10. Grup 10: Webhook Pembayaran Masuk (1 Endpoint)

### 50. `POST /webhooks/payment/:provider` (& `/api/webhooks/payment/:provider`)
* **File Route & Controller:** `backend/src/routes/webhook.routes.js:13`, `backend/src/controllers/topup.controller.js:115`
* **Autentikasi:** Header Token Verifikasi Gateway (Xendit callback token).
* **Middleware Khusus:** Menggunakan `express.raw({ type: '*/*' })` agar payload asli tidak rusak sebelum verifikasi tanda tangan.
* **Logika Bisnis:**
  1. Memverifikasi keabsahan callback token mitra.
  2. Memeriksa tabel `webhook_events` untuk menjamin idempotensi (mencegah proses ganda).
  3. Mengubah status `PaymentIntent` menjadi `PAID`.
  4. Mengkredit saldo pengguna secara atomik dengan entri buku besar `TOPUP`.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

## 11. Grup 11: Observabilitas, Health & Metrik (3 Endpoint)

### 51. `GET /api/health` (& `/health`)
* **File Route & Controller:** `backend/src/app.js:85`
* **Autentikasi:** Publik tanpa token.
* **Logika Bisnis:** Liveness probe mengembalikan status HTTP 200 `{ status: "healthy" }`.
* **Status:** ✅ BERFUNGSI

---

### 52. `GET /api/health/ready` (& `/health/ready`)
* **File Route & Controller:** `backend/src/app.js:96`
* **Autentikasi:** Publik tanpa token.
* **Logika Bisnis:** Readiness probe menjalankan query `SELECT 1` ke PostgreSQL. Mengembalikan HTTP 200 jika DB sehat, atau HTTP 503 jika DB terputus.
* **Status:** ✅ BERFUNGSI

---

### 53. `GET /metrics` (& `/api/metrics`)
* **File Route & Controller:** `backend/src/routes/metrics.routes.js:11`
* **Autentikasi:** Token Wajib (`X-Metrics-Token` atau `Bearer <token>`).
* **Logika Bisnis:** Mengumpulkan metriks operasional (total transaksi, topup, withdrawal, sengketa, job failures, reconcile discrepancies, memory, uptime) dan mengekspornya dalam format teks Prometheus 0.0.4.
* **Status:** ✅ BERFUNGSI

---

## 12. Grup 12: Admin - Moderasi Penarikan Dana (3 Endpoint)

### 54. `GET /api/admin/withdrawals`
* **File Route & Controller:** `backend/src/routes/admin.withdrawal.routes.js:19`, `backend/src/controllers/admin.withdrawal.controller.js:20`
* **Autentikasi:** Khusus ADMIN (`authenticate`, `authorize('ADMIN')`).
* **Logika Bisnis:** Menampilkan daftar permohonan penarikan dana dengan filter status dan informasi rekening tujuan.
* **Status:** ✅ BERFUNGSI

---

### 55. `POST /api/admin/withdrawals/:id/approve`
* **File Route & Controller:** `backend/src/routes/admin.withdrawal.routes.js:25`, `backend/src/controllers/admin.withdrawal.controller.js:55`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:**
  1. Memvalidasi status permohonan `PENDING_REVIEW`.
  2. Memicu payout ke gateway perbankan.
  3. Mengubah status menjadi `APPROVED` / `PROCESSING`.
  4. Mencatat `AuditLog` administratif.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 56. `POST /api/admin/withdrawals/:id/reject`
* **File Route & Controller:** `backend/src/routes/admin.withdrawal.routes.js:37`, `backend/src/controllers/admin.withdrawal.controller.js:95`
* **Autentikasi:** Khusus ADMIN.
* **Validasi Input:** `reason` string (minimal 5 karakter).
* **Logika Bisnis:**
  1. Menandai penarikan menjadi `REJECTED`.
  2. Mengembalikan dana yang dicadangkan ke saldo pengguna melalui entri buku besar `ADJUSTMENT`.
  3. Mencatat `AuditLog`.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

## 13. Grup 13: Admin - Resolusi Sengketa Escrow (4 Endpoint)

### 57. `GET /api/admin/disputes`
* **File Route & Controller:** `backend/src/routes/admin.dispute.routes.js:23`, `backend/src/controllers/admin.dispute.controller.js:20`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Menampilkan seluruh sengketa aktif di platform dengan filter status (`OPEN`, `UNDER_REVIEW`, `RESOLVED_*`).
* **Status:** ✅ BERFUNGSI

---

### 58. `GET /api/admin/disputes/:id`
* **File Route & Controller:** `backend/src/routes/admin.dispute.routes.js:29`, `backend/src/controllers/admin.dispute.controller.js:50`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Mengambil berkas investigasi lengkap, profil pembeli/penjual, dan seluruh berkas bukti yang diajukan.
* **Status:** ✅ BERFUNGSI

---

### 59. `POST /api/admin/disputes/:id/review`
* **File Route & Controller:** `backend/src/routes/admin.dispute.routes.js:35`, `backend/src/controllers/admin.dispute.controller.js:80`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Mengubah status sengketa dari `OPEN` menjadi `UNDER_REVIEW` saat admin mulai memeriksa kasus.
* **Status:** ✅ BERFUNGSI

---

### 60. `POST /api/admin/disputes/:id/resolve`
* **File Route & Controller:** `backend/src/routes/admin.dispute.routes.js:41`, `backend/src/controllers/admin.dispute.controller.js:105`
* **Autentikasi:** Khusus ADMIN.
* **Validasi Input:** `decision` (`RESOLVED_BUYER` atau `RESOLVED_SELLER`), `resolutionNote` (minimal 10 karakter).
* **Logika Bisnis:**
  1. Memverifikasi status sengketa masih aktif.
  2. Jika `RESOLVED_BUYER`: Dana escrow dikembalikan 100% ke saldo pembeli (`refundEscrow`).
  3. Jika `RESOLVED_SELLER`: Dana bersih dilepaskan ke saldo penjual (`releaseEscrow`).
  4. Menandai sengketa selesai, mencatat ID admin penuntas, dan menyimpan `AuditLog`.
* **Database Transaction:** `prisma.$transaction` atomik.
* **Status:** ✅ BERFUNGSI

---

## 14. Grup 14: Admin - Moderasi KYC (4 Endpoint)

### 61. `GET /api/admin/kyc`
* **File Route & Controller:** `backend/src/routes/admin.kyc.routes.js:15`, `backend/src/controllers/admin.kyc.controller.js:20`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Menampilkan daftar pengajuan KYC pengguna dengan filter status.
* **Status:** ✅ BERFUNGSI

---

### 62. `GET /api/admin/kyc/:id`
* **File Route & Controller:** `backend/src/routes/admin.kyc.routes.js:18`, `backend/src/controllers/admin.kyc.controller.js:45`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Mengambil detail KYC: mendekripsi NIK dan menyamarkannya (`317101••••••0001`) serta menghasilkan URL bertanda tangan untuk foto KTP dan selfie.
* **Status:** ✅ BERFUNGSI

---

### 63. `POST /api/admin/kyc/:id/approve`
* **File Route & Controller:** `backend/src/routes/admin.kyc.routes.js:21`, `backend/src/controllers/admin.kyc.controller.js:75`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Menandai `KycSubmission.status = 'APPROVED'` dan `User.kycStatus = 'APPROVED'`. Mengirimkan notifikasi push ke pengguna dan mencatat `AuditLog`.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 64. `POST /api/admin/kyc/:id/reject`
* **File Route & Controller:** `backend/src/routes/admin.kyc.routes.js:24`, `backend/src/controllers/admin.kyc.controller.js:105`
* **Autentikasi:** Khusus ADMIN.
* **Validasi Input:** `reason` string minimal 5 karakter.
* **Logika Bisnis:** Menandai pengajuan `REJECTED`, menyimpan alasan penolakan, mengembalikan status user ke `REJECTED` agar dapat mengajukan ulang, dan mencatat `AuditLog`.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

## 15. Grup 15: Admin - Metrik & Analitik Platform (1 Endpoint)

### 65. `GET /api/admin/metrics`
* **File Route & Controller:** `backend/src/routes/admin.metric.routes.js:13`, `backend/src/controllers/admin.metric.controller.js:15`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Mengagregasi metrik platform: volume transaksi, total fee terkumpul, sengketa aktif, permohonan penarikan tertunda, dan tren volume 7 hari terakhir untuk grafik `fl_chart`.
* **Status:** ✅ BERFUNGSI

---

## 16. Grup 16: Admin - Pengaturan Platform (2 Endpoint)

### 66. `GET /api/admin/settings`
* **File Route & Controller:** `backend/src/routes/admin.setting.routes.js:13`, `backend/src/controllers/admin.setting.controller.js:15`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Menampilkan seluruh konfigurasi platform dari tabel `platform_settings`.
* **Status:** ✅ BERFUNGSI

---

### 67. `PUT /api/admin/settings`
* **File Route & Controller:** `backend/src/routes/admin.setting.routes.js:16`, `backend/src/controllers/admin.setting.controller.js:35`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Memperbarui pasangan kunci-nilai pengaturan (misal `fee_percent`, `maintenance_mode`), menginvalidasi cache memori seketika, dan mencatat `AuditLog`.
* **Status:** ✅ BERFUNGSI

---

## 17. Grup 17: Admin - Pemantauan Transaksi (1 Endpoint)

### 68. `GET /api/admin/transactions`
* **File Route & Controller:** `backend/src/routes/admin.transaction.routes.js:13`, `backend/src/controllers/admin.transaction.controller.js:15`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Menampilkan seluruh transaksi platform lintas pengguna dengan filter status, kursor paginasi, dan relasi profil buyer/seller.
* **Status:** ✅ BERFUNGSI

---

## 18. Grup 18: Admin - Manajemen & Pemblokiran Pengguna (4 Endpoint)

### 69. `GET /api/admin/users`
* **File Route & Controller:** `backend/src/routes/admin.user.routes.js:15`, `backend/src/controllers/admin.user.controller.js:20`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Menampilkan daftar pengguna terdaftar dengan fitur pencarian nama/email dan filter status keaktifan.
* **Status:** ✅ BERFUNGSI

---

### 70. `GET /api/admin/users/:id`
* **File Route & Controller:** `backend/src/routes/admin.user.routes.js:18`, `backend/src/controllers/admin.user.controller.js:50`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Mengambil rincian profil pengguna, saldo dompet, status KYC, dan statistik jumlah transaksinya.
* **Status:** ✅ BERFUNGSI

---

### 71. `POST /api/admin/users/:id/ban`
* **File Route & Controller:** `backend/src/routes/admin.user.routes.js:26`, `backend/src/controllers/admin.user.controller.js:80`
* **Autentikasi:** Khusus ADMIN.
* **Validasi Input:** `reason` string 3–500 karakter.
* **Logika Bisnis:**
  1. Menyetel `User.isActive = false`.
  2. Mencabut seluruh refresh token aktif pengguna terkait.
  3. Mencatat alasan pemblokiran pada `AuditLog`.
* **Database Transaction:** `prisma.$transaction`.
* **Status:** ✅ BERFUNGSI

---

### 72. `POST /api/admin/users/:id/unban`
* **File Route & Controller:** `backend/src/routes/admin.user.routes.js:41`, `backend/src/controllers/admin.user.controller.js:115`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Mengaktifkan kembali akun pengguna (`isActive = true`) dan mencatat `AuditLog`.
* **Status:** ✅ BERFUNGSI

---

## 19. Grup 19: Admin - Jejak Audit Sistem (1 Endpoint)

### 73. `GET /api/admin/audit-logs`
* **File Route & Controller:** `backend/src/routes/admin.audit.routes.js:13`, `backend/src/controllers/admin.audit.controller.js:15`
* **Autentikasi:** Khusus ADMIN.
* **Logika Bisnis:** Menampilkan log peristiwa administratif (`AuditLog`) terpaginasi kursor: mencatat aktor, aksi, tipe target, snapshot data sebelum/sesudah, dan alamat IP pemanggil.
* **Status:** ✅ BERFUNGSI

---
*Katalog 73 Endpoint ini diverifikasi langsung dari kode sumber backend Rekber per 22 November 2026.*
