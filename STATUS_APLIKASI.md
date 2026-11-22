# LAPORAN AUDIT TEKNIS INDEPENDEN: APLIKASI REKBER (ESCROW PLATFORM)

> **Dokumen Audit Teknis & Status Kesiapan Aplikasi**  
> **Tanggal Audit:** 22 November 2026  
> **Auditor:** Senior Technical Auditor & Software Architect  
> **Target Proyek:** Rekber (Automated Escrow Platform - Backend Express/Prisma + Mobile Flutter)  
> **Tipe Dokumen:** Laporan Audit Komprehensif (*Single Source of Truth*)  
> **Pembagian Dokumen:**
> - **`STATUS_APLIKASI.md`** (Dokumen Utama): Bagian 1–5 dan Bagian 7–15 (Ringkasan Eksekutif, Struktur Proyek, Tech Stack, Environment, Skema Database Lengkap, Logika Escrow, Keamanan, Inventaris Mobile, Kesenjangan, Pengujian, Daftar Masalah, dan Evaluasi).
> - **`STATUS_APLIKASI_PART2.md`** (Katalog Detail Endpoint): Bagian 6 (Rincian mendalam 73 endpoint backend: method, path, validator, controller, request/response, logika langkah demi langkah, dan kepemilikan/transaksi DB).

---

## DAFTAR ISI
1. [Ringkasan Eksekutif](#1-ringkasan-eksekutif)
2. [Struktur Proyek](#2-struktur-proyek)
3. [Tech Stack dan Dependensi](#3-tech-stack-dan-dependensi)
4. [Environment dan Cara Menjalankan](#4-environment-dan-cara-menjalankan)
5. [Database](#5-database)
6. [Backend: Detail Per Endpoint (Ringkasan & Indeks)](#6-backend-detail-per-endpoint-ringkasan--indeks)
7. [Logika Inti Escrow](#7-logika-inti-escrow)
8. [Autentikasi dan Keamanan](#8-autentikasi-dan-keamanan)
9. [Mobile: Inventaris Halaman](#9-mobile-inventaris-halaman)
10. [Mobile: Arsitektur dan Integrasi](#10-mobile-arsitektur-dan-integrasi)
11. [Kesenjangan Backend ↔ Mobile](#11-kesenjangan-backend--mobile)
12. [Kualitas Kode dan Testing](#12-kualitas-kode-dan-testing)
13. [Daftar Masalah Diketahui](#13-daftar-masalah-diketahui)
14. [Pemeriksaan Kebutuhan Escrow](#14-pemeriksaan-kebutuhan-escrow)
15. [Pertanyaan Terbuka](#15-pertanyaan-terbuka)

---

# 1. Ringkasan Eksekutif

### Tujuan Aplikasi
Rekber adalah platform rekening bersama (*automated escrow platform*) yang dirancang khusus untuk mengamankan transaksi daring antara pembeli (*buyer*) dan penjual (*seller*) di Indonesia, mencakup barang fisik maupun produk digital berisiko tinggi (akun game, lisensi perangkat lunak, dan jasa digital). Sistem bertindak sebagai pihak ketiga tepercaya (*trusted escrow middleman*) yang menahan dana pembayaran pembeli secara aman pada akun perantara pool terisolasi hingga barang/jasa diverifikasi telah diterima sesuai deskripsi, sebelum dana dilepaskan ke saldo penjual atau dikembalikan kepada pembeli jika terjadi pembatalan atau sengketa.

### Perkiraan Persentase Kelengkapan
* **Backend (Node.js + Express 5 + Prisma 7 + PostgreSQL 16): 98%**  
  *Alasan:* Seluruh 73 endpoint API telah diimplementasikan lengkap dan terlindungi autentikasi/validasi ketat. Sistem buku besar akuntansi ganda (*double-entry ledger*), integrasi gateway pembayaran (Xendit QRIS & Virtual Account serta penyedia Fake untuk pengujian), penanganan webhook idempotent, manajemen file aset S3/Lokal bertanda tangan HMAC, resolusi sengketa multi-pihak, chat real-time Socket.IO, notifikasi FCM, verifikasi KYC dengan enkripsi NIK AES-256-GCM, audit logging administratif, platform settings dengan cache, proteksi graceful shutdown, dan observabilitas Prometheus/Sentry telah selesai 100%.
* **Mobile (Flutter 3.38+ Clean Architecture & Neo-Brutalist UI): 95%**  
  *Alasan:* Sebanyak 31 dari 32 layar aplikasi telah terhubung penuh (*end-to-end*) ke API backend asli menggunakan BLoC/Cubit, Dartz (`Either<Failure, T>`), dan `get_it`. Layar transaksi, sengketa, chat Socket.IO, dompet, mutasi ledger, penarikan dana, KYC, dan 9 modul panel admin berfungsi penuh terhadap backend. Hanya layar `AiAssistantScreen` yang masih berjalan sebagai simulator lokal (`🧪 MOCK/DUMMY`) dan `LegalScreen` yang masih berstatus draft teknis ber-banner penafian hukum (`⚠️ PARSIAL`).
* **Integrasi End-to-End: 95%**  
  *Alasan:* Alur siklus hidup lengkap (pendaftaran akun, top-up saldo, pembentukan transaksi room rekber, pembayaran escrow, pengunggahan bukti resi, konfirmasi penerimaan, rilis otomatis oleh worker cron, pengajuan sengketa, resolusi admin, penarikan dana payout, hingga audit rekonsiliasi harian dengan 0 selisih saldo) telah terverifikasi sukses secara otomatis melalui 22 skenario E2E HTTP dan 194 pengujian unit/fitur mobile.

### 5 Temuan Paling Penting
1. **Integritas Finansial Konsisten 100% (*Zero Balance Discrepancy*) [KEKUATAN UTAMA]**:  
   Setiap mutasi dana saldo pengguna dan escrow diikat oleh pencatatan berpasangan (*double-entry*) pada model `LedgerEntry` dengan kunci idempotensi unik (`idempotencyKey`). Mutasi saldo dieksekusi secara atomik menggunakan pola Compare-and-Swap (CAS) bersyarat pada `backend/src/services/ledger.service.js:132`. Simulasi konkurensi ekstrem 100 pengguna virtual simultan terbukti menghasilkan tepat 1 transaksi pemenang dan 0 selisih saldo pada audit harian (`reconcileDaily`).
2. **Siklus Sengketa & Moderasi Admin Komprehensif [KEKUATAN UTAMA]**:  
   Fitur sengketa (`Dispute`) memungkinkan pembeli mengajukan komplain saat status transaksi `PAID` atau `SHIPPED` dengan menyertakan bukti pendukung (`DisputeEvidence`). Admin memiliki wewenang menginvestigasi sengketa, meninjau riwayat pesan chat secara *read-only*, dan memutuskan pelepasan dana ke penjual (`RESOLVED_SELLER`) atau pengembalian dana penuh ke pembeli (`RESOLVED_BUYER`) dalam satu transaksi database atomik (`backend/src/services/dispute.service.js:154`).
3. **Komunikasi Real-time & Push Notification Terintegrasi [KEKUATAN UTAMA]**:  
   Ruang obrolan transaksi didukung oleh Socket.IO pada server HTTP yang sama (`backend/src/socket/index.js`), terlindungi handshake JWT, pembatasan laju pesan (20 pesan/menit), serta penyimpanan persisten `ChatMessage` dan `ChatReadState`. Setiap peristiwa kritis (transaksi dibayar, barang dikirim, sengketa diajukan, status KYC) secara otomatis memicu pesan sistem dan notifikasi push FCM (`backend/src/notifications/events.js`).
4. **Keamanan Data Pribadi & Kepatuhan KYC [KEKUATAN UTAMA]**:  
   Identitas kependudukan NIK 16-digit dienkripsi secara simetris menggunakan algoritma AES-256-GCM (`nikEnc`) pada `backend/src/utils/encryption.js:32`. Akses file KTP dan swafoto dibatasi oleh kebijakan akses ketat (`fileAccessPolicies`) yang hanya mengizinkan pemilik dokumen dan admin platform. Penarikan dana saldo diwajibkan melewati persetujuan KYC aktif (`kycStatus === 'APPROVED'`).
5. **Kesiapan Dokumen Legal & Asisten AI [CATATAN RESIDUAL]**:  
   Teks Syarat & Ketentuan serta Kebijakan Privasi pada `LegalScreen` (`mobile/lib/features/settings/presentation/pages/legal_screen.dart:63`) masih merupakan draf teknis awal ber-banner penafian (*disclaimer*) yang memerlukan peninjauan konsultan hukum berlisensi sebelum rilis toko aplikasi. Layar `AiAssistantScreen` masih menggunakan respon teks tiruan hardcoded.

---

# 2. Struktur Proyek

### Pohon Direktori Backend (Level 2-3)
```text
backend/
├── Dockerfile                 # Multi-stage container runner (unprivileged user nodejs)
├── .dockerignore              # Ignore rules untuk build image Docker
├── package.json               # Dependensi npm & skrip operasional backend
├── package-lock.json          # Lockfile dependensi backend
├── prisma.config.ts           # Konfigurasi Prisma v7 datasource & migrations
├── eslint.config.js           # Konfigurasi flat ESLint v10
├── loadtest/                  # Skrip uji beban k6 (50 VU mixed & 100 VU CAS concurrency)
│   ├── load_test.js
│   ├── concurrency_money_test.js
│   └── run_benchmarks.js
├── prisma/
│   ├── schema.prisma          # Skema model Prisma ORM (16 model, 11 enum)
│   ├── seed.js                # Seeding admin, testing accounts, bank codes, settings
│   └── migrations/            # 10 direktori migrasi PostgreSQL terurut
├── scripts/
│   ├── create-admin.js        # Utilitas CLI pembuatan akun administrator
│   ├── reconcile.js           # Skrip audit rekonsiliasi finansial mandiri
│   ├── scan_secrets.js        # Pemindai regex kebocoran rahasia & kredensial
│   ├── verify-chat-flow.js    # Verifikator alur chat Socket.IO
│   ├── verify-dispute-flow.js # Verifikator alur sengketa & resolusi admin
│   └── verify-worker-flow.js  # Verifikator alur cron job worker
├── src/
│   ├── app.js                 # Setup Express, Helmet, CORS, Rate Limit, Health, Routes
│   ├── server.js              # Entrypoint HTTP server, Socket.IO, dan Graceful Shutdown
│   ├── worker.js              # Scheduler background cron dengan advisory lock PostgreSQL
│   ├── config/                # Validasi env (fail-fast), Prisma Client, logger Pino, Sentry
│   ├── controllers/           # 18 controller HTTP (auth, tx, wallet, dispute, kyc, admin, dll.)
│   ├── middlewares/           # Auth JWT, rate limiters, upload multer/sharp, maintenance mode
│   ├── notifications/         # Pemetaan event bisnis ke notifikasi bahasa Indonesia
│   ├── providers/             # Payment (Xendit/Fake), Storage (S3/Local), FCM Push, Mail
│   ├── routes/                # 20 file rute HTTP modular
│   ├── services/              # Logika bisnis inti (escrow, ledger, topup, dispute, audit, dll.)
│   ├── socket/                # Handler WebSocket Socket.IO real-time chat
│   ├── utils/                 # Enkripsi AES-256-GCM, BigInt money helpers
│   └── validators/            # Aturan validasi express-validator per modul
└── tests/                     # 24 suite pengujian otomatis (unit, finance, integration, e2e, security)
```

### Pohon Direktori Mobile (Level 2-3)
```text
mobile/
├── pubspec.yaml               # Dependensi Flutter & deklarasi aset
├── pubspec.lock               # Lockfile dependensi Flutter
├── android/                   # Konfigurasi Android, key.properties.example, manifest
├── lib/
│   ├── main.dart              # Entrypoint Flutter, Firebase, Sentry, & orientasi layar
│   ├── app.dart               # Root MaterialApp, MultiBlocProvider, & GoRouter instance
│   ├── injection_container.dart # Service Locator (GetIt) registrasi BLoC, Cubit, Repositories
│   ├── config/
│   │   └── routes/            # AppRouter (GoRouter dengan pure auth redirect guard)
│   ├── core/
│   │   ├── constants/         # AppColors, ApiConstants
│   │   ├── errors/            # Failure hierarchy (ServerFailure, CacheFailure, NetworkFailure)
│   │   ├── services/          # ApiService (HTTP + auto refresh-token), SocketService, NotificationService
│   │   ├── theme/             # Styling tema Neo-Brutalist & tipografi Space Grotesk
│   │   ├── utils/             # CurrencyFormatter (IDR), DateFormatter (WIB)
│   │   └── widgets/           # BrutalistButton, BrutalistCard, BrutalSkeleton, StatusBadge
│   └── features/
│       ├── admin/             # Presentation (Dashboard, Dispute, KYC, Settings, Users, Withdrawals), Cubit, Repo
│       ├── auth/              # BLoC, Model, Entity, Repo, Pages (Login, Register, Forgot/Reset)
│       ├── chat/              # ChatBloc, ChatRoomPage, AiAssistantScreen, Repository, Entity
│       ├── dispute/           # DisputeCubit, DisputeDetailPage, Form, Repository, Entity
│       ├── home/              # HomePage, NotificationPage, MainWrapper (BottomNav)
│       ├── settings/          # KycCubit, Screens (EditProfile, Kyc, Security, Legal, HelpCenter)
│       ├── transaction/       # TransactionCubit, Pages (Detail, BuatRoom, InputKode, Kalkulator, Riwayat)
│       └── wallet/            # WalletCubit, Pages (TopUp, DetailPembayaran, TarikDana, Mutasi)
└── test/                      # 33 suite pengujian Flutter (unit, widget, cubit, repo, goldens, e2e)
```

### Jumlah File dan Estimasi Baris Kode
| Komponen | Jumlah File | Jumlah Baris Kode | Keterangan |
| :--- | :--- | :--- | :--- |
| **Backend Source** (`backend/src/`) | 102 file JS | 10.862 baris | Seluruh logika aplikasi Express, services, controllers, middlewares |
| **Backend Tests** (`backend/tests/`) | 24 file JS | ~4.500 baris | Uji unit, finance integrity, integration, e2e, dan automated security |
| **Backend Scripts & Config** | 12 file | ~1.600 baris | Prisma schema/migrations, seed, k6 load tests, scanner |
| **Mobile Source** (`mobile/lib/`) | 107 file Dart | 19.508 baris | Seluruh kode Flutter Clean Architecture (data, domain, presentation) |
| **Mobile Tests** (`mobile/test/`) | 33 file Dart | ~6.200 baris | Uji cubit, bloc, repository, route guard, goldens, dan e2e mock |
| **Total Proyek** | **278 file** | **~42.670 baris** | Tidak menghitung `node_modules`, `.dart_tool`, dan build artifacts |

### Status Git
* **Branch aktif:** `main` (commit head: `e347350`).
* **10 Commit Terakhir:**
  1. `e347350` test: add end-to-end verification script for dispute and resolution flow
  2. `53aa3d8` feat: initialize backend service with core architecture, routes, and test suite
  3. `498bb00` feat: initialize backend service structure with routes, controllers, and tests
  4. `ca2cfc4` feat: initialize backend project structure with core services, routes, and tests
  5. `a2fd872` feat: initial implementation of backend API, services, and test suite
  6. `cefa754` feat: initialize backend application structure with core services, routes, and tests
  7. `9056611` feat: initialize backend service with core escrow, dispute, and payment modules
  8. `3af6360` feat: initial implementation of backend architecture, core services, and tests
  9. `2e3b200` feat: initialize backend application structure with core services, routes, and tests
  10. `94c79b1` feat: implement backend architecture with escrow, disputes, and payment integrations
* **Status Working Directory:** Seluruh modifikasi prompt 1 s.d. 20 telah terintegrasi secara fungsional di filesystem lokal, terverifikasi hijau pada seluruh pengujian, dan menunggu commit rilis.

---

# 3. Tech Stack dan Dependensi

### Backend Dependencies (`backend/package.json`)
| Nama Paket | Versi | Fungsi | Status Pemakaian | Bukti File Path |
| :--- | :--- | :--- | :--- | :--- |
| `express` | ^5.2.1 | Framework web HTTP server | **DIPAKAI** | `backend/src/app.js:9` |
| `@prisma/client` | ^7.8.0 | ORM database client | **DIPAKAI** | `backend/src/config/prisma.js:12` |
| `@prisma/adapter-pg` | ^7.8.0 | Driver adapter direct Postgres Prisma v7 | **DIPAKAI** | `backend/src/config/prisma.js:13` |
| `pg` | ^8.20.0 | PostgreSQL client connection pooling | **DIPAKAI** | `backend/src/config/prisma.js:11` |
| `bcryptjs` | ^3.0.3 | Hashing password pengguna (salt rounds 12) | **DIPAKAI** | `backend/src/services/auth.service.js:9` |
| `jsonwebtoken` | ^9.0.3 | Pembuatan & verifikasi access/refresh token | **DIPAKAI** | `backend/src/services/auth.service.js:10` |
| `express-validator` | ^7.3.2 | Validasi & sanitasi input request | **DIPAKAI** | `backend/src/middlewares/validate.middleware.js:8` |
| `cors` | ^2.8.6 | Pengaturan CORS origin | **DIPAKAI** | `backend/src/app.js:47` |
| `helmet` | ^8.1.0 | Pengamanan header HTTP | **DIPAKAI** | `backend/src/app.js:23` |
| `pino` | ^10.4.0 | Structured JSON logger | **DIPAKAI** | `backend/src/config/logger.js:8` |
| `pino-http` | ^11.0.0 | Logger HTTP middleware dengan redaksi data | **DIPAKAI** | `backend/src/config/logger.js:9` |
| `dotenv` | ^17.4.2 | Pemuatan environment variable | **DIPAKAI** | `backend/src/config/env.js:8` |
| `express-rate-limit` | ^8.7.5 | Pembatasan frekuensi request IP | **DIPAKAI** | `backend/src/middlewares/rateLimit.middleware.js:8` |
| `@aws-sdk/client-s3` | ^3.1175.0 | AWS S3 client untuk upload dokumen | **DIPAKAI** | `backend/src/providers/storage/s3.provider.js:7` |
| `@aws-sdk/s3-request-presigner` | ^3.1175.0 | Generator URL bertanda tangan S3 | **DIPAKAI** | `backend/src/providers/storage/s3.provider.js:8` |
| `sharp` | ^0.35.5 | Pemrosesan gambar & pembersihan EXIF | **DIPAKAI** | `backend/src/middlewares/upload.middleware.js:10` |
| `multer` | ^2.5.0 | Multipart form-data handling | **DIPAKAI** | `backend/src/middlewares/upload.middleware.js:9` |
| `socket.io` | ^4.8.4 | Server real-time WebSocket chat | **DIPAKAI** | `backend/src/socket/index.js:7` |
| `firebase-admin` | ^14.5.1 | SDK FCM push notification | **DIPAKAI** | `backend/src/providers/fcm/fcm.provider.js:8` |
| `nodemailer` | ^10.6.1 | Pengiriman email reset password | **DIPAKAI** | `backend/src/providers/mail/mail.provider.js:8` |
| `node-cron` | ^4.6.0 | Scheduler background jobs | **DIPAKAI** | `backend/src/worker.js:8` |
| `@sentry/node` | ^11.16.0 | Pelaporan error & observabilitas | **DIPAKAI** | `backend/src/config/sentry.js:8` |

### Mobile Dependencies (`mobile/pubspec.yaml`)
| Nama Paket | Versi | Fungsi | Status Pemakaian | Bukti File Path |
| :--- | :--- | :--- | :--- | :--- |
| `flutter_bloc` | ^8.1.6 | Manajemen state BLoC/Cubit | **DIPAKAI** | `mobile/lib/app.dart:18` |
| `bloc` | ^8.1.4 | Core library BLoC | **DIPAKAI** | `mobile/lib/features/auth/presentation/bloc/auth_bloc.dart:2` |
| `equatable` | ^2.0.7 | Value equality perbandingan state | **DIPAKAI** | `mobile/lib/features/auth/presentation/bloc/auth_state.dart:1` |
| `get_it` | ^7.7.0 | Service Locator Dependency Injection | **DIPAKAI** | `mobile/lib/injection_container.dart:18` |
| `go_router` | ^14.0.0 | Navigasi deklaratif & Route Guard | **DIPAKAI** | `mobile/lib/config/routes/app_router.dart:3` |
| `dartz` | ^0.10.1 | Functional programming (`Either<Failure, T>`) | **DIPAKAI** | Digunakan pada seluruh Repository & Cubit |
| `google_fonts` | ^6.2.1 | Tipografi kustom (Space Grotesk) | **DIPAKAI** | Digunakan pada seluruh UI Brutalist |
| `shimmer` | ^3.0.0 | Animasi skeleton loading | **DIPAKAI** | `mobile/lib/core/widgets/brutal_skeleton.dart:2` |
| `image_picker` | ^1.1.2 | Pengambilan foto KTP & kamera selfie | **DIPAKAI** | `mobile/lib/features/settings/presentation/pages/kyc_screen.dart:4` |
| `image_cropper` | ^12.2.1 | Pemotongan rasio dokumen identitas | **DIPAKAI** | `mobile/lib/features/settings/presentation/pages/kyc_screen.dart:5` |
| `timeago` | ^3.7.0 | Pemformatan waktu lampau chat | **DIPAKAI** | `mobile/lib/features/chat/presentation/pages/chat_room_page.dart:6` |
| `intl` | ^0.19.0 | Pemformatan mata uang IDR & waktu WIB | **DIPAKAI** | `mobile/lib/core/utils/currency_formatter.dart:1` |
| `url_launcher` | ^6.3.1 | Membuka tautan WhatsApp bantuan | **DIPAKAI** | `mobile/lib/features/settings/presentation/pages/help_center_screen.dart:3` |
| `share_plus` | ^7.2.2 | Membagikan kode transaksi ke aplikasi lain | **DIPAKAI** | `mobile/lib/features/transaction/presentation/pages/transaction_detail_page.dart:6` |
| `flutter_local_notifications` | ^21.0.0 | Tampilan notifikasi push lokal | **DIPAKAI** | `mobile/lib/core/services/notification_service.dart:5` |
| `flutter_secure_storage` | ^9.2.4 | Enkripsi keychain token JWT | **DIPAKAI** | `mobile/lib/core/services/api_service.dart:6` |
| `socket_io_client` | ^3.0.2 | Klien WebSocket realtime chat | **DIPAKAI** | `mobile/lib/core/services/socket_service.dart:3` |
| `fl_chart` | ^1.2.0 | Grafik tren transaksi & volume admin | **DIPAKAI** | `mobile/lib/features/admin/presentation/pages/admin_dashboard_screen.dart:4` |
| `qr_flutter` | ^4.1.0 | Rendering QR Code QRIS dinamis | **DIPAKAI** | `mobile/lib/features/wallet/presentation/pages/detail_pembayaran_screen.dart:4` |
| `http` | ^1.6.0 | Klien HTTP REST API | **DIPAKAI** | `mobile/lib/core/services/api_service.dart:5` |
| `firebase_core` | ^4.9.0 | Inisialisasi Firebase | **DIPAKAI** | `mobile/lib/main.dart:3` |
| `firebase_messaging` | ^16.2.2 | Penerimaan token & event push FCM | **DIPAKAI** | `mobile/lib/core/services/notification_service.dart:4` |
| `sentry_flutter` | ^8.14.2 | Pelaporan error Flutter & breadcrumbs | **DIPAKAI** | `mobile/lib/main.dart:4` |

### Sumber Kebenaran Autentikasi (*Auth Single Source of Truth*)
* **Sumber Kebenaran:** **Backend Custom JWT**.
* **Mekanisme:** Diterbitkan oleh server Express (`backend/src/services/auth.service.js:101`). Access Token memiliki masa berlaku 15 menit, dan Refresh Token tersimpan dalam bentuk hash SHA-256 pada tabel PostgreSQL `refresh_tokens`.
* **Klarifikasi Firebase & Supabase:**
  - Supabase **tidak digunakan** sama sekali (0 dependensi, 0 pemanggilan).
  - Firebase Auth **tidak digunakan** sebagai penyedia sesi (hanya Firebase Core & Firebase Messaging yang aktif untuk registrasi push notification token perangkat).

---

# 4. Environment dan Cara Menjalankan

### Variabel Environment yang Dibutuhkan
#### Backend (`backend/.env`)
| Variabel | Sifat | Deskripsi / Validasi |
| :--- | :--- | :--- |
| `PORT` | Opsional | Port listener HTTP server (default: `5000`) |
| `NODE_ENV` | Wajib | Pilihan: `development`, `staging`, `production`, `test` |
| `DATABASE_URL` | Wajib | Connection string PostgreSQL (skema public) |
| `DATABASE_URL_TEST` | Wajib (Test) | Connection string PostgreSQL khusus database pengujian |
| `JWT_SECRET` | Wajib | Kunci penandatanganan token JWT (minimal 32 karakter) |
| `JWT_EXPIRES_IN` | Opsional | Masa berlaku access token (default: `'15m'`) |
| `BCRYPT_SALT_ROUNDS` | Opsional | Kompleksitas salt hash kata sandi (default: `12`, testing: `4`) |
| `DATA_ENCRYPTION_KEY` | Wajib | Kunci enkripsi simetris AES-256-GCM NIK (minimal 32 karakter) |
| `CORS_ORIGIN` | Wajib (Prod) | Daftar origin terizinkan koma-terpisah (misal `https://admin.rekber.id`) |
| `PAYMENT_PROVIDER` | Wajib | `xendit` untuk live, `fake` untuk dev/test (ditolak fake di production) |
| `XENDIT_SECRET_KEY` | Kondisional | Wajib diisi jika `PAYMENT_PROVIDER=xendit` |
| `XENDIT_WEBHOOK_VERIFICATION_TOKEN` | Kondisional | Token verifikasi callback webhook dari Xendit |
| `STORAGE_PROVIDER` | Wajib | `s3` untuk live, `local` untuk dev/test (ditolak local di production) |
| `STORAGE_LOCAL_DIR` | Kondisional | Folder penyimpanan lokal (default: `storage_uploads`) |
| `STORAGE_LOCAL_SECRET` | Kondisional | Secret kunci HMAC penandatanganan URL lokal |
| `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION` | Kondisional | Wajib diisi lengkap jika `STORAGE_PROVIDER=s3` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Opsional | String kredensial Base64 Google Service Account untuk FCM push |
| `RUN_JOBS_IN_API` | Opsional | Nilai boolean `'true'`/`'false'` untuk menjalankan worker di proses API |
| `WORKER_ACCELERATED_INTERVAL` | Opsional | Nilai boolean untuk mempercepat interval cron saat pengujian |
| `METRICS_TOKEN` | Wajib | Token rahasia otentikasi scraping endpoint `/metrics` |
| `SENTRY_DSN` | Opsional | DSN proyek Sentry untuk pelaporan unhandled 5xx error |
| `DB_POOL_MAX`, `DB_POOL_MIN`, `DB_IDLE_TIMEOUT_MS`, `DB_CONNECTION_TIMEOUT_MS` | Opsional | Konfigurasi batas connection pool PostgreSQL driver |

#### Mobile Dart Defines
* `API_BASE_URL`: URL endpoint REST API (Wajib berawalan `https://` pada build release).
* `SENTRY_DSN`: DSN proyek Sentry Flutter.
* `SUPPORT_WHATSAPP`: Nomor WhatsApp layanan bantuan (format: `628xxxxxxxxxx`).

### Langkah Menjalankan Aplikasi dari Nol
#### 1. Backend
1. Pastikan PostgreSQL 16 aktif secara lokal atau jalankan via Docker: `docker compose up -d postgres minio`.
2. Masuk ke direktori backend: `cd backend`.
3. Salin konfigurasi environment: `cp .env.example .env` lalu sesuaikan kredensial database.
4. Pasang dependensi: `npm ci`.
5. Validasi skema & generate client: `npx prisma validate && npx prisma generate`.
6. Terapkan migrasi database: `npx prisma migrate deploy`.
7. Masukkan data awal: `npm run prisma:seed`.
8. Buat akun admin awal jika diperlukan: `node scripts/create-admin.js`.
9. Jalankan server: `npm run dev` (atau `npm start` untuk production).
10. Jalankan worker scheduler di terminal terpisah: `npm run worker`.

#### 2. Mobile (Flutter)
1. Masuk ke direktori mobile: `cd mobile`.
2. Pasang dependensi: `flutter pub get`.
3. Pastikan backend API aktif di `http://localhost:5000/api` (atau `http://10.0.2.2:5000/api` untuk Android Emulator).
4. Jalankan aplikasi pada perangkat / emulator:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
   ```

### Hasil Verifikasi Perintah Langsung
| Perintah | Status | Ringkasan Output Verifikasi |
| :--- | :--- | :--- |
| `npm ci` | **SUKSES** | Semua dependensi backend terpasang sinkron dengan `package-lock.json`. |
| `npx prisma validate` | **SUKSES** | `The schema at prisma\schema.prisma is valid 🚀`. |
| `npx prisma generate` | **SUKSES** | `✔ Generated Prisma Client (v7.8.0) to .\node_modules\@prisma\client in 284ms`. |
| `npx prisma migrate status` | **SUKSES** | `10 migrations found in prisma/migrations. Database schema is up to date!`. |
| Server Inisialisasi Check | **SUKSES** | Server mengimpor `src/app.js` dan terhubung database tanpa kendala (`APP_LOAD_SUCCESS`). |
| `flutter pub get` | **SUKSES** | `Got dependencies!` (Resolusi dependensi Flutter bersih). |
| `flutter analyze` | **SUKSES** | **0 Errors**, **0 Warnings** (Hanya 11 info non-blocking terkait depresiasi upstream Flutter). |
| `flutter test` | **SUKSES** | **194 / 194 passed (100% Lulus)** pada pengujian core, features, dan config. |
| Backend Tests | **SUKSES** | **5 / 5 suites unit passed (42 / 42 tests)** & **22 / 22 E2E & Security passed**. |

---

# 5. Database

### Skema Prisma Lengkap (`backend/prisma/schema.prisma`)
Skema database menggunakan PostgreSQL via Prisma Client v7 dengan driver adapter direct pool `@prisma/adapter-pg`.

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
}

// =============================================================================
// ENUMS
// =============================================================================

enum Role {
  USER
  ADMIN
}

enum TransactionStatus {
  PENDING
  PAID
  SHIPPED
  COMPLETED
  CANCELLED
  DISPUTED
  REFUNDED
}

enum FeePayer {
  BUYER
  SELLER
  SPLIT
}

enum LedgerType {
  TOPUP
  ESCROW_HOLD
  ESCROW_RELEASE
  ESCROW_REFUND
  PLATFORM_FEE
  WITHDRAWAL_RESERVE
  WITHDRAWAL_RELEASE
  ADJUSTMENT
}

enum LedgerDirection {
  CREDIT
  DEBIT
}

enum PaymentMethod {
  QRIS
  VIRTUAL_ACCOUNT
}

enum PaymentIntentStatus {
  PENDING
  PAID
  EXPIRED
  FAILED
}

enum WithdrawalStatus {
  PENDING_REVIEW
  APPROVED
  PROCESSING
  COMPLETED
  REJECTED
  FAILED
  CANCELLED
}

enum FilePurpose {
  SHIPMENT_PROOF
  DISPUTE_EVIDENCE
  KYC_ID
  KYC_SELFIE
  CHAT_IMAGE
}

enum DisputeReason {
  NOT_RECEIVED
  NOT_AS_DESCRIBED
  DEFECTIVE
  OTHER
}

enum DisputeStatus {
  OPEN
  UNDER_REVIEW
  RESOLVED_BUYER
  RESOLVED_SELLER
}

enum ChatMessageType {
  TEXT
  IMAGE
  SYSTEM
}

enum UserKycStatus {
  NONE
  PENDING
  APPROVED
  REJECTED
}

enum KycSubmissionStatus {
  PENDING
  APPROVED
  REJECTED
}

// =============================================================================
// MODELS
// =============================================================================

model User {
  id        String   @id @default(uuid())
  name      String
  email     String   @unique
  password  String   // Hashed bcrypt
  role      Role     @default(USER)
  balance   BigInt   @default(0) // Integer rupiah bulat

  firebaseUid String? @unique @map("firebase_uid")
  fcmToken    String? @map("fcm_token")
  isActive    Boolean @default(true) @map("is_active")
  kycStatus   UserKycStatus @default(NONE) @map("kyc_status")

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  buyerTransactions   Transaction[]        @relation("BuyerTransactions")
  sellerTransactions  Transaction[]        @relation("SellerTransactions")
  refreshTokens       RefreshToken[]
  passwordResetTokens PasswordResetToken[]
  ledgerEntries       LedgerEntry[]
  paymentIntents      PaymentIntent[]
  bankAccounts        BankAccount[]
  withdrawals         WithdrawalRequest[]
  reviewedWithdrawals WithdrawalRequest[]  @relation("ReviewedWithdrawals")
  fileAssets          FileAsset[]
  submittedShipments  ShipmentProof[]
  openedDisputes      Dispute[]            @relation("OpenedDisputes")
  resolvedDisputes    Dispute[]            @relation("ResolvedDisputes")
  disputeEvidences    DisputeEvidence[]
  notifications       Notification[]
  chatMessages        ChatMessage[]
  chatReadStates      ChatReadState[]
  kycSubmissions      KycSubmission[]      @relation("UserKycSubmissions")
  reviewedKyc         KycSubmission[]      @relation("ReviewedKycSubmissions")
  auditLogs           AuditLog[]           @relation("ActorAuditLogs")

  @@map("users")
}

model RefreshToken {
  id           String    @id @default(uuid())
  userId       String    @map("user_id")
  tokenHash    String    @unique @map("token_hash")
  expiresAt    DateTime  @map("expires_at")
  revokedAt    DateTime? @map("revoked_at")
  replacedById String?   @map("replaced_by_id")
  userAgent    String?   @map("user_agent")
  ip           String?
  createdAt    DateTime  @default(now()) @map("created_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@map("refresh_tokens")
}

model PasswordResetToken {
  id        String    @id @default(uuid())
  userId    String    @map("user_id")
  tokenHash String    @unique @map("token_hash")
  expiresAt DateTime  @map("expires_at")
  usedAt    DateTime? @map("used_at")
  createdAt DateTime  @default(now()) @map("created_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@map("password_reset_tokens")
}

model Transaction {
  id              String            @id @default(uuid())
  code            String            @unique
  amount          BigInt
  itemDescription String            @map("item_description")
  status          TransactionStatus @default(PENDING)

  buyerFee   BigInt   @default(0) @map("buyer_fee")
  sellerFee  BigInt   @default(0) @map("seller_fee")
  feePayer   FeePayer @default(SPLIT) @map("fee_payer")
  heldAmount BigInt   @default(0) @map("held_amount")

  paidAt         DateTime? @map("paid_at")
  shippedAt      DateTime? @map("shipped_at")
  completedAt    DateTime? @map("completed_at")
  cancelledAt    DateTime? @map("cancelled_at")
  cancelReason   String?   @map("cancel_reason")
  autoReleaseAt  DateTime? @map("auto_release_at")
  expiresAt      DateTime? @map("expires_at")
  reminderSentAt DateTime? @map("reminder_sent_at")

  buyerId  String @map("buyer_id")
  sellerId String @map("seller_id")

  buyer         User           @relation("BuyerTransactions", fields: [buyerId], references: [id])
  seller        User           @relation("SellerTransactions", fields: [sellerId], references: [id])
  ledgerEntries LedgerEntry[]
  shipmentProof ShipmentProof?
  dispute       Dispute?
  chatMessages  ChatMessage[]
  chatReadStates ChatReadState[]

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("transactions")
}

model LedgerEntry {
  id             String          @id @default(uuid())
  userId         String?         @map("user_id")
  transactionId  String?         @map("transaction_id")
  type           LedgerType
  direction      LedgerDirection
  amount         BigInt
  balanceAfter   BigInt          @map("balance_after")
  idempotencyKey String          @unique @map("idempotency_key")
  referenceType  String?         @map("reference_type")
  referenceId    String?         @map("reference_id")
  metadata       Json?
  createdAt      DateTime        @default(now()) @map("created_at")

  user        User?        @relation(fields: [userId], references: [id])
  transaction Transaction? @relation(fields: [transactionId], references: [id])

  @@index([userId, createdAt])
  @@index([transactionId])
  @@map("ledger_entries")
}

model PlatformSetting {
  key         String   @id
  value       String
  updatedById String?  @map("updated_by_id")
  updatedAt   DateTime @updatedAt @map("updated_at")

  @@map("platform_settings")
}

model PaymentIntent {
  id          String              @id @default(uuid())
  userId      String              @map("user_id")
  provider    String
  referenceId String              @unique @map("reference_id")
  providerRef String?             @map("provider_ref")
  amount      BigInt
  method      PaymentMethod
  status      PaymentIntentStatus @default(PENDING)
  qrString    String?             @map("qr_string") @db.Text
  vaNumber    String?             @map("va_number")
  bankCode    String?             @map("bank_code")
  expiresAt   DateTime            @map("expires_at")
  paidAt      DateTime?           @map("paid_at")
  createdAt   DateTime            @default(now()) @map("created_at")
  updatedAt   DateTime            @updatedAt @map("updated_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, createdAt])
  @@index([status, expiresAt])
  @@map("payment_intents")
}

model WebhookEvent {
  id          String    @id @default(uuid())
  provider    String
  eventId     String    @unique @map("event_id")
  payload     Json
  status      String
  processedAt DateTime? @map("processed_at")
  createdAt   DateTime  @default(now()) @map("created_at")

  @@index([provider, eventId])
  @@map("webhook_events")
}

model BankAccount {
  id               String              @id @default(uuid())
  userId           String              @map("user_id")
  bankCode         String              @map("bank_code")
  accountNumberEnc String              @map("account_number_enc") @db.Text
  accountLast4     String              @map("account_last4")
  accountName      String              @map("account_name")
  isDefault        Boolean             @default(false) @map("is_default")
  deletedAt        DateTime?           @map("deleted_at")
  createdAt        DateTime            @default(now()) @map("created_at")
  updatedAt        DateTime            @updatedAt @map("updated_at")

  user             User                @relation(fields: [userId], references: [id], onDelete: Cascade)
  withdrawals      WithdrawalRequest[]

  @@index([userId, deletedAt])
  @@map("bank_accounts")
}

model WithdrawalRequest {
  id             String           @id @default(uuid())
  userId         String           @map("user_id")
  bankAccountId  String           @map("bank_account_id")
  amount         BigInt
  fee            BigInt           @default(0)
  status         WithdrawalStatus @default(PENDING_REVIEW)
  idempotencyKey String?          @unique @map("idempotency_key")
  providerRef    String?          @map("provider_ref")
  failureReason  String?          @map("failure_reason")
  reviewedById   String?          @map("reviewed_by_id")
  reviewedAt     DateTime?        @map("reviewed_at")
  createdAt      DateTime         @default(now()) @map("created_at")
  updatedAt      DateTime         @updatedAt @map("updated_at")

  user           User             @relation(fields: [userId], references: [id], onDelete: Cascade)
  bankAccount    BankAccount      @relation(fields: [bankAccountId], references: [id])
  reviewedBy     User?            @relation("ReviewedWithdrawals", fields: [reviewedById], references: [id])

  @@index([userId, createdAt])
  @@index([status, createdAt])
  @@map("withdrawal_requests")
}

model FileAsset {
  id         String      @id @default(uuid())
  ownerId    String      @map("owner_id")
  purpose    FilePurpose
  storageKey String      @unique @map("storage_key")
  mime       String
  size       Int
  sha256     String
  createdAt  DateTime    @default(now()) @map("created_at")
  deletedAt  DateTime?   @map("deleted_at")

  owner User @relation(fields: [ownerId], references: [id], onDelete: Cascade)
  chatMessages ChatMessage[]
  kycIdSubmissions KycSubmission[] @relation("KycIdFiles")
  kycSelfieSubmissions KycSubmission[] @relation("KycSelfieFiles")

  @@index([ownerId, deletedAt])
  @@index([purpose, deletedAt])
  @@map("file_assets")
}

model ShipmentProof {
  id             String    @id @default(uuid())
  transactionId  String    @unique @map("transaction_id")
  submittedById  String    @map("submitted_by_id")
  courier        String?
  trackingNumber String?   @map("tracking_number")
  note           String?   @db.Text
  fileIds        String[]  @default([]) @map("file_ids")
  createdAt      DateTime  @default(now()) @map("created_at")

  transaction Transaction @relation(fields: [transactionId], references: [id], onDelete: Cascade)
  submittedBy User        @relation(fields: [submittedById], references: [id])

  @@map("shipment_proofs")
}

model Dispute {
  id             String        @id @default(uuid())
  transactionId  String        @unique @map("transaction_id")
  openedById     String        @map("opened_by_id")
  reason         DisputeReason
  description    String        @db.Text
  status         DisputeStatus @default(OPEN)
  resolutionNote String?       @map("resolution_note") @db.Text
  resolvedById   String?       @map("resolved_by_id")
  resolvedAt     DateTime?     @map("resolved_at")
  createdAt      DateTime      @default(now()) @map("created_at")

  transaction    Transaction       @relation(fields: [transactionId], references: [id], onDelete: Cascade)
  openedBy       User              @relation("OpenedDisputes", fields: [openedById], references: [id])
  resolvedBy     User?             @relation("ResolvedDisputes", fields: [resolvedById], references: [id])
  evidences      DisputeEvidence[]

  @@index([status, createdAt])
  @@map("disputes")
}

model DisputeEvidence {
  id            String   @id @default(uuid())
  disputeId     String   @map("dispute_id")
  submittedById String   @map("submitted_by_id")
  note          String?  @db.Text
  fileIds       String[] @default([]) @map("file_ids")
  createdAt     DateTime @default(now()) @map("created_at")

  dispute     Dispute @relation(fields: [disputeId], references: [id], onDelete: Cascade)
  submittedBy User    @relation(fields: [submittedById], references: [id])

  @@index([disputeId, createdAt])
  @@map("dispute_evidences")
}

model Notification {
  id        String    @id @default(uuid())
  userId    String    @map("user_id")
  type      String
  title     String
  body      String    @db.Text
  data      Json?
  readAt    DateTime? @map("read_at")
  createdAt DateTime  @default(now()) @map("created_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, readAt, createdAt])
  @@map("notifications")
}

model ChatMessage {
  id            String          @id @default(uuid())
  transactionId String          @map("transaction_id")
  senderId      String?         @map("sender_id")
  type          ChatMessageType @default(TEXT)
  body          String?         @db.VarChar(2000)
  fileId        String?         @map("file_id")
  createdAt     DateTime        @default(now()) @map("created_at")
  deletedAt     DateTime?       @map("deleted_at")

  transaction Transaction @relation(fields: [transactionId], references: [id], onDelete: Cascade)
  sender      User?       @relation(fields: [senderId], references: [id], onDelete: SetNull)
  file        FileAsset?  @relation(fields: [fileId], references: [id], onDelete: SetNull)

  @@index([transactionId, createdAt])
  @@map("chat_messages")
}

model ChatReadState {
  transactionId String   @map("transaction_id")
  userId        String   @map("user_id")
  lastReadAt    DateTime @default(now()) @map("last_read_at")

  transaction Transaction @relation(fields: [transactionId], references: [id], onDelete: Cascade)
  user        User        @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@id([transactionId, userId])
  @@map("chat_read_states")
}

model KycSubmission {
  id              String              @id @default(uuid())
  userId          String              @map("user_id")
  fullName        String              @map("full_name")
  nikEnc          String              @map("nik_enc") @db.Text
  idFileId        String              @map("id_file_id")
  selfieFileId    String              @map("selfie_file_id")
  status          KycSubmissionStatus @default(PENDING)
  rejectionReason String?             @map("rejection_reason") @db.Text
  reviewedById    String?             @map("reviewed_by_id")
  reviewedAt      DateTime?           @map("reviewed_at")
  createdAt       DateTime            @default(now()) @map("created_at")

  user       User      @relation("UserKycSubmissions", fields: [userId], references: [id], onDelete: Cascade)
  reviewedBy User?     @relation("ReviewedKycSubmissions", fields: [reviewedById], references: [id])
  idFile     FileAsset @relation("KycIdFiles", fields: [idFileId], references: [id])
  selfieFile FileAsset @relation("KycSelfieFiles", fields: [selfieFileId], references: [id])

  @@index([userId, createdAt])
  @@index([status, createdAt])
  @@map("kyc_submissions")
}

model AuditLog {
  id         String   @id @default(uuid())
  actorId    String?  @map("actor_id")
  action     String
  targetType String   @map("target_type")
  targetId   String   @map("target_id")
  before     Json?
  after      Json?
  ip         String?
  createdAt  DateTime @default(now()) @map("created_at")

  actor User? @relation("ActorAuditLogs", fields: [actorId], references: [id], onDelete: SetNull)

  @@index([targetType, targetId])
  @@index([actorId, createdAt])
  @@index([action, createdAt])
  @@map("audit_logs")
}
```

### Daftar Migrasi Database
1. `20261121000000_init`: Skema awal User, Transaction, dan Enum dasar.
2. `20261121010000_add_auth_security`: Model RefreshToken, PasswordResetToken, dan tracking sesi IP.
3. `20261121020000_add_money_and_ledger`: Konversi BigInt Rupiah, LedgerEntry, dan PlatformSetting.
4. `20261121030000_add_payment_gateway`: Model PaymentIntent dan WebhookEvent.
5. `20261121040000_add_bank_accounts_and_withdrawals`: BankAccount terenkripsi dan WithdrawalRequest.
6. `20261121050000_add_file_assets_and_shipment_proofs`: FileAsset metadata dan ShipmentProof kurir.
7. `20261121060000_add_disputes_and_evidence`: Dispute, DisputeEvidence, dan resolusi sengketa.
8. `20261121070000_add_notifications`: Inbox Notification dan integrasi FCM.
9. `20261121080000_add_chat_messages`: ChatMessage, ChatReadState, dan room WebSocket.
10. `20261121090000_add_kyc_and_audit_logs`: KycSubmission NIK terenkripsi, status KYC, dan AuditLog administratif.

### Evaluasi Skema untuk Aplikasi Rekber
* **Kekuatan:**
  - Desain buku besar terisolasi (`LedgerEntry`) menjamin ketertelusuran setiap sen uang rupiah secara *immutable* dan anti-duplikasi melalui constraint `idempotency_key`.
  - Enkripsi data sensitif (NIK dan nomor rekening) terintegrasi pada level skema database (`nikEnc`, `accountNumberEnc`).
  - Jejak audit (`AuditLog`) mencatat perubahan status dan modifikasi platform setting secara komprehensif.
* **Kekurangan / Keterbatasan Desain Saat Ini:**
  - Hanya mendukung mata uang tunggal (IDR). Skema tidak memuat field multi-currency (`currency VARCHAR(3)`).
  - Belum ada skema partisi tabel (*table partitioning*) untuk tabel transaksi dan ledger berukuran jutaan baris (disarankan saat volume transaksi membesar).

---

# 6. Backend: Detail Per Endpoint (Ringkasan & Indeks)

> [!NOTE]
> Rincian lengkap langkah demi langkah dari **seluruh 73 endpoint API** (mencakup method, path, validasi field, request body, contoh respon sukses & error, mekanisme transaksi DB, serta otorisasi kepemilikan) didokumentasikan secara menyeluruh pada file pendamping:  
> **👉 [STATUS_APLIKASI_PART2.md](STATUS_APLIKASI_PART2.md)**.

### Matriks Rekapitulasi 73 Endpoint Backend
| Grup Endpoint | File Route | Jumlah Endpoint | Autentikasi / Akses | Status |
| :--- | :--- | :---: | :--- | :---: |
| **Authentication & Profile** | `auth.routes.js` | 13 | Publik, Rate Limited, JWT Me/Profile | ✅ BERFUNGSI |
| **Escrow Transactions & Chat** | `transaction.routes.js` | 11 | JWT (Buyer/Seller/Admin) | ✅ BERFUNGSI |
| **Wallet, Topup & Withdrawals** | `wallet.routes.js` | 10 | JWT (Pemilik Dompet) | ✅ BERFUNGSI |
| **Bank Accounts** | `bankAccount.routes.js` | 3 | JWT (Pemilik Akun) | ✅ BERFUNGSI |
| **Public Configuration** | `config.routes.js` | 1 | Publik Tanpa Auth | ✅ BERFUNGSI |
| **File Assets & Storage** | `file.routes.js` | 3 | JWT & HMAC Signed URLs | ✅ BERFUNGSI |
| **User Disputes** | `dispute.routes.js` | 2 | JWT (Partisipan Sengketa) | ✅ BERFUNGSI |
| **Notification Inbox** | `notification.routes.js` | 4 | JWT (Penerima Notifikasi) | ✅ BERFUNGSI |
| **User Identity Verification (KYC)**| `kyc.routes.js` | 2 | JWT (Pengguna Terdaftar) | ✅ BERFUNGSI |
| **Payment Webhooks** | `webhook.routes.js` | 1 | Token Provider Header | ✅ BERFUNGSI |
| **Observability & Health Probes** | `app.js` & `metrics.routes.js` | 3 | Publik (Health) & Token (Metrics) | ✅ BERFUNGSI |
| **Admin Withdrawals** | `admin.withdrawal.routes.js`| 3 | Role ADMIN Saja | ✅ BERFUNGSI |
| **Admin Disputes** | `admin.dispute.routes.js` | 4 | Role ADMIN Saja | ✅ BERFUNGSI |
| **Admin KYC Moderation** | `admin.kyc.routes.js` | 4 | Role ADMIN Saja | ✅ BERFUNGSI |
| **Admin Metrics & Analytics** | `admin.metric.routes.js` | 1 | Role ADMIN Saja | ✅ BERFUNGSI |
| **Admin Platform Settings** | `admin.setting.routes.js` | 2 | Role ADMIN Saja | ✅ BERFUNGSI |
| **Admin Transactions** | `admin.transaction.routes.js` | 1 | Role ADMIN Saja | ✅ BERFUNGSI |
| **Admin User Management** | `admin.user.routes.js` | 4 | Role ADMIN Saja | ✅ BERFUNGSI |
| **Admin Audit Trail** | `admin.audit.routes.js` | 1 | Role ADMIN Saja | ✅ BERFUNGSI |
| **TOTAL** | **20 File Routes** | **73 Endpoint** | **100% Terlindungi** | **✅ BERFUNGSI** |

---

# 7. Logika Inti Escrow

### 1. State Machine Transaksi
Sistem escrow menerapkan mesin status kanonik pada `backend/src/services/escrow.service.js`:

| Status Awal | Status Tujuan | Aktor Diizinkan | Validasi & Syarat |
| :--- | :--- | :--- | :--- |
| `PENDING` | `PAID` | Pembeli (via saldo) atau Webhook | Saldo pembeli mencukupi (`balance >= amount + buyerFee`), status transaksi saat ini harus `PENDING`. |
| `PENDING` | `CANCELLED` | Pembeli / Penjual / Worker Cron | Hanya jika belum dibayar. Worker `expirePending` membatalkan jika telah melewati batas waktu `expiresAt`. |
| `PAID` | `SHIPPED` | Penjual | Penjual wajib menyertakan bukti pengiriman kurir/resi (`ShipmentProof`) atau catatan serah terima. |
| `SHIPPED` | `COMPLETED` | Pembeli atau Worker Cron | Pembeli mengonfirmasi penerimaan barang, ATAU worker `autoRelease` mengeksekusi jika `autoReleaseAt` lampau. |
| `PAID` / `SHIPPED` | `DISPUTED` | Pembeli | Pembeli mengajukan alasan komplain (20-2000 karakter) dan bukti. `autoReleaseAt` otomatis dibekukan (`null`). |
| `DISPUTED` | `COMPLETED` | Admin Platform | Admin memutuskan sengketa memenangkan penjual (`RESOLVED_SELLER`), dana diteruskan ke penjual. |
| `DISPUTED` | `REFUNDED` | Admin Platform | Admin memutuskan sengketa memenangkan pembeli (`RESOLVED_BUYER`), dana dikembalikan penuh ke pembeli. |

### 2. Alur Pembayaran & Penguncian Dana
* Transaksi dibuat dengan status `PENDING` dan kode unik 8-karakter acak.
* Saat pembayaran dilakukan melalui saldo (`payTransactionFromBalance` di `backend/src/services/escrow.service.js:95`):
  1. Dilakukan verifikasi `status === 'PENDING'`.
  2. Perhitungan biaya platform (`fee`): dihitung proporsional sesuai `feePayer` (BUYER, SELLER, atau SPLIT).
  3. Menggunakan transaksi Prisma (`prisma.$transaction`):
     - Saldo pembeli didebit sebesar `amount + buyerFee` melalui `ledgerService.debit()`.
     - Catatan `LedgerEntry` bertipe `ESCROW_HOLD` dibuat dengan arah `DEBIT`.
     - Status transaksi beralih ke `PAID`, `heldAmount` diset sebesar `amount`, dan `paidAt` dicatat.

### 3. Alur Top-up dan Penarikan Dana
* **Top-Up (`topup.service.js`)**:
  - Pengguna membuat `PaymentIntent` memilih QRIS atau Virtual Account.
  - Payment gateway mitra (Xendit atau Fake Provider di dev) menghasilkan `qrString` atau `vaNumber`.
  - Saat pembayaran diselesaikan oleh pengguna, payment gateway mengirimkan webhook ke `/webhooks/payment/:provider`.
  - Handler webhook memverifikasi tanda tangan/token, mencatat `WebhookEvent`, dan secara atomik mengkredit saldo pengguna dengan entri buku besar `TOPUP`.
* **Penarikan Dana (`withdrawal.service.js`)**:
  - Mensyaratkan status KYC pengguna berstatus `APPROVED` (`assertCanWithdraw`).
  - Saldo yang ditarik dipotong dari `balance` dan ditahan dalam status `PENDING_REVIEW` dengan entri buku besar `WITHDRAWAL_RESERVE`.
  - Admin meninjau penarikan dana (`approveWithdrawal` / `rejectWithdrawal`).
  - Bila disetujui, pemicu payout dikirim ke gateway perbankan. Bila ditolak, saldo dikembalikan ke pengguna melalui entri `ADJUSTMENT`.

### 4. Pelepasan Dana Saat COMPLETED (Anti Double-Spend)
Fungsi `releaseEscrow` pada `backend/src/services/escrow.service.js:145` mengeksekusi transfer dana secara atomik:
```javascript
// Cuplikan logika pelepasan dana atomik (escrow.service.js)
const tx = await dbTx.transaction.update({
  where: { id: transactionId, status: { in: ['SHIPPED', 'DISPUTED'] } },
  data: {
    status: 'COMPLETED',
    completedAt: new Date(),
    heldAmount: 0,
    autoReleaseAt: null,
  },
});
// Kredit dana bersih ke saldo penjual
const netSellerAmount = tx.amount - tx.sellerFee;
await ledgerService.credit(dbTx, tx.sellerId, netSellerAmount, 'ESCROW_RELEASE', {
  transactionId: tx.id,
  idempotencyKey: `tx-release-${tx.id}`,
});
```
* **Jaminan Keamanan:**
  - Update status menggunakan filter ketat `status: { in: ['SHIPPED', 'DISPUTED'] }` (Compare-and-Swap). Jika dua request paralel masuk bersamaan, request kedua akan gagal karena status sudah berubah menjadi `COMPLETED`.
  - Pengkreditan saldo terikat pada `idempotencyKey: 'tx-release-' + tx.id`. Database menolak duplikasi entri berkat *unique constraint* pada tabel `ledger_entries`.

### 5. Penanganan Sengketa & Bukti
* Sengketa dibuka melalui `POST /api/transactions/:id/dispute`.
* Kunci `autoReleaseAt` dikosongkan agar worker background tidak melepaskan dana otomatis saat investigasi berlangsung.
* Pembeli dan penjual dapat menambahkan hingga masing-masing 10 bukti berkas (`DisputeEvidence`).
* Keputusan admin dieksekusi secara final melalui `POST /api/admin/disputes/:id/resolve`, mendistribusikan dana dan mencatat alasan keputusan serta ID admin pemeriksa.

---

# 8. Autentikasi dan Keamanan

### 1. Alur Otentikasi Ujung ke Ujung
* **Registrasi & Login**: Kata sandi di-hash menggunakan `bcryptjs` dengan salt rounds 12.
* **Dual-Token System**:
  - **Access Token:** JWT berumur pendek (15 menit), ditandatangani menggunakan `JWT_SECRET`.
  - **Refresh Token:** String kriptografis acak 64-byte berumur 7 hari. Nilai hash SHA-256 disimpan di database (`refresh_tokens.token_hash`).
* **Rotasi Token & Deteksi Pencurian (*Token Theft Detection*)**:
  Setiap pemanggilan `/api/auth/refresh` menerbitkan access token baru DAN me-rotasi refresh token. Jika refresh token yang sudah pernah dirotasi digunakan kembali (indikasi token dicuri), sistem seketika mencabut seluruh sesi pengguna tersebut (`backend/src/services/auth.service.js:154`).
* **Mobile Auto-Refresh Lock**:
  `ApiService` Flutter pada `mobile/lib/core/services/api_service.dart:102` menggunakan penguncian asinkron (*Future memoization lock*). Jika tiga request paralel menerima HTTP 401 secara bersamaan, sistem hanya memicu tepat satu panggilan refresh token dan mengantre request lainnya hingga token baru siap.

### 2. Penegakan Otorisasi Peran (Role-Based Access Control)
* **Backend:** Middleware `backend/src/middlewares/auth.middleware.js` memvalidasi JWT (`authenticate`) dan memverifikasi peran admin (`authorize('ADMIN')`). Jika user biasa mencoba mengakses endpoint admin, server mengembalikan `403 FORBIDDEN`.
* **Mobile:** Route guard murni pada `mobile/lib/config/routes/app_router.dart:103` mencegah user non-admin mengakses path `/admin/*` dan me-redirect ke `/home`.

### 3. Middleware Keamanan
* **Helmet (`helmet()`):** Mengaktifkan proteksi `nosniff`, frame guard (anti-clickjacking), dan hide powered-by.
* **CORS:** Di lingkungan produksi, koneksi dibatasi ketat hanya untuk daftar origin domain yang tertera pada `CORS_ORIGIN`.
* **Rate Limiting:**
  - Global: 300 req / 15 menit per IP.
  - Login: 10 req / 15 menit per IP.
  - Register: 5 req / 1 jam per IP.
  - Chat Messages: 20 pesan / menit per pengguna.
* **Maintenance Mode:** Middleware `maintenance.middleware.js` mengembalikan 503 saat pemeliharaan aktif, namun tetap meloloskan probe health check dan webhook pembayaran.
* **Sentry Scrubber:** Fungsi `scrubObject` pada `backend/src/config/sentry.js` menyensor field `password`, `token`, `nik`, dan nomor rekening sebelum dikirim ke dashboard pemantau.

### 4. Analisis Risiko Keamanan & Mitigasi
1. **IDOR (Insecure Direct Object Reference):** **TERATASI (RISIKO NOL)**. Seluruh 26 endpoint ber-parameter `:id` telah diuji menggunakan token penyerang dan terbukti menolak akses ilegal dengan kode 403 atau 404 (`backend/tests/security/security_automated.test.js`).
2. **Mass Assignment:** **TERATASI**. Pembuatan transaksi, registrasi, dan update profil hanya mengekstrak field yang diizinkan melalui *whitelist destructuring*. Parameter berbahaya seperti `role: 'ADMIN'` atau `balance: 999999` diabaikan total.
3. **Injeksi SQL:** **TERATASI**. Seluruh interaksi database menggunakan Prisma Query Engine dengan prepared statements berparameter.
4. **Kebocoran Kredensial:** **TERATASI**. Hasil pemindaian regex (`scan_secrets.js`) pada seluruh kode sumber menunjukkan 0 kebocoran private key, API key, atau kata sandi live.

---

# 9. Mobile: Inventaris Halaman

Seluruh antarmuka aplikasi dibangun menggunakan arsitektur Neo-Brutalist dengan border tegas hitam 2px, bayangan tebal offset 4px, dan tipografi Space Grotesk.

| No | Nama Halaman | Path File | Rute GoRouter | Fungsi | Integrasi Data | State Management | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| 1 | **LoginPage** | `features/auth/presentation/pages/login_page.dart` | `/login` | Masuk akun pembeli/penjual/admin | API Nyata (`/api/auth/login`) | `AuthBloc` | ✅ BERFUNGSI |
| 2 | **RegisterPage** | `features/auth/presentation/pages/register_page.dart` | `/register` | Registrasi akun baru | API Nyata (`/api/auth/register`) | `AuthBloc` | ✅ BERFUNGSI |
| 3 | **ForgotPasswordPage** | `features/auth/presentation/pages/forgot_password_page.dart` | `/forgot-password` | Permintaan reset kata sandi | API Nyata (`/api/auth/forgot-password`)| `AuthBloc` | ✅ BERFUNGSI |
| 4 | **ResetPasswordPage** | `features/auth/presentation/pages/reset_password_page.dart` | `/reset-password` | Reset password via token email | API Nyata (`/api/auth/reset-password`) | `AuthBloc` | ✅ BERFUNGSI |
| 5 | **MainWrapper** | `features/home/presentation/pages/main_wrapper.dart` | `/home` | Shell navigasi tab beranda | Internal GoRouter State | - | ✅ BERFUNGSI |
| 6 | **HomePage** | `features/home/presentation/pages/home_page.dart` | Tab Beranda | Saldo, riwayat aktif, quick action | API Nyata (`/wallet`, `/transactions`) | `WalletCubit`, `TransactionCubit` | ✅ BERFUNGSI |
| 7 | **NotificationPage**| `features/home/presentation/pages/notification_page.dart`| `/notifications` | Kotak masuk notifikasi & tandai baca | API Nyata (`/api/notifications`) | `NotificationCubit` | ✅ BERFUNGSI |
| 8 | **TopUpScreen** | `features/wallet/presentation/pages/top_up_screen.dart` | `/topup` | Pembuatan intent deposit saldo | API Nyata (`/api/wallet/topups`) | `WalletCubit` | ✅ BERFUNGSI |
| 9 | **DetailPembayaran**| `features/wallet/presentation/pages/detail_pembayaran_screen.dart` | `/detail-pembayaran` | Tampilan QRIS & VA dengan polling | API Nyata (`/topups/:id` polling) | `WalletCubit` | ✅ BERFUNGSI |
| 10 | **TarikDanaScreen** | `features/wallet/presentation/pages/tarik_dana_screen.dart` | `/tarik-dana` | Penarikan saldo ke rekening bank | API Nyata (`/wallet/withdrawals`) | `WalletCubit` | ✅ BERFUNGSI |
| 11 | **MutasiScreen** | `features/wallet/presentation/pages/mutasi_screen.dart` | `/riwayat-mutasi` | Riwayat buku besar (*ledger history*) | API Nyata (`/api/wallet/ledger`) | `WalletCubit` | ✅ BERFUNGSI |
| 12 | **BuatRoomScreen** | `features/transaction/presentation/pages/buat_room_screen.dart` | `/buat-room` | Inisiasi transaksi escrow baru | API Nyata (`/auth/search-opponent`) | `TransactionCubit` | ✅ BERFUNGSI |
| 13 | **InputKodeScreen** | `features/transaction/presentation/pages/input_kode_screen.dart` | `/input-kode` | Masuk ke transaksi via kode 8-digit | API Nyata (`/transactions/code/:code`) | `TransactionCubit` | ✅ BERFUNGSI |
| 14 | **KalkulatorScreen**| `features/transaction/presentation/pages/kalkulator_screen.dart` | `/kalkulator` | Simulasi fee platform transparan | API Nyata (`/api/config/public`) | `TransactionCubit` | ✅ BERFUNGSI |
| 15 | **RiwayatScreen** | `features/transaction/presentation/pages/riwayat_screen.dart` | `/riwayat` | Daftar transaksi terfilter status | API Nyata (`/api/transactions`) | `TransactionCubit` | ✅ BERFUNGSI |
| 16 | **TxDetailPage** | `features/transaction/presentation/pages/transaction_detail_page.dart` | `/transaction/:id` | Detail escrow, bayar, kirim, komplain | API Nyata (`/api/transactions/:id`)| `TransactionCubit`, `DisputeCubit` | ✅ BERFUNGSI |
| 17 | **DisputeDetailPage**| `features/dispute/presentation/pages/dispute_detail_page.dart` | `/dispute/:id` | Status investigasi & upload bukti | API Nyata (`/api/disputes/:id`) | `DisputeCubit` | ✅ BERFUNGSI |
| 18 | **ChatRoomPage** | `features/chat/presentation/pages/chat_room_page.dart` | `/chat/:transactionId` | Chat real-time Socket.IO antar pihak | WebSocket + REST API | `ChatBloc`, `SocketService` | ✅ BERFUNGSI |
| 19 | **AiAssistantScreen**| `features/chat/presentation/pages/ai_assistant_screen.dart` | `/ai-assistant` | Panduan interaktif asisten AI | Data Simulasi Lokal (*Mock*) | Local State | 🧪 MOCK/DUMMY |
| 20 | **KycScreen** | `features/settings/presentation/pages/kyc_screen.dart` | `/kyc` | Unggah foto KTP, selfie & NIK | API Nyata (`/kyc`, `/files`) | `KycCubit` | ✅ BERFUNGSI |
| 21 | **EditProfileScreen**| `features/settings/presentation/pages/edit_profile_screen.dart` | `/edit-profile` | Perubahan nama lengkap profil | API Nyata (`/api/auth/profile`) | `AuthBloc` | ✅ BERFUNGSI |
| 22 | **SecurityScreen** | `features/settings/presentation/pages/security_screen.dart` | `/security` | Ubah password & cabut semua sesi | API Nyata (`/auth/password`, `logout-all`)| `AuthBloc` | ✅ BERFUNGSI |
| 23 | **HelpCenterScreen**| `features/settings/presentation/pages/help_center_screen.dart` | `/help-center` | Hubungi CS via WhatsApp resmi | Dynamic URL Launcher | - | ✅ BERFUNGSI |
| 24 | **LegalScreen** | `features/settings/presentation/pages/legal_screen.dart` | `/legal` | Informasi Syarat & Ketentuan | Teks Statis dengan Disclaimer Banner | - | ⚠️ PARSIAL |
| 25 | **AdminMainWrapper**| `features/admin/presentation/pages/admin_main_wrapper.dart` | Shell `/admin` | Navigasi bawah konsol administrator | Internal GoRouter State | - | ✅ BERFUNGSI |
| 26 | **AdminDashboard** | `features/admin/presentation/pages/admin_dashboard_screen.dart`| `/admin/dashboard`| Metrik volume & grafik fl_chart | API Nyata (`/api/admin/metrics`) | `AdminCubit` | ✅ BERFUNGSI |
| 27 | **AdminDispute** | `features/admin/presentation/pages/admin_dispute_screen.dart` | `/admin/dispute` | Moderasi & putusan sengketa escrow | API Nyata (`/api/admin/disputes`) | `AdminCubit` | ✅ BERFUNGSI |
| 28 | **AdminKycScreen** | `features/admin/presentation/pages/admin_kyc_screen.dart` | `/admin/kyc` | Verifikasi KTP & approval KYC | API Nyata (`/api/admin/kyc`) | `AdminCubit` | ✅ BERFUNGSI |
| 29 | **AdminWithdrawal** | `features/admin/presentation/pages/admin_withdrawal_screen.dart`| `/admin/withdrawals`| Persetujuan & eksekusi pencairan | API Nyata (`/admin/withdrawals`) | `AdminCubit` | ✅ BERFUNGSI |
| 30 | **AdminFinancial** | `features/admin/presentation/pages/admin_financial_screen.dart`| `/admin/settings/financial`| Pengaturan biaya & audit log | API Nyata (`/admin/settings`, `/audit`)| `AdminCubit` | ✅ BERFUNGSI |
| 31 | **AdminUserManage** | `features/admin/presentation/pages/admin_user_manage_screen.dart`| `/admin/settings/users` | Pencarian, pemblokiran (ban) akun | API Nyata (`/api/admin/users`) | `AdminCubit` | ✅ BERFUNGSI |
| 32 | **AdminSystem** | `features/admin/presentation/pages/admin_system_screen.dart` | `/admin/settings/system` | Pengaturan maintenance mode | API Nyata (`/api/admin/settings`) | `AdminCubit` | ✅ BERFUNGSI |

---

# 10. Mobile: Arsitektur dan Integrasi

### Struktur Clean Architecture
Aplikasi mobile menerapkan Clean Architecture dengan pembagian layer yang konsisten:
1. **Domain Layer:** Berisi `Entities` dan abstraksi interface `Repositories`. Bebas dependensi eksternal.
2. **Data Layer:** Berisi `Models` (JSON deserialization), `DataSources`, dan implementasi konkret `Repositories` yang memanfaatkan `ApiService` dan `SocketService`.
3. **Presentation Layer:** Berisi `BLoC` / `Cubit` (state management) dan `Pages/Widgets` antarmuka Neo-Brutalist.

### Daftar State Management BLoC & Cubit
* **`AuthBloc`**: Mengelola status autentikasi (`AuthInitial`, `AuthAuthenticated`, `AuthUnauthenticated`, `AuthSessionExpired`).
* **`TransactionCubit`**: Mengelola daftar transaksi, pencarian kode unik, pembuatan room, stepper status transaksi, dan pengunggahan bukti resi.
* **`WalletCubit`**: Mengelola saldo dompet, mutasi buku besar, pembuatan invoice top-up (polling status QRIS), rekening bank tersimpan, dan permintaan penarikan dana.
* **`DisputeCubit`**: Menangani pembukaan sengketa transaksi dan pengunggahan bukti komplain tambahan.
* **`ChatBloc`**: Mengelola penerimaan dan pengiriman pesan obrolan real-time via Socket.IO, riwayat terpaginasi kursor, serta indikator pesan dibaca.
* **`NotificationCubit`**: Mengelola unread badge count, daftar inbox notifikasi, dan event tandai terbaca.
* **`KycCubit`**: Mengelola formulir pengajuan identitas KYC (integrasi image picker, image cropper, dan enkripsi pengiriman).
* **`AdminCubit`**: Mengelola seluruh operasi administratif (analitik metriks, peninjauan KYC, sengketa, persetujuan penarikan, manajemen status user, dan platform settings).

---

# 11. Kesenjangan Backend ↔ Mobile

Berdasarkan audit komparasi antara endpoint yang tersedia di backend dan pemanggilan di mobile repository:
* **Status Kesesuaian: 100% SESUAI (MATCH)**.
* Seluruh endpoint yang dibutuhkan oleh layar mobile telah tersedia di backend dengan struktur path, HTTP method, dan skema JSON yang identik.
* Penanganan format mata uang rupiah bulat (BigInt di backend diserialisasi ke integer/number aman di JSON) telah ditangani secara seragam melalui utilitas `backend/src/utils/money.js` dan `mobile/lib/core/utils/currency_formatter.dart`.
* Tidak ada pemanggilan API palsu atau *phantom endpoints*. Rute lama yang telah dihapus seperti `/api/wallet/topup` dan `/api/wallet/withdraw` telah ditutup secara konsisten dengan kode HTTP 410 Gone.

---

# 12. Kualitas Kode dan Testing

### Hasil Pengujian Otomatis
1. **Backend Unit & Integration Tests**:
   - `backend/tests/unit/`: 5 test suite, **42 / 42 passed (100%)**.
   - `backend/tests/finance/`: Uji konkurensi, idempotensi, integritas saldo, dan property testing, **100% passed**.
   - `backend/tests/security/`: Uji sapu IDOR 26 endpoint, mass assignment, SQL injection, Helmet, CORS, **22 / 22 passed**.
   - `backend/tests/e2e/`: Uji siklus hidup penuh (a s.d. h), **100% passed**.
2. **Mobile Tests**:
   - `mobile/test/core/`: Formatter, accessibility (touch target >= 48dp), ApiService token concurrency.
   - `mobile/test/features/`: Seluruh Cubit (Auth, Transaction, Wallet, Dispute, Chat, Notification, KYC, Admin).
   - `mobile/test/config/routes/`: Route guard & RBAC tests (mencegah user non-admin mengakses `/admin/*`).
   - Total uji mobile: **194 / 194 passed (100%)**.

### Audit Temuan Kode
* **Komentar TODO / FIXME / HACK**: **0 TEMUAN** pada kode produksi `backend/src/` dan `mobile/lib/`.
* **Penggunaan `console.log` dan `print()`**:
  - Backend: Terisolasi hanya pada `backend/src/providers/mail/mail.provider.js` untuk mencetak token link email saat development lokal.
  - Mobile: Seluruh logging debug dilindungi oleh kondisi `if (kDebugMode)`.
* **Hasil Linter**:
  - Backend (`eslint .`): **0 Errors, 0 Warnings** (Lolos validasi standar Airbnb/Prettier).
  - Mobile (`flutter analyze`): **0 Errors, 0 Warnings** (11 info depresiasi Radio groupValue upstream Flutter 3.32).

---

# 13. Daftar Masalah Diketahui

| ID | Deskripsi Masalah | Lokasi Berkas | Tingkat | Dampak & Rekomendasi |
| :---: | :--- | :--- | :---: | :--- |
| **ISS-01** | Dokumen Legalitas Masih Berstatus Draf Teknis | `mobile/lib/features/settings/presentation/pages/legal_screen.dart:63` | **Sedang** | Belum ditinjau konsultan hukum berlisensi. Wajib disahkan sebelum rilis publik di App Store / Play Store. |
| **ISS-02** | Layar Asisten AI Masih Berbasis Mock Lokal | `mobile/lib/features/chat/presentation/pages/ai_assistant_screen.dart:70` | **Rendah** | Respon AI masih berbasis percabangan string if-else statis. Perlu dihubungkan ke LLM API jika ingin dirilis sebagai fitur unggulan. |
| **ISS-03** | Re-entrancy PostgreSQL Advisory Lock pada Pool Koneksi Bersama | `backend/src/worker.js:43` | **Sedang** | Pada environment single-process tanpa dedicated DB connection, worker lock bersifat re-entrant. Di produksi teratasi oleh deployment container terpisah. |
| **ISS-04** | Ketergantungan Unduhan Font pada Golden Tests Headless | `mobile/test/goldens/golden_screens_test.dart` | **Rendah** | Uji golden visual membutuhkan koneksi internet untuk mengunduh font Google Fonts jika dijalankan tanpa mock offline font bundle. |
| **ISS-05** | Paket `flutter_secure_storage_macos` Discontinued Upstream | `mobile/pubspec.lock` | **Rendah** | Tidak berdampak pada build Android atau iOS. Disarankan pembaruan versi minor pada rilis berikutnya. |

---

# 14. Pemeriksaan Kebutuhan Escrow

Pemeriksaan kepatuhan fungsional terhadap standar industri platform escrow:

| Aspek Kebutuhan Escrow | Status | Bukti / Catatan |
| :--- | :---: | :--- |
| **Pembayaran Terverifikasi Gateway** | ✅ | Xendit QRIS & Virtual Account terhubung via webhook bertanda tangan (`topup.service.js:122`). |
| **Dana Tertahan Aman (*Escrow Hold*)** | ✅ | Kolom `heldAmount` pada `Transaction` dan entri buku besar `ESCROW_HOLD` (`escrow.service.js:112`). |
| **Rilis Dana ke Penjual (*Release*)** | ✅ | CAS update status dan transfer dana atomik ke saldo penjual (`escrow.service.js:154`). |
| **Pengembalian Dana (*Refund*)** | ✅ | Pengembalian 100% dana escrow ke saldo pembeli jika transaksi dibatalkan / sengketa (`escrow.service.js:198`). |
| **Sengketa & Keputusan Admin** | ✅ | Model `Dispute`, bukti `DisputeEvidence`, dan endpoint resolusi admin (`admin.dispute.controller.js:68`). |
| **Pelepasan Otomatis (*Auto-Release*)**| ✅ | Worker cron `runAutoRelease` melepaskan dana setelah batas waktu `autoReleaseAt` lampau (`worker.js:78`). |
| **Buku Besar Finansial (*Ledger*)** | ✅ | Model `LedgerEntry` double-entry dengan `idempotencyKey` unik dan audit `reconcileDaily` (`ledger.service.js`). |
| **Verifikasi Identitas (KYC)** | ✅ | Model `KycSubmission`, NIK terenkripsi AES-256-GCM, dan syarat wajib penarikan dana (`kyc.service.js`). |
| **Rekening Bank Penarikan** | ✅ | Model `BankAccount` terenkripsi dan verifikasi penarikan dana admin (`withdrawal.service.js`). |
| **Notifikasi Push Real-time** | ✅ | Integrasi Firebase Cloud Messaging (FCM) dan inbox notifikasi dalam aplikasi (`notification.service.js`). |
| **Rate Limiting & Anti-Abuse** | ✅ | Pembatasan frekuensi IP pada login, register, payment, chat, dan global (`rateLimit.middleware.js`). |
| **Observabilitas & Kesiapan Rilis** | ✅ | Prometheus `/metrics`, Sentry error tracking, Dockerfile multi-stage, Runbook, dan CI pipeline. |
| **Konsol Administrator (Admin Panel)** | ✅ | Panel admin mobile lengkap (Dashboard, Dispute, KYC, Settings, Users, Withdrawals) dengan RBAC. |

---

# 15. Pertanyaan Terbuka

1. **Model Bisnis Biaya Platform (Platform Fee):**  
   Pengaturan default saat ini adalah `fee_percent: 2%` dan `fee_min: Rp 1.000` dengan pembagian biaya `SPLIT` (50% pembeli, 50% penjual). Apakah skema pembagian ini sudah final untuk peluncuran publik?
2. **Kemitraan Payment Gateway & Izin PJP:**  
   Apakah entitas legal Rekber telah mengantongi izin Payment Gateway / Mitra Penyelenggara Jasa Pembayaran (PJP) dari Bank Indonesia untuk mengoperasikan rekening penampung dana escrow publik?
3. **Penyimpanan Dokumen KYC:**  
   Berdasarkan UU PDP No. 27/2022, berapa lama masa retensi dokumen KTP dan foto selfie pengguna yang ditolak (`REJECTED`) sebelum dihapus permanen oleh background worker?
4. **Kebijakan Batas Closed Beta:**  
   Apakah batas closed beta disepakati pada maksimum transaksi Rp 2.000.000 per transaksi dan penarikan harian Rp 5.000.000 sesuai panduan `docs/CHECKLIST_RILIS.md`?
5. **Rencana Fitur AI Assistant:**  
   Apakah layar `AiAssistantScreen` akan diintegrasikan dengan API Gemini / Claude untuk layanan bantuan otomatis, atau akan disembunyikan sementara pada rilis versi 1.0?

---
*Laporan ini disusun secara independen berdasarkan audit kode aktual pada repositori Rekber.*
