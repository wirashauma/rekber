# LAPORAN PENGUJIAN AKHIR: E2E, KEAMANAN, DAN BEBAN (PROMPT 19)

**Tanggal Pengujian:** 22 November 2026  
**Aplikasi:** Rekber (Escrow) Platform (Backend Node.js/Express + Mobile Flutter)  
**Lingkungan:** Node.js v22.20.0, Express 5.2.1, Prisma 7.8.0, PostgreSQL 16 (Local), Flutter 3.38+  

---

## 1. RINGKASAN EKSEKUTIF

Pengujian komprehensif Prompt 19 telah dilaksanakan yang mencakup empat pilar pengujian:
1. **Pengujian End-to-End (E2E) HTTP:** 8 skenario siklus hidup kritis dari registrasi hingga rekonsiliasi nol selisih.
2. **Pengujian Keamanan Otomatis:** Sapu IDOR pada seluruh 26 endpoint ber-`:id`, proteksi otorisasi, ketahanan injeksi, proteksi mass assignment, audit header keamanan Helmet, CORS produksi, rate limiting, kebocoran data sensitif, dan serangan JWT.
3. **Pengujian Beban & Konkurensi Uang:** Simulasi 50 Pengguna Virtual (VU) paralel (~2.000 request campuran) dan konkurensi ekstrem 100 VU simultan pada 1 transaksi untuk menguji compare-and-swap (CAS) dan pencegahan double-spending.
4. **Audit Dependensi & Pemindaian Rahasia:** Analisis `npm audit --omit=dev`, `flutter pub outdated`, dan pemindaian regex rahasia (secret scan) di seluruh repositori.

### Status Pengujian Utama:
* **E2E & Security Test Suite:** 22/22 pengujian **LULUS (100%)**, diverifikasi non-flaky melalui pengujian berulang 3x berturut-turut.
* **Performa Beban 50 VU:** **p95 = 222.86 ms** (Target awal: < 500 ms) | **Error Rate = 0.00%** (Target: < 1.0%) | **Throughput = 463.6 RPS**.
* **Konkurensi Uang 100 VU:** Tepat 1 pemenang atomic lock (HTTP 200), 99 permintaan ditolak aman oleh CAS (HTTP 409), 0 server crash (HTTP 500), 1 entri ledger `ESCROW_HOLD`, **Rekonsiliasi = 100% konsisten (0 selisih saldo)**.
* **Secret Scan:** Tidak ditemukan kebocoran kredensial produksi, private key, atau live API key di kode sumber.

---

## 2. HASIL PENGUJIAN END-TO-END (E2E)

File implementasi: `backend/tests/e2e/e2e_escrow_flow.test.js`

| Skenario | Deskripsi Alur Pengujian | Status | Verifikasi Integritas |
|---|---|---|---|
| **(a) Jalur Sukses Lengkap** | 2 user daftar $\rightarrow$ top-up via webhook fake $\rightarrow$ buat transaksi $\rightarrow$ bayar $\rightarrow$ kirim bukti pengiriman $\rightarrow$ konfirmasi buyer $\rightarrow$ KYC seller disetujui admin $\rightarrow$ tarik dana $\rightarrow$ admin approve $\rightarrow$ webhook payout $\rightarrow$ audit rekonsiliasi | **LULUS** | Saldo seller bertambah Rp 495.000, penarikan Rp 400.000 selesai, audit `reconcile()` 0 user discrepancies, 0 escrow discrepancies. |
| **(b) Auto-Release Worker** | Transaksi `SHIPPED` dengan `autoReleaseAt` lampau diproses oleh `runAutoRelease()` | **LULUS** | Transaksi otomatis `COMPLETED`, dana Rp 200.000 dilepas ke penjual, `heldAmount = 0`. |
| **(c) Sengketa $\rightarrow$ Admin Refund** | Transaksi `PAID` $\rightarrow$ Buyer dispute $\rightarrow$ Admin putuskan `REFUND_TO_BUYER` | **LULUS** | Transaksi `REFUNDED`, dana escrow dikembalikan 100% ke saldo pembeli, `heldAmount = 0`. |
| **(d) Sengketa $\rightarrow$ Admin Release** | Transaksi `PAID` $\rightarrow$ Buyer dispute $\rightarrow$ Admin putuskan `RELEASE_TO_SELLER` | **LULUS** | Transaksi `COMPLETED`, dana escrow diteruskan ke penjual, `heldAmount = 0`. |
| **(e) PENDING Kedaluwarsa** | Transaksi `PENDING` melewati batas `expiresAt` diproses oleh `runExpirePending()` | **LULUS** | Status transaksi otomatis transisi ke `CANCELLED`. |
| **(f) Webhook Top-Up Duplikat** | Webhook top-up dipanggil 2x dengan `eventId` yang sama persis | **LULUS** | Request ke-2 mengembalikan 200 idempotensi, saldo tidak berlipat ganda, entri ledger `TOPUP` tepat 1. |
| **(g) Rotasi & Token Reuse** | Refresh token lama dipakai kembali setelah dirotasi | **LULUS** | Mengembalikan 401 `TOKEN_THEFT_DETECTED`, seluruh sesi pengguna langsung dicabut otomatis. |
| **(h) User Di-Ban saat Aktif** | Buyer di-ban admin saat transaksi berstatus `PAID` | **LULUS** | Sesi buyer terputus (403 `ACCOUNT_INACTIVE`), dana escrow tetap aman terkunci, tidak ada kebocoran saldo. |

---

## 3. HASIL PENGUJIAN KEAMANAN OTOMATIS

File implementasi: `backend/tests/security/security_automated.test.js`

### 3.1. Sapu IDOR (Insecure Direct Object Reference)
Daftar seluruh 26 endpoint ber-`:id` diuji secara sistematis menggunakan token penyerang (*unauthorized attacker*). Seluruh endpoint terbukti **menolak penyerang dengan kode status 403 atau 404**:
1. `GET /api/transactions/:id` $\rightarrow$ 403 Forbidden
2. `POST /api/transactions/:id/shipment` $\rightarrow$ 403 Forbidden
3. `POST /api/transactions/:id/dispute` $\rightarrow$ 403 Forbidden
4. `GET /api/transactions/:id/dispute` $\rightarrow$ 403 Forbidden
5. `PUT /api/transactions/:id/status` $\rightarrow$ 403 Forbidden
6. `GET /api/transactions/:id/messages` $\rightarrow$ 403 Forbidden
7. `POST /api/transactions/:id/messages` $\rightarrow$ 403 Forbidden
8. `POST /api/transactions/:id/messages/read` $\rightarrow$ 403 Forbidden
9. `GET /api/wallet/topups/:id` $\rightarrow$ 404 Not Found
10. `POST /api/wallet/withdrawals/:id/cancel` $\rightarrow$ 404 Not Found
11. `DELETE /api/bank-accounts/:id` $\rightarrow$ 404 Not Found
12. `GET /api/files/:id/url` $\rightarrow$ 403 Forbidden
13. `GET /api/disputes/:id` $\rightarrow$ 403 Forbidden
14. `POST /api/disputes/:id/evidence` $\rightarrow$ 403 Forbidden
15. `POST /api/notifications/:id/read` $\rightarrow$ 404 Not Found
16. `POST /api/admin/withdrawals/:id/approve` $\rightarrow$ 403 Forbidden
17. `POST /api/admin/withdrawals/:id/reject` $\rightarrow$ 403 Forbidden
18. `GET /api/admin/disputes/:id` $\rightarrow$ 403 Forbidden
19. `POST /api/admin/disputes/:id/review` $\rightarrow$ 403 Forbidden
20. `POST /api/admin/disputes/:id/resolve` $\rightarrow$ 403 Forbidden
21. `GET /api/admin/kyc/:id` $\rightarrow$ 403 Forbidden
22. `POST /api/admin/kyc/:id/approve` $\rightarrow$ 403 Forbidden
23. `POST /api/admin/kyc/:id/reject` $\rightarrow$ 403 Forbidden
24. `GET /api/admin/users/:id` $\rightarrow$ 403 Forbidden
25. `POST /api/admin/users/:id/ban` $\rightarrow$ 403 Forbidden
26. `POST /api/admin/users/:id/unban` $\rightarrow$ 403 Forbidden

### 3.2. Aspek Keamanan Lainnya
* **Autentikasi:** Seluruh endpoint privat menolak request tanpa token dengan status 401 `UNAUTHORIZED`.
* **Otorisasi Role:** Seluruh endpoint `/api/admin/*` menolak regular USER dengan status 403 `FORBIDDEN`.
* **Mass Assignment:** Upaya menyusupkan parameter `role: 'ADMIN'`, `balance: 10000000`, `isActive: true`, `kycStatus: 'APPROVED'` pada register, profile update, dan transaksi berhasil dinetralisir (diabaikan dan disimpan default).
* **Ketahanan Injeksi:** Payload SQL Injection (`' OR 1=1 --`, `UNION SELECT`, `; DROP TABLE`) pada parameter query ditangani dengan aman (200/400/422), tanpa menyebabkan database error atau server crash 500.
* **Header Keamanan Helmet:** Header `X-Content-Type-Options: nosniff`, `X-Frame-Options`, `X-DNS-Prefetch-Control: off` aktif pada seluruh respons.
* **CORS Produksi:** Pada mode produksi, request dengan header `Origin` di luar daftar putih (`CORS_ORIGIN`) ditolak.
* **Rate Limiting:** Frekuensi request melebihi ambang batas menghasilkan status 429 `TOO_MANY_REQUESTS`.
* **Anti-Kebocoran Stack Trace:** Respons error 400, 401, 403, 404, 500 tidak memuat stack trace (`stack`) maupun path file internal filesystem.
* **Pemindaian Data Sensitif:** Seluruh respons JSON diverifikasi bersih dari `password`, `passwordHash`, `tokenHash`, NIK 16-digit polos, dan nomor rekening polos (nomor rekening disamarkan `••••••••1234`).
* **Serangan JWT:**
  * `alg: none` (token tanpa signature) $\rightarrow$ Ditolak (401 `INVALID_TOKEN`)
  * Tampered Signature $\rightarrow$ Ditolak (401 `INVALID_TOKEN`)
  * Token Expired $\rightarrow$ Ditolak (401 `TOKEN_EXPIRED`)
  * User Deactivated (`isActive: false`) $\rightarrow$ Ditolak (403 `ACCOUNT_INACTIVE`)

---

## 4. HASIL PENGUJIAN BEBAN DAN KONKURENSI UANG

File implementasi:
* Script k6: `backend/loadtest/load_test.js` & `backend/loadtest/concurrency_money_test.js`
* Runner tolok ukur: `backend/loadtest/run_benchmarks.js`

### 4.1. Skenario Beban: 50 Pengguna Virtual (Mixed Load Test)
Simulasi campuran autentikasi, pengecekan dompet, melihat daftar transaksi, detail transaksi, dan pembuatan transaksi escrow:

| Metrik | Target Awal | Nilai Sebenarnya | Status |
|---|---|---|---|
| **Total Permintaan** | - | **2.000 request** | Selesai |
| **Permintaan Berhasil (2xx)** | - | **2.000 (100%)** | Optimal |
| **Permintaan Gagal** | - | **0 (0.00%)** | Sempurna |
| **Error Rate** | < 1.0% | **0.00%** | **MEMENUHI TARGET** |
| **Throughput (RPS)** | - | **463.6 req/detik** | Sangat Tinggi |
| **Latensi Minimal** | - | **3.56 ms** | Cepat |
| **Latensi Rata-rata** | - | **106.15 ms** | Stabil |
| **Latensi p50 (Median)** | - | **71.47 ms** | Sangat Cepat |
| **Latensi p90** | - | **205.72 ms** | Baik |
| **Latensi p95** | < 500 ms | **222.86 ms** | **MEMENUHI TARGET** ($> 2\times$ lebih cepat) |
| **Latensi p99** | - | **348.11 ms** | Sangat Baik |

### 4.2. Skenario Konkurensi Uang: 100 VU Simultan pada 1 Transaksi
100 worker virtual menembak request pembayaran (`PUT /api/transactions/:id/status` dengan `{ status: 'PAID' }`) secara simultan pada milidetik yang sama:

| Parameter Uji | Nilai Ekspektasi | Nilai Sebenarnya | Analisis |
|---|---|---|---|
| **Pemenang Atomic Lock (HTTP 200)** | Tepat 1 | **1** | CAS PostgreSQL berhasil mengunci baris transaksi |
| **Ditolak Aman (HTTP 409 Conflict)** | 99 | **99** | Seluruh 99 request yang kalah balap ditolak tanpa efek samping |
| **Crash Server (HTTP 500)** | 0 | **0** | Tidak terjadi deadlock error atau unhandled exception |
| **Status Akhir Transaksi** | `PAID` | `PAID` | Status konsisten |
| **Dana Terkunci Escrow** | Rp 306.000 | **Rp 306.000** | Pokok Rp 300.000 + Buyer Fee 2% (Rp 6.000) |
| **Entri Ledger `ESCROW_HOLD`** | Tepat 1 | **1** | Tidak ada double-spending atau pemotongan ganda |
| **Audit Rekonsiliasi Finansial** | 100% Konsisten | **0 Selisih** | Saldo user dan escrow klop tanpa selisih 1 Rupiah pun |

---

## 5. AUDIT DEPENDENSI DAN PEMINDAIAN RAHASIA

### 5.1. Backend (`npm audit --omit=dev`)
* **Patch Diterapkan:** Dependensi `proxy-addr` berhasil diperbarui dari `2.0.7` ke `2.0.8` (kerentanan kritis teratasi).
* **Kerentanan Tersisa:** 11 kerentanan pada dependensi sekunder/transitif (3 moderate, 8 high):
  * `@hono/node-server`, `valibot`, `deepmerge-ts`, `effect`, `mysql2`: Dependensi internal paket Prisma CLI/dev (`@prisma/dev`, `@prisma/config`). Tidak terekspos di runtime Express produksi API.
  * `body-parser` (2.0.0-2.3.0) & `fast-uri`: Transitif dari Express 5 dan validator.
  * **Catatan:** Pembaruan paksa (`npm audit fix --force`) berpotensi menyebabkan *breaking change* pada Express 5 / Prisma 7, sehingga dicatat sebagai risiko tersisa untuk pembaruan terjadwal.

### 5.2. Mobile (`flutter pub outdated`)
* Ditemukan 61 dependensi terkunci pada `pubspec.lock` dan 36 dependensi dibatasi oleh constraint versi `pubspec.yaml`.
* Paket `flutter_secure_storage_macos` dan `js` telah berstatus *discontinued* oleh upstream maintainer. Direkomendasikan migrasi ke versi modern pada siklus rilis berikutnya.

### 5.3. Pemindaian Rahasia (Secret Scan)
Script scanner: `backend/scripts/scan_secrets.js`
* Hasil scan regex menyeluruh pada seluruh direktori proyek:
  * AWS Access Key / Secret Key: **0 temuan**
  * RSA / OpenSSH Private Key: **0 temuan**
  * Firebase Service Account Key: **0 temuan**
  * Xendit Live API Key: **0 temuan**
  * Hardcoded Password di kode produksi: **0 temuan**
  * Temuan terisolasi: URL lokal database testing di `backend/.env.test` (`postgres:1@localhost:5432/rekber_test`).

---

## 6. DAFTAR BUG & ANOMALI YANG DITEMUKAN

Sesuai aturan Prompt 19, bug yang ditemukan **dicatat dan tidak diperbaiki**, kecuali celah keamanan kecil ($\le 10$ baris):

### 1. [SEDANG] Postgres Advisory Lock pada Single Process dengan Connection Pooling
* **Komponen:** `backend/src/worker.js` (`withAdvisoryLock`)
* **Deskripsi:** `withAdvisoryLock` menggunakan `SELECT pg_try_advisory_lock(${lockId})` melalui query mentah Prisma (`prisma.$queryRawUnsafe`). Karena Prisma menggunakan connection pool tanpa mengunci koneksi ke satu thread pemanggil, dua pemanggilan paralel dalam proses yang sama berpotensi menggunakan koneksi yang sama, di mana lock PostgreSQL bersifat re-entrant (kedua pemanggilan mengembalikan `true`).
* **Dampak:** Pada pengujian unit konkurensi lokal, dua pemanggilan dalam proses yang sama bisa lolos. Di lingkungan produksi dengan beberapa instance/container terpisah (koneksi DB berbeda), advisory lock berfungsi normal.
* **Rekomendasi:** Gunakan koneksi Postgres yang didedikasikan atau gunakan `pg_try_advisory_xact_lock` di dalam blok transaksi terisolasi.

### 2. [SEDANG] Golden Tests Mobile Gagal karena Ketergantungan Unduhan Font
* **Komponen:** `mobile/test/goldens/golden_screens_test.dart`
* **Deskripsi:** Uji golden modal sengketa dan ruang chat gagal saat dijalankan headless tanpa koneksi internet karena package `google_fonts` mencoba mengunduh file TTF font dari URL eksternal (`fonts.gstatic.com`). Selain itu, ukuran viewport master golden (440x932) berbeda dengan rendering default (390x844).
* **Dampak:** 208 pengujian unit, widget, bloc, dan repository lulus sempurna; namun pengujian visual golden memerlukan konfigurasi `GoogleFonts.config.allowRuntimeFetching = false` dan mock font bundle offline.

### 3. [RENDAH] Paket macOS Secure Storage Telah Discontinued
* **Komponen:** `mobile/pubspec.yaml` (`flutter_secure_storage`)
* **Deskripsi:** Dependensi transitif `flutter_secure_storage_macos` telah ditandai discontinued oleh komunitas pub.dev dan dialihkan ke implementasi platform interface universal.
* **Dampak:** Tidak mempengaruhi build Android maupun iOS, namun perlu diupdate pada migrasi versi Flutter mendatang.

---

## 7. REKOMENDASI DAN RISIKO TERSISA (RESIDUAL RISKS)

1. **Pemisahan Connection Worker:** Konfigurasikan worker cron job pada instance terpisah dengan `DATABASE_URL` yang memiliki parameter `connection_limit=1` atau gunakan Redis Redlock jika infrastruktur mendukung.
2. **Mocking Font Lokal untuk Golden Tests:** Tambahkan bundel font TTF lokal pada folder `assets/fonts/` dan aktifkan `GoogleFonts.config.allowRuntimeFetching = false` di file setup test widget mobile.
3. **Pembaruan Bertahap Dependensi:** Lakukan pembaruan minor terjadwal untuk paket `@prisma/client`, `body-parser`, dan `flutter_secure_storage`.
4. **WAF (Web Application Firewall):** Untuk deployment produksi, tempatkan Cloudflare atau AWS WAF di depan API untuk perlindungan layer 7 terhadap serangan DDoS dan brute-force.

---
*Laporan ini disusun secara otomatis oleh sistem penjaminan mutu Rekber Platform.*
