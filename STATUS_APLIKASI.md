# LAPORAN AUDIT TEKNIS INDEPENDEN: APLIKASI REKBER (ESCROW PLATFORM)

> **Dokumen Audit Teknis & Status Kesiapan Aplikasi**  
> **Tanggal Audit:** 21 November 2026  
> **Auditor:** Senior Technical Auditor & Software Architect  
> **Target Proyek:** Rekber (Escrow Platform - Backend Express/Prisma + Mobile Flutter)  
> **Tipe Dokumen:** Laporan Audit Tunggal (*Single Source of Truth*)  
> **File:** `STATUS_APLIKASI.md`

---

## DAFTAR ISI
1. [Ringkasan Eksekutif](#1-ringkasan-eksekutif)
2. [Struktur Proyek](#2-struktur-proyek)
3. [Tech Stack dan Dependensi](#3-tech-stack-dan-dependensi)
4. [Environment dan Cara Menjalankan](#4-environment-dan-cara-menjalankan)
5. [Database](#5-database)
6. [Backend: Detail Per Endpoint](#6-backend-detail-per-endpoint)
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
Rekber adalah platform rekening bersama (*automated escrow platform*) yang dirancang untuk mengamankan transaksi jual-beli online antara pembeli (*buyer*) dan penjual (*seller*) di Indonesia, khususnya untuk produk digital (akun game, voucher, jasa joki/desain) dan barang fisik bernilai tinggi. Sistem bertujuan bertindak sebagai penengah tepercaya (*trusted middleman*) yang menahan dana pembayaran pembeli secara aman hingga barang/jasa diverifikasi telah diterima sesuai deskripsi, sebelum dana dilepaskan ke penjual atau dikembalikan kepada pembeli jika terjadi pembatalan/sengketa.

### Perkiraan Persentase Kelengkapan
* **Backend (Node.js + Express + Prisma + PostgreSQL): 45%**  
  *Alasan:* Arsitektur dasar Express, Prisma Client v7, otentikasi JWT, CRUD transaksi dasar, dan atomic balance lock pada transisi status sudah dibuat. Namun, tidak ada integrasi payment gateway riil, tidak ada tabel buku besar (*financial ledger*), tidak ada model rekening bank, tidak ada fitur bukti pengiriman, serta tidak ada logika resolusi sengketa admin.
* **Mobile (Flutter Neo-Brutalist): 40%**  
  *Alasan:* Implementasi tampilan antarmuka (*UI/UX*) neo-brutalist sangat kaya dan mencakup 32 layar (termasuk dashboard, kalkulator, room rekber, dan panel admin). Namun, lebih dari 60% layar tersebut berjalan menggunakan data tiruan (*mock/dummy data*), state lokal in-memory, atau stub tanpa logika pemanggilan backend API.
* **Integrasi End-to-End: 25%**  
  *Alasan:* Hanya alur registrasi, login, lihat profil, inisiasi transaksi room, riwayat transaksi, dan simulasi top-up/withdraw yang terhubung ujung-ke-ujung. Alur inti seperti verifikasi pembayaran otomatis (QRIS/VA), pengunggahan bukti resi, ruang chat transaksi, konfirmasi penerimaan di aplikasi mobile, dan moderasi sengketa oleh admin belum tersambung sama sekali ke backend.

### 5 Temuan Paling Penting
1. **Celah Manipulasi Saldo Kritis (*Unverified Balance Generation*)**:  
   Endpoint `/api/wallet/topup` (`backend/src/routes/wallet.routes.js:7-28`) dan `/api/wallet/withdraw` (`backend/src/routes/wallet.routes.js:31-61`) tidak terhubung ke payment gateway atau sistem bank apa pun. Pengguna yang berhasil login dapat langsung menembak API untuk menambah saldo hingga miliaran rupiah secara cuma-cuma tanpa verifikasi setoran riil.
2. **Ketiadaan Buku Besar Finansial (*Missing Financial Ledger*)**:  
   Saldo uang hanya disimpan sebagai nilai tunggal `balance Float` pada tabel `User` (`backend/prisma/schema.prisma:59`). Tidak ada tabel mutasi kredit/debit, snapshot saldo, atau jejak audit finansial. Ini sangat berbahaya untuk sistem escrow dan berisiko tinggi terhadap ketidakkonsistenan saldo atau eksploitasi race condition.
3. **Fragmentasi Backend (*Dual Architecture Trap*)**:  
   Di dalam direktori backend terdapat dua rancangan backend terpisah: Express.js + Prisma (`backend/src/`) dan Supabase SQL + Edge Functions Deno (`backend/supabase/`). Aplikasi mobile diarahkan ke server Express.js, sedangkan seluruh kode Supabase (yang memuat skema escrow lebih lengkap seperti chat, withdrawal, dan bukti transaksi) menjadi kode mati (*dead code*).
4. **Ketidakcocokan Status Transaksi (*State Machine Incompatibility*)**:  
   Enum status transaksi pada skema Prisma backend menggunakan format HURUF BESAR (`PENDING`, `PAID`, `SHIPPED`, `COMPLETED`, `CANCELLED`, `DISPUTED` pada `backend/prisma/schema.prisma:38-45`), sementara logika state machine di mobile `EscrowStateMachine` menggunakan format snake_case Supabase (`awaiting_payment`, `escrow`, `processed`, `shipped`, `completed`, `disputed`, `refunded`, `cancelled` pada `mobile/lib/features/transaction/domain/services/escrow_state_machine.dart:32-90`).
5. **Panel Admin dan Ruang Chat 100% Mockup / Stub**:  
   Seluruh fitur ruang chat interaktif (`ChatRoomPage`), asisten AI (`AiAssistantScreen`), dan 9 layar moderasi Admin (Dashboard, Sengketa, KYC Approval, User Ban, Financial Controls) di mobile hanyalah tampilan mockup statis dengan dialog tiruan (`SnackBar`) tanpa endpoint backend pendukung sama sekali.

---

# 2. Struktur Proyek

### Pohon Direktori Backend (Level 2-3)
```text
backend/
├── package.json               # Konfigurasi dependensi npm dan skrip
├── package-lock.json          # Lockfile dependensi backend
├── prisma.config.ts           # Konfigurasi Prisma v7
├── test-api.ps1               # Skrip pengujian integrasi manual (PowerShell)
├── verify-db.js               # Skrip pengecekan koneksi & integritas DB
├── prisma/
│   ├── schema.prisma          # Skema model database Prisma (User, Transaction)
│   └── seed.js                # Data awal untuk admin, buyer, seller, user
├── src/
│   ├── app.js                 # Inisialisasi Express, middleware global, router
│   ├── server.js              # Entrypoint server Express & koneksi Prisma
│   ├── config/
│   │   ├── index.js           # Konfigurasi environment (JWT, PORT, Bcrypt)
│   │   └── prisma.js          # Instansiasi PrismaClient dengan PrismaPg adapter
│   ├── controllers/
│   │   ├── auth.controller.js # Handler HTTP endpoint otentikasi & user
│   │   └── transaction.controller.js # Handler HTTP endpoint transaksi rekber
│   ├── middlewares/
│   │   ├── auth.middleware.js # Verifikasi JWT & otorisasi role (USER/ADMIN)
│   │   ├── error.middleware.js# Global error handling & ApiError class
│   │   └── validate.middleware.js # Middleware pengecekan express-validator
│   ├── routes/
│   │   ├── auth.routes.js     # Definisi route /api/auth/*
│   │   ├── index.js           # Aggregator utama route /api/*
│   │   ├── transaction.routes.js # Definisi route /api/transactions/*
│   │   └── wallet.routes.js   # Definisi route /api/wallet/* (topup & withdraw)
│   ├── services/
│   │   ├── auth.service.js    # Logika bisnis registrasi, login, pencarian lawan
│   │   └── transaction.service.js # Logika bisnis escrow & atomic state machine
│   └── validators/
│       ├── auth.validator.js  # Aturan validasi input auth
│       └── transaction.validator.js # Aturan validasi input transaksi
└── supabase/                  # [DEAD CODE / UNUSED BY RUNNING APP]
    ├── config.toml            # Konfigurasi lokal Supabase CLI
    ├── seed.sql               # Data awal Supabase
    ├── functions/             # Deno Edge Functions (create-tx, payment, withdraw)
    └── migrations/
        └── 001_initial_schema.sql # Skema PostgreSQL Supabase (8 tabel)
```

### Pohon Direktori Mobile (Level 2-3)
```text
mobile/
├── pubspec.yaml               # Konfigurasi paket & asset Flutter
├── pubspec.lock               # Lockfile dependensi Flutter
├── lib/
│   ├── main.dart              # Entrypoint Flutter, inisialisasi Firebase & DI
│   ├── app.dart               # Root MaterialApp, MultiBlocProvider, GoRouter
│   ├── injection_container.dart # Service locator (GetIt)
│   ├── config/
│   │   └── routes/
│   │       └── app_router.dart # Konfigurasi GoRouter (32 route)
│   ├── core/
│   │   ├── constants/         # AppColors, AppDimensions, ApiConstants
│   │   ├── errors/            # Failure & Exception classes
│   │   ├── services/          # ApiService (HTTP client), MockDataService, NotificationService
│   │   ├── theme/             # Styling tema brutalist & tipografi
│   │   ├── utils/             # CurrencyFormatter, DateFormatter
│   │   └── widgets/           # BrutalistButton, BrutalistCard, BrutalSkeleton, dll.
│   └── features/
│       ├── admin/presentation/pages/ # 9 layar panel admin (Dashboard, Dispute, KYC, dll.)
│       ├── auth/              # BLoC, User Model, User Entity, Login, Register, Lupa Email
│       ├── chat/              # ChatRoomPage, AiAssistantScreen, ChatMessageEntity
│       ├── home/              # HomePage, MainWrapper (BottomNav), NotificationPage
│       ├── product/           # ProductEntity (Domain only, no UI/API)
│       ├── settings/          # SettingsPage, EditProfile, KycScreen, Security, Legal
│       ├── transaction/       # BuatRoom, InputKode, Kalkulator, Riwayat, Detail, StateMachine
│       └── wallet/            # TopUpScreen, DetailPembayaran, TarikDana, WalletEntity
└── test/
    └── widget_test.dart       # Default test template (gagal/outdated)
```

### Jumlah File dan Estimasi Baris Kode
| Komponen | Jumlah File | Estimasi Baris Kode | Keterangan |
| :--- | :--- | :--- | :--- |
| **Backend Source** (`src/`, `prisma/`, `supabase/`) | 27 file | 2.410 baris | Termasuk Express JS, Prisma schema/seed, dan Supabase SQL/TS |
| **Backend Total** (termasuk config/script) | 32 file | ~2.500 baris | Tidak menghitung `node_modules` |
| **Mobile Source** (`lib/`, `test/`) | 70 file | 11.011 baris | Seluruh kode Dart aplikasi Flutter |
| **Mobile Total** (termasuk runner config) | 85 file | ~11.500 baris | Tidak menghitung `.dart_tool` dan build folder |

### Status Git
* **Branch aktif:** `main` (sinkron dengan `origin/main`).
* **Status working directory:** Bersih (*Clean*), hanya ada file untracked `DOKUMENTASI.md` dan pembuatan `STATUS_APLIKASI.md`. Tidak ada modifikasi kode yang dilakukan.
* **10 Commit Terakhir:**
  1. `c7e3402` docs: add comprehensive tech stack section to README
  2. `aba0bcb` feat: implement wallet withdrawal and transaction features across mobile and backend services
  3. `4e3ac67` feat: implement modular feature architecture and foundational auth, transaction, and AI assistant screens
  4. `4c2f3d6` feat: implement modular architecture with Auth BLoC, brutalist UI components, and initial feature module scaffolding
  5. `b30cbd8` feat: scaffold core features including dashboard, authentication, transaction management, and admin views with neo-brutalist UI components.
  6. `ccc7607` feat: implement core auth architecture, mock data services, and administrative dashboard screens
  7. `433ef9e` feat: implement core mobile application modules, admin dashboard features, and backend seed script
  8. `3ee5005` feat: implement AI assistant feature and scaffold core application modules and UI components
  9. `7d66cc7` feat: initialize app core architecture, base features, and AI assistant screen implementation
  10. `fa8f248` feat: initialize project foundation with brutalist UI components and backend service scaffold

---

# 3. Tech Stack dan Dependensi

### Backend Dependencies (`backend/package.json`)
| Nama Paket | Versi Terpasang | Fungsi | Status Pemakaian di Kode | Bukti File Path |
| :--- | :--- | :--- | :--- | :--- |
| `express` | ^5.2.1 | Web framework HTTP server | **DIPAKAI** | `backend/src/app.js:8` |
| `@prisma/client` | ^7.8.0 | ORM database client | **DIPAKAI** | `backend/src/config/prisma.js:10` |
| `@prisma/adapter-pg`| ^7.8.0 | Adapter PostgreSQL driver Prisma v7 | **DIPAKAI** | `backend/src/config/prisma.js:11` |
| `pg` | ^8.20.0 | Driver native PostgreSQL | **DIPAKAI** (diperlukan adapter) | `backend/package.json:34` |
| `bcryptjs` | ^3.0.3 | Hashing password (salt rounds 12) | **DIPAKAI** | `backend/src/services/auth.service.js:8` |
| `jsonwebtoken` | ^9.0.3 | Pembuatan & verifikasi token JWT | **DIPAKAI** | `backend/src/middlewares/auth.middleware.js:10` |
| `express-validator`| ^7.3.2 | Sanitasi & validasi request body/params | **DIPAKAI** | `backend/src/middlewares/validate.middleware.js:14` |
| `cors` | ^2.8.6 | Konfigurasi CORS header | **DIPAKAI** | `backend/src/app.js:9,30` |
| `helmet` | ^8.1.0 | Keamanan HTTP header | **DIPAKAI** | `backend/src/app.js:10,26` |
| `morgan` | ^1.10.1 | Logger HTTP request | **DIPAKAI** | `backend/src/app.js:11,38` |
| `dotenv` | ^17.4.2 | Pemuatan environment variables | **DIPAKAI** | `backend/src/config/index.js:7` |
| `prisma` | ^7.8.0 | Prisma CLI tooling | **DIPAKAI** (Dev CLI) | `backend/package.json:35` |
| `nodemon` (dev) | ^3.1.14 | Hot-reload development | **DIPAKAI** (`npm run dev`) | `backend/package.json:7,38` |

### Mobile Dependencies (`mobile/pubspec.yaml`)
| Nama Paket | Versi | Fungsi | Status Pemakaian di Kode | Bukti File Path / Catatan |
| :--- | :--- | :--- | :--- | :--- |
| `flutter_bloc` | ^8.1.6 | State management BLoC | **DIPAKAI** | `mobile/lib/app.dart:2,16` |
| `bloc` | ^8.1.4 | Core library BLoC | **DIPAKAI** | `mobile/lib/features/auth/presentation/bloc/auth_bloc.dart:2` |
| `equatable` | ^2.0.7 | Perbandingan kesetaraan objek | **DIPAKAI** | `mobile/lib/features/auth/presentation/bloc/auth_state.dart:1` |
| `get_it` | ^7.7.0 | Service locator / Dependency injection | **DIPAKAI** | `mobile/lib/injection_container.dart:1,7` |
| `go_router` | ^14.0.0 | Declarative routing & navigation | **DIPAKAI** | `mobile/lib/config/routes/app_router.dart:2,41` |
| `http` | ^1.6.0 | HTTP Client panggilan API backend | **DIPAKAI** | `mobile/lib/core/services/api_service.dart:4,19` |
| `flutter_secure_storage`| ^9.2.4| Penyimpanan token JWT terenkripsi | **DIPAKAI** | `mobile/lib/core/services/api_service.dart:5,20` |
| `google_fonts` | ^6.2.1 | Custom typography (Space Grotesk) | **DIPAKAI** | `mobile/lib/features/auth/presentation/pages/login_page.dart:4` |
| `shimmer` | ^3.0.0 | Skeleton loading animation | **DIPAKAI** | `mobile/lib/core/widgets/brutal_skeleton.dart:2` |
| `intl` | ^0.19.0 | Format mata uang Rupiah | **DIPAKAI** | `mobile/lib/core/utils/currency_formatter.dart:1,8` |
| `dartz` | ^0.10.1 | Functional programming (`Either`, `Left`, `Right`) | **DIPAKAI PARSIAL** | Hanya di `escrow_state_machine.dart:9` |
| `firebase_core` | ^4.9.0 | Inisialisasi Firebase | **DIPAKAI** | `mobile/lib/main.dart:3,27` |
| `firebase_auth` | ^6.5.1 | Otentikasi Firebase Email/Password | **DIPAKAI PARSIAL** | `mobile/lib/features/auth/presentation/bloc/auth_bloc.dart:3` |
| `firebase_messaging`| ^16.2.2| Push notification FCM | **DIPAKAI** | `mobile/lib/core/services/notification_service.dart:2,11` |
| `flutter_local_notifications`| ^21.0.0| Menampilkan push notifikasi lokal | **DIPAKAI** | `mobile/lib/core/services/notification_service.dart:3,12` |
| `timeago` | ^3.7.0 | Format waktu relatif ("2 jam lalu") | **DIPAKAI PARSIAL** | Hanya 2 referensi import |
| `supabase_flutter` | ^2.8.1 | Supabase Client SDK | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tidak ada `Supabase.initialize` di seluruh `lib/` |
| `injectable` | ^2.5.0 | Generator Dependency Injection | ❌ **TERPASANG TIDAK DIGUNAKAN** | Injeksi GetIt dibuat manual di `injection_container.dart` |
| `shared_preferences`| ^2.5.5 | Local key-value storage | ❌ **TERPASANG TIDAK DIGUNAKAN** | Penyimpanan token memakai `flutter_secure_storage` |
| `image_picker` | ^1.1.2 | Pemilihan gambar dari kamera/galeri | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tombol upload di KYC & Edit Profil hanya stub/komentar |
| `image_cropper` | ^12.2.1| Pemotongan gambar | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tidak pernah di-import di `lib/` |
| `fl_chart` | ^1.2.0 | Diagram/Grafik finansial | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tidak ada chart di Admin atau Home |
| `qr_flutter` | ^4.1.0 | Render QR Code untuk QRIS | ❌ **TERPASANG TIDAK DIGUNAKAN** | Layar QRIS hanya memakai text string mock |
| `flutter_svg` | ^2.0.10+1| Render SVG image | ❌ **TERPASANG TIDAK DIGUNAKAN** | Asset gambar memakai PNG (`assets/images/`) |
| `cached_network_image`| ^3.4.1| Cache gambar URL | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tidak di-import di kode |
| `lottie` | ^3.1.2 | Animasi JSON Lottie | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tidak di-import di kode |
| `uuid` | ^4.5.1 | Generator UUID Dart | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tidak di-import di `lib/` |
| `url_launcher` | ^6.3.1 | Buka URL/WhatsApp eksternal | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tombol WA di help center hanya komentar kosong |
| `share_plus` | ^7.2.2 | Bagikan kode transaksi ke apps lain | ❌ **TERPASANG TIDAK DIGUNAKAN** | Tombol salin hanya memakai `Clipboard.setData` |
| `cupertino_icons` | ^1.0.8 | Icon iOS | ❌ **TERPASANG TIDAK DIGUNAKAN** | Semua icon menggunakan `Icons.*` Material |

### Analisis Tumpang Tindih Otentikasi (*Auth Conflict Analysis*)
Pada proyek ini ditemukan 3 teknologi otentikasi yang tumpang tindih:
1. **Supabase Auth**: Dikonfigurasi di `backend/supabase/config.toml` dan `api_constants.dart`, namun **sama sekali tidak aktif** di aplikasi mobile.
2. **Firebase Auth**: Diinisialisasi di `mobile/lib/main.dart:27` dan dipanggil di `mobile/lib/features/auth/presentation/bloc/auth_bloc.dart:63` saat registrasi & login.
3. **Custom JWT Backend**: Dikeluarkan oleh Express API (`backend/src/services/auth.service.js:101`) menggunakan `jsonwebtoken`.

**Sumber Kebenaran (*Single Source of Truth*):**  
**Custom Backend JWT** adalah sumber kebenaran otentikasi yang sesungguhnya. Seluruh otorisasi transaksi pada endpoint Express dilindungi oleh middleware `backend/src/middlewares/auth.middleware.js:37` yang memvalidasi JWT backend, bukan Firebase Token.  
*Anomali:* Di `AuthBloc` (`mobile/lib/features/auth/presentation/bloc/auth_bloc.dart:70-74`), akun uji coba bawaan seed yang berakhiran `@rekber.com` sengaja dibuat membypass error Firebase Auth agar bisa langsung login ke backend. Akibatnya ada dependensi ganda yang rapuh: pengguna umum harus terdaftar di Firebase DAN di PostgreSQL Express secara paralel, tetapi tidak ada sinkronisasi dua arah jika password diubah.

---

# 4. Environment dan Cara Menjalankan

### Variabel Environment yang Dibutuhkan
#### Backend (`backend/.env`)
* `PORT`: Port server HTTP Express (Default: `5000`) — *STATUS: Opsional/Fallback ada*.
* `NODE_ENV`: Mode environment (`development`/`production`) — *STATUS: Opsional/Fallback ada*.
* `CORS_ORIGIN`: Domain yang diizinkan untuk CORS saat production — *STATUS: Dibutuhkan saat prod*.
* `JWT_SECRET`: Kunci rahasia untuk tanda tangan JWT — *STATUS: Belum ada di file .env. Kode memiliki fallback `'fallback-secret-change-me'` (BAHAYA)*.
* `JWT_EXPIRES_IN`: Masa berlaku token JWT (Default: `'7d'`) — *STATUS: Opsional/Fallback ada*.
* `BCRYPT_SALT_ROUNDS`: Kompleksitas salt hash password (Default: `12`) — *STATUS: Opsional/Fallback ada*.
* `DATABASE_URL`: Connection string PostgreSQL untuk Prisma (format: `postgresql://[USER]:[PASSWORD]@[HOST]:[PORT]/[DB]?schema=public`) — *STATUS: **BELUM ADA / TIDAK TERDEFINISI** (Menyebabkan crash DB)*.

#### Mobile (`mobile/lib/core/services/api_service.dart` & `api_constants.dart`)
* `ApiService.baseUrl`: Hardcoded di kode Dart (`http://localhost:5000/api` untuk web/iOS dan `http://10.0.2.2:5000/api` untuk emulator Android). Tidak menggunakan file `.env` atau `--dart-define`.
* `ApiConstants.supabaseUrl`: Berisi nilai dummy `'YOUR_SUPABASE_URL'` (tidak dipakai).
* `ApiConstants.supabaseAnonKey`: Berisi nilai dummy `'YOUR_SUPABASE_ANON_KEY'` (tidak dipakai).
* `google-services.json`: **SUDAH ADA** di `mobile/android/app/google-services.json`.
* `GoogleService-Info.plist`: **BELUM ADA** di `mobile/ios/Runner/`.

### Langkah Menjalankan Aplikasi dari Nol
#### 1. Backend
1. Pastikan PostgreSQL Server sudah berjalan dan database kosong telah dibuat (misal `rekber_db`).
2. Masuk ke folder backend: `cd backend`.
3. Buat file `.env` (saat ini belum ada contoh `.env.example`, harus dibuat manual) dengan isi:
   ```env
   PORT=5000
   NODE_ENV=development
   JWT_SECRET=[REDACTED_SECRET]
   JWT_EXPIRES_IN=7d
   DATABASE_URL=postgresql://[REDACTED_USER]:[REDACTED_PASSWORD]@localhost:5432/rekber_db?schema=public
   ```
4. Jalankan install dependensi: `npm install`.
5. Sinkronkan skema ke database: `npx prisma db push`.
6. Jalankan seed data akun pengujian: `npm run prisma:seed`.
7. Jalankan server: `npm run dev` atau `npm start`. Server berjalan di `http://localhost:5000`.

#### 2. Mobile
1. Pastikan Flutter SDK (>=3.2.0) dan Java JDK/Android Studio telah terpasang.
2. Masuk ke folder mobile: `cd mobile`.
3. Unduh dependensi: `flutter pub get`.
4. Jalankan aplikasi pada emulator atau perangkat fisik: `flutter run`.

### Hasil Percobaan Perintah Aktual
| Perintah | Hasil | Pesan Error Utama / Output |
| :--- | :--- | :--- |
| `npm install` (backend) | **SUKSES** | Added 234 packages, audited 235 packages in 17s. Ditemukan 17 vulnerabilities pada dependencies bawaan npm. |
| `npx prisma validate` (backend) | **SUKSES** | `The schema at prisma\schema.prisma is valid 🚀` |
| `npx prisma generate` (backend) | **SUKSES** | `✔ Generated Prisma Client (v7.8.0) to .\node_modules\@prisma\client in 122ms` |
| Start Server / Koneksi DB (`verify-db.js`) | ❌ **GAGAL** | `prisma:error SASL: SCRAM-SERVER-FIRST-MESSAGE: client password must be a string`. *Penyebab:* File `.env` tidak ada di backend, variabel `DATABASE_URL` bernilai undefined. |
| `flutter pub get` (mobile) | **SUKSES** | `Got dependencies!` (148 paket memiliki versi pembaruan yang tersedia). |
| `flutter analyze` (mobile) | ⚠️ **LULUS DENGAN PERINGATAN** | **11 issues found** (0 errors, 0 warnings, 11 infos). Semua berupa peringatan linter `use_build_context_synchronously` pada `edit_profile_screen.dart`, `buat_room_screen.dart`, `detail_pembayaran_screen.dart`, dan `tarik_dana_screen.dart`. |
| `flutter test` (mobile) | ❌ **GAGAL** | `Counter increments smoke test [E]` pada `test/widget_test.dart:18:5`. Expected: 1 widget text "0", Actual: 0 found. *Penyebab:* File tes masih bawaan template counter awal Flutter dan tidak pernah disesuaikan dengan kode Rekber. |

### Status Koneksi Database & Migrasi Saat Ini
* **Apakah backend bisa terhubung ke database saat ini?**  
  **TIDAK.** Karena tidak ada file `.env` di direktori `backend/`, nilai `process.env.DATABASE_URL` bernilai `undefined`, sehingga driver PostgreSQL melemparkan error SCRAM autentikasi dan server gagal menyambung ke DB.
* **Apakah migrasi sudah dibuat dan dijalankan?**  
  **BELUM.** Direktori `backend/prisma/migrations` tidak ada. Skema database Prisma belum pernah di-generate menjadi file migrasi SQL formal (`npx prisma migrate dev`).

---

# 5. Database

### Skema Prisma Lengkap (`backend/prisma/schema.prisma`)
```prisma
// =============================================================================
// REKBER (Escrow) - Prisma Schema
// =============================================================================

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
}

// =============================================================================
// MODELS
// =============================================================================

model User {
  id        String   @id @default(uuid())
  name      String
  email     String   @unique
  password  String   // Hashed with bcryptjs, never stored in plaintext
  role      Role     @default(USER)
  balance   Float    @default(0) // Virtual wallet balance in IDR
  
  firebaseUid String? @unique @map("firebase_uid")
  fcmToken    String? @map("fcm_token")

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  // Relations: A user can be a buyer or seller in many transactions
  buyerTransactions  Transaction[] @relation("BuyerTransactions")
  sellerTransactions Transaction[] @relation("SellerTransactions")

  @@map("users")
}

model Transaction {
  id              String            @id @default(uuid())
  amount          Float             // Transaction amount in IDR
  itemDescription String            @map("item_description")
  status          TransactionStatus @default(PENDING)

  // Foreign keys
  buyerId  String @map("buyer_id")
  sellerId String @map("seller_id")

  // Relations
  buyer  User @relation("BuyerTransactions", fields: [buyerId], references: [id])
  seller User @relation("SellerTransactions", fields: [sellerId], references: [id])

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("transactions")
}
```

### Riwayat Migrasi
* Direktori `backend/prisma/migrations/`: **TIDAK ADA** (Nol file migrasi).
* Satu-satunya file migrasi SQL yang ada di repositori berada di `backend/supabase/migrations/001_initial_schema.sql` (482 baris), namun file ini ditujukan untuk Supabase CLI dan **tidak terintegrasi** dengan Prisma ORM.

### Seed Data
Tersedia file `backend/prisma/seed.js` yang melakukan upsert pada 4 akun pengujian:
1. `admin@rekber.com` (Role: `ADMIN`, Saldo awal: Rp 1.000.000)
2. `buyer@rekber.com` (Role: `USER`, Saldo awal: Rp 500.000)
3. `seller@rekber.com` (Role: `USER`, Saldo awal: Rp 250.000)
4. `user@rekber.com` (Role: `USER`, Saldo awal: Rp 100.000)

### Analisis Tabel Pendukung Escrow
* **Tabel Ledger / Mutasi Saldo:** ❌ **TIDAK ADA**. Tidak ada pencatatan riwayat transaksi uang masuk/keluar.
* **Tabel Sengketa / Dispute:** ❌ **TIDAK ADA**. Sengketa hanya berupa status `DISPUTED` pada transaksi, tanpa alasan klaim, data penengah, maupun hasil investigasi.
* **Tabel Bukti Pengiriman (*Proofs*):** ❌ **TIDAK ADA**. Tidak ada tempat menyimpan nomor resi, foto bukti pengiriman, atau URL dokumen.
* **Tabel Rekening Bank / Penarikan:** ❌ **TIDAK ADA**. Penarikan dana di backend tidak menyimpan informasi nama bank, nomor rekening, atau atas nama rekening.
* **Tabel Notifikasi:** ❌ **TIDAK ADA**. Tidak ada penyimpanan inbox notifikasi di database.
* **Tabel Log Audit:** ❌ **TIDAK ADA**. Tidak ada pencatatan audit log untuk tindakan admin atau perubahan status kritis.

### Kekurangan Fatal Skema untuk Aplikasi Escrow
1. Menggunakan tipe `Float` untuk nilai moneter `amount` dan `balance`. Dalam aplikasi finansial, tipe Float rentan terhadap kesalahan pembulatan desimal (*floating point precision error*). Seharusnya menggunakan `Decimal` (Prisma) atau `BigInt`/integer sen terkecil.
2. Tidak adanya pemisahan antara *Available Balance* (saldo yang dapat ditarik) dan *Escrow/Locked Balance* (saldo yang sedang terkunci dalam transaksi berjalan).
3. Kolom `platform_fee` tidak ada pada skema transaksi, sehingga komisi platform tidak tercatat di level database.
4. Ketiadaan constraint integritas data pada transaksi, misalnya tidak ada check constraint `buyerId != sellerId` di level database (hanya diperiksa di layer service).

---

# 6. Backend: Detail Per Endpoint

Berikut adalah rincian lengkap ke-14 endpoint API yang ada di backend Express:

### 1. `GET /api/health`
* **Route & Controller:** `backend/src/app.js:48-55`
* **Auth:** Publik (Tanpa token).
* **Validasi Input:** Tidak ada.
* **Body Request:** None.
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Rekber API is running! 🚀",
    "environment": "development",
    "timestamp": "2026-11-21T11:15:00.000Z"
  }
  ```
* **Logika Bisnis:** Mengembalikan pesan status server dan timestamp ISO saat ini.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Tidak.
* **Status:** ✅ **BERFUNGSI**

---

### 2. `POST /api/auth/register`
* **Route & Controller:** `backend/src/routes/auth.routes.js:17`, `backend/src/controllers/auth.controller.js:16-30`, `backend/src/services/auth.service.js:20-53`
* **Auth:** Publik.
* **Validasi Input (`backend/src/validators/auth.validator.js:12-36`):**
  * `name`: string, notEmpty, min 2 max 100 karakter.
  * `email`: string, format email valid, dinormalisasi.
  * `password`: string, min 8 karakter, wajib mengandung huruf besar, huruf kecil, dan angka.
* **Body Request:**
  ```json
  {
    "name": "Budi Santoso",
    "email": "budi@rekber.id",
    "password": "Password123",
    "firebaseUid": "optional-uid-string",
    "fcmToken": "optional-fcm-token"
  }
  ```
* **Contoh Response Sukses (201):**
  ```json
  {
    "success": true,
    "message": "Registrasi berhasil! Silakan login.",
    "data": {
      "id": "e4b3c829-1234-4a5b-bcde-9876543210ab",
      "name": "Budi Santoso",
      "email": "budi@rekber.id",
      "role": "USER",
      "balance": 0,
      "firebaseUid": null,
      "fcmToken": null,
      "createdAt": "2026-11-21T11:15:00.000Z"
    }
  }
  ```
* **Contoh Response Error (409):**
  ```json
  {
    "success": false,
    "message": "Email sudah terdaftar. Gunakan email lain."
  }
  ```
* **Logika Bisnis:** Memeriksa keunikan email via `prisma.user.findUnique`. Menghash password dengan `bcrypt.hash(password, 12)`. Menyimpan data user baru ke tabel `users`.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Tidak.
* **Status:** ✅ **BERFUNGSI**

---

### 3. `POST /api/auth/login`
* **Route & Controller:** `backend/src/routes/auth.routes.js:21`, `backend/src/controllers/auth.controller.js:38-52`, `backend/src/services/auth.service.js:79-112`
* **Auth:** Publik.
* **Validasi Input (`backend/src/validators/auth.validator.js:41-52`):**
  * `email`: format email valid, notEmpty.
  * `password`: notEmpty.
* **Body Request:**
  ```json
  {
    "email": "budi@rekber.id",
    "password": "Password123"
  }
  ```
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Login berhasil!",
    "data": {
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "user": {
        "id": "e4b3c829-1234-4a5b-bcde-9876543210ab",
        "name": "Budi Santoso",
        "email": "budi@rekber.id",
        "role": "USER",
        "balance": 0,
        "firebaseUid": null,
        "fcmToken": null,
        "createdAt": "2026-11-21T11:15:00.000Z",
        "updatedAt": "2026-11-21T11:15:00.000Z"
      }
    }
  }
  ```
* **Contoh Response Error (401):**
  ```json
  {
    "success": false,
    "message": "Email atau password salah."
  }
  ```
* **Logika Bisnis:** Mencari user by email. Memvalidasi hash password dengan `bcrypt.compare`. Menandatangani JWT dengan payload `{ id, email, role }` berdurasi 7 hari.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Tidak.
* **Status:** ✅ **BERFUNGSI** (Catatan: Risiko rahasia fallback pada `JWT_SECRET`).

---

### 4. `POST /api/auth/forgot-email`
* **Route & Controller:** `backend/src/routes/auth.routes.js:25`, `backend/src/controllers/auth.controller.js:70-82`, `backend/src/services/auth.service.js:119-142`
* **Auth:** Publik.
* **Validasi Input (`backend/src/validators/auth.validator.js:57-66`):**
  * `name`: string, notEmpty.
  * `password`: string, notEmpty.
* **Body Request:**
  ```json
  {
    "name": "Budi Santoso",
    "password": "Password123"
  }
  ```
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Email berhasil ditemukan.",
    "data": {
      "email": "budi@rekber.id"
    }
  }
  ```
* **Contoh Response Error (401 / 404):**
  ```json
  {
    "success": false,
    "message": "Password salah."
  }
  ```
* **Logika Bisnis:** Mencari user berdasarkan nama lengkap (case-insensitive). Melakukan perulangan dan memverifikasi hash password satu per satu. Mengembalikan alamat email jika password cocok.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Tidak.
* **Status:** ⚠️ **PARSIAL / RISIKO KEAMANAN** (Memungkinkan penyerang mencari email user jika mengetahui nama dan password).

---

### 5. `GET /api/auth/me`
* **Route & Controller:** `backend/src/routes/auth.routes.js:29`, `backend/src/controllers/auth.controller.js:84-95`, `backend/src/services/auth.service.js:149-169`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input:** Header `Authorization: Bearer <token>`.
* **Body Request:** None.
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "data": {
      "id": "e4b3c829-1234-4a5b-bcde-9876543210ab",
      "name": "Budi Santoso",
      "email": "budi@rekber.id",
      "role": "USER",
      "balance": 500000,
      "firebaseUid": null,
      "fcmToken": null,
      "createdAt": "2026-11-21T11:15:00.000Z"
    }
  }
  ```
* **Logika Bisnis:** Mengambil detail data dan saldo pengguna yang sedang login berdasarkan `req.user.id`.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya (Data diri sendiri).
* **Status:** ✅ **BERFUNGSI**

---

### 6. `PUT /api/auth/profile`
* **Route & Controller:** `backend/src/routes/auth.routes.js:33`, `backend/src/controllers/auth.controller.js:97-110`, `backend/src/services/auth.service.js:177-194`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input:** ❌ Tidak ada validator middleware! Input `name` langsung diambil dari `req.body.name`.
* **Body Request:**
  ```json
  {
    "name": "Budi Santoso Baru"
  }
  ```
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Profil berhasil diperbarui.",
    "data": {
      "id": "e4b3c829-1234-4a5b-bcde-9876543210ab",
      "name": "Budi Santoso Baru",
      "email": "budi@rekber.id",
      "role": "USER",
      "balance": 500000,
      "createdAt": "2026-11-21T11:15:00.000Z"
    }
  }
  ```
* **Logika Bisnis:** Mengubah field nama pada tabel `users` untuk id `req.user.id`.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya.
* **Status:** ⚠️ **PARSIAL** (Validasi input kosong di router).

---

### 7. `GET /api/auth/search-opponent`
* **Route & Controller:** `backend/src/routes/auth.routes.js:37`, `backend/src/controllers/auth.controller.js:112-124`, `backend/src/services/auth.service.js:202-224`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input:** Pengecekan manual `if (!query) throw ApiError(400)`.
* **Query Params:** `?query=budi`
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "a1b2c3d4-...",
        "name": "Budi Gaming",
        "email": "budi_gaming@rekber.id"
      }
    ]
  }
  ```
* **Logika Bisnis:** Mencari lawan transaksi berdasarkan email atau nama persis (case-insensitive) selain akun sendiri, limit 5 pengguna.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya (`id: { not: currentUserId }`).
* **Status:** ✅ **BERFUNGSI**

---

### 8. `POST /api/auth/update-fcm`
* **Route & Controller:** `backend/src/routes/auth.routes.js:41`, `backend/src/controllers/auth.controller.js:54-68`, `backend/src/services/auth.service.js:60-65`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input:** Tidak ada validator middleware.
* **Body Request:**
  ```json
  {
    "fcmToken": "fcm_token_device_string_here"
  }
  ```
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "FCM Token berhasil diperbarui."
  }
  ```
* **Logika Bisnis:** Mengupdate kolom `fcm_token` pada user di PostgreSQL.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya.
* **Status:** ✅ **BERFUNGSI**

---

### 9. `POST /api/transactions`
* **Route & Controller:** `backend/src/routes/transaction.routes.js:23`, `backend/src/controllers/transaction.controller.js:15-50`, `backend/src/services/transaction.service.js:64-97`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input (`backend/src/validators/transaction.validator.js:11-24`):**
  * `amount`: float, minimal 1000 IDR.
  * `itemDescription`: string, min 5 max 500 karakter.
  * Controller: `sellerId` atau `buyerId` wajib ada salah satu.
* **Body Request:**
  ```json
  {
    "sellerId": "d3b07384-d113-40e1-9548-a006ef8987b2",
    "amount": 450000,
    "itemDescription": "Beli Akun Valorant Immortal Full Skin"
  }
  ```
* **Contoh Response Sukses (201):**
  ```json
  {
    "success": true,
    "message": "Transaksi escrow berhasil dibuat.",
    "data": {
      "id": "4fa89a31-0d3a-4a87-bf6b-67df76e6a123",
      "amount": 450000,
      "itemDescription": "Beli Akun Valorant Immortal Full Skin",
      "status": "PENDING",
      "buyerId": "e4b3c829-1234-4a5b-bcde-9876543210ab",
      "sellerId": "d3b07384-d113-40e1-9548-a006ef8987b2",
      "buyer": { "id": "...", "name": "Buyer Rekber", "email": "buyer@rekber.com" },
      "seller": { "id": "...", "name": "Seller Rekber", "email": "seller@rekber.com" },
      "createdAt": "2026-11-21T11:20:00.000Z",
      "updatedAt": "2026-11-21T11:20:00.000Z"
    }
  }
  ```
* **Logika Bisnis:** Menetapkan inisiator sebagai buyer atau seller. Memastikan buyerId != sellerId. Memastikan counterparty ada di DB. Menyimpan transaksi dengan status awal `PENDING`.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya.
* **Status:** ✅ **BERFUNGSI**

---

### 10. `GET /api/transactions`
* **Route & Controller:** `backend/src/routes/transaction.routes.js:27`, `backend/src/controllers/transaction.controller.js:112-124`, `backend/src/services/transaction.service.js:253-269`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input:** None.
* **Body Request:** None.
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Daftar transaksi berhasil diambil.",
    "data": [
      {
        "id": "4fa89a31-0d3a-4a87-bf6b-67df76e6a123",
        "amount": 450000,
        "itemDescription": "Beli Akun Valorant Immortal Full Skin",
        "status": "PENDING",
        "buyerId": "...",
        "sellerId": "...",
        "buyer": { "name": "Buyer Rekber", "email": "buyer@rekber.com" },
        "seller": { "name": "Seller Rekber", "email": "seller@rekber.com" },
        "createdAt": "2026-11-21T11:20:00.000Z"
      }
    ]
  }
  ```
* **Logika Bisnis:** Mengambil semua transaksi di mana user bertindak sebagai pembeli ATAU penjual, diurutkan tanggal terbaru.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya (`OR: [{ buyerId: userId }, { sellerId: userId }]`).
* **Status:** ✅ **BERFUNGSI**

---

### 11. `GET /api/transactions/:id`
* **Route & Controller:** `backend/src/routes/transaction.routes.js:31`, `backend/src/controllers/transaction.controller.js:58-74`, `backend/src/services/transaction.service.js:109-131`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input (`backend/src/validators/transaction.validator.js:47-51`):**
  * `param('id')`: Wajib berupa UUID valid.
* **Body Request:** None.
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Detail transaksi berhasil diambil.",
    "data": {
      "id": "4fa89a31-0d3a-4a87-bf6b-67df76e6a123",
      "amount": 450000,
      "itemDescription": "Beli Akun Valorant Immortal Full Skin",
      "status": "PENDING",
      "buyerId": "...",
      "sellerId": "...",
      "buyer": { "id": "...", "name": "...", "email": "..." },
      "seller": { "id": "...", "name": "...", "email": "..." }
    }
  }
  ```
* **Contoh Response Error (403):**
  ```json
  {
    "success": false,
    "message": "Anda tidak memiliki akses ke transaksi ini."
  }
  ```
* **Logika Bisnis:** Mengambil transaksi by ID. Memeriksa apakah user yang meminta adalah buyer, seller, atau role ADMIN. Jika bukan ketiganya, tolak dengan 403 Forbidden.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya.
* **Status:** ✅ **BERFUNGSI**

---

### 12. `PUT /api/transactions/:id/status`
* **Route & Controller:** `backend/src/routes/transaction.routes.js:35`, `backend/src/controllers/transaction.controller.js:88-110`, `backend/src/services/transaction.service.js:153-246`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input (`backend/src/validators/transaction.validator.js:29-42`):**
  * `param('id')`: UUID valid.
  * `body('status')`: String, in `['PENDING', 'PAID', 'SHIPPED', 'COMPLETED', 'CANCELLED', 'DISPUTED']`.
* **Body Request:**
  ```json
  {
    "status": "PAID"
  }
  ```
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Status transaksi berhasil diperbarui menjadi PAID.",
    "data": {
      "id": "4fa89a31-0d3a-4a87-bf6b-67df76e6a123",
      "status": "PAID",
      "amount": 450000,
      "buyer": { "id": "...", "name": "Buyer" },
      "seller": { "id": "...", "name": "Seller" }
    }
  }
  ```
* **Contoh Response Error (400 - Saldo Tidak Cukup):**
  ```json
  {
    "success": false,
    "message": "Saldo tidak mencukupi. Saldo Anda: Rp 100.000, Jumlah transaksi: Rp 450.000."
  }
  ```
* **Logika Bisnis:**
  1. Validasi keabsahan transisi berdasarkan map `VALID_TRANSITIONS`.
  2. Validasi otoritas peran (`buyer` vs `seller` vs `ADMIN`).
  3. Menjalankan operasi dalam transaksi basis data atomik (`prisma.$transaction`):
     - `PENDING → PAID`: Cek kecukupan saldo buyer, potong saldo buyer via `decrement: amount`.
     - `SHIPPED → COMPLETED`: Tambah saldo seller via `increment: amount`.
     - `PAID → CANCELLED`: Refund dana ke buyer via `increment: amount`.
     - Update status transaksi.
* **DB Transaction:** ✅ **YA (`prisma.$transaction`)**. **Pengecekan Kepemilikan:** ✅ **YA**.
* **Status:** ⚠️ **PARSIAL** (Sisi backend rapi, namun tidak ada alur penyelesaian sengketa admin / payout keluar, dan di mobile tombol detail transaksi tidak memanggil endpoint ini).

---

### 13. `POST /api/wallet/topup`
* **Route & Controller:** `backend/src/routes/wallet.routes.js:7-28`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input:** Pengecekan inline `isNaN(nominal) || nominal <= 0`.
* **Body Request:**
  ```json
  {
    "amount": 100000000
  }
  ```
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Top up berhasil!",
    "data": {
      "balance": 100500000
    }
  }
  ```
* **Contoh Response Error (400):**
  ```json
  {
    "success": false,
    "message": "Nominal top up tidak valid."
  }
  ```
* **Logika Bisnis:** Mengambil amount, langsung menjalankan `prisma.user.update` dengan `balance: { increment: nominal }` pada user pemohon.
* **DB Transaction:** Tidak. **Pengecekan Kepemilikan:** Ya (User mengupdate diri sendiri).
* **Status:** ⚠️ **PARSIAL / 🔴 RISIKO KRITIS** (Tidak ada integrasi payment gateway. Saldo bertambah cuma-cuma tanpa bukti pembayaran).

---

### 14. `POST /api/wallet/withdraw`
* **Route & Controller:** `backend/src/routes/wallet.routes.js:31-61`
* **Auth:** JWT terproteksi (`authenticate`).
* **Validasi Input:** Pengecekan inline `isNaN(nominal) || nominal <= 0`.
* **Body Request:**
  ```json
  {
    "amount": 50000
  }
  ```
* **Contoh Response Sukses (200):**
  ```json
  {
    "success": true,
    "message": "Penarikan berhasil!",
    "data": {
      "balance": 450000
    }
  }
  ```
* **Contoh Response Error (400):**
  ```json
  {
    "success": false,
    "message": "Saldo tidak mencukupi untuk penarikan."
  }
  ```
* **Logika Bisnis:** Mengambil data user. Cek `user.balance < nominal`. Mengurangi saldo user dengan `balance: { decrement: nominal }`.
* **DB Transaction:** ❌ **TIDAK**. **Pengecekan Kepemilikan:** Ya.
* **Status:** ⚠️ **PARSIAL / 🔴 RISIKO TINGGI** (Rentan *race condition* penarikan ganda. Tidak ada rekening bank penerima dan tidak ada instruksi transfer uang nyata).

---

# 7. Logika Inti Escrow

### State Machine Transaksi (Backend Aktual)
Implementasi state machine pada `backend/src/services/transaction.service.js:32-53` berjalan dengan aturan berikut:

| Status Asal | Status Tujuan | Pihak yang Berwenang | Kondisi & Validasi | Efek pada Saldo (*Balance Logic*) |
| :--- | :--- | :--- | :--- | :--- |
| `PENDING` | `PAID` | Pembeli (*Buyer*) | Saldo pembeli harus $\ge$ nominal transaksi | Saldo pembeli **dipotong** sejumlah nominal transaksi |
| `PENDING` | `CANCELLED` | Pembeli (*Buyer*) | Sebelum pembayaran disetor | Tidak ada perpindahan dana |
| `PAID` | `SHIPPED` | Penjual (*Seller*) | Barang/jasa telah dikirim oleh penjual | Dana tetap tertahan di escrow |
| `PAID` | `DISPUTED` | Pembeli (*Buyer*) | Pembeli mengajukan komplain setelah bayar | Dana dibekukan dalam sengketa |
| `PAID` | `CANCELLED` | Admin saja | Dibatalkan oleh Admin | Saldo **dikembalikan (*refund*)** ke pembeli |
| `SHIPPED` | `COMPLETED` | Pembeli (*Buyer*) | Pembeli mengonfirmasi penerimaan barang | Dana **dilepaskan** ke saldo penjual |
| `SHIPPED` | `DISPUTED` | Pembeli (*Buyer*) | Barang bermasalah saat tiba | Dana dibekukan dalam sengketa |
| `COMPLETED`| *(Terminal)* | - | Status akhir | Tidak ada transisi lagi |
| `CANCELLED`| *(Terminal)* | - | Status akhir | Tidak ada transisi lagi |
| `DISPUTED` | *(Terminal)* | - | Status akhir di kode backend | **KEKURANGAN BESAR**: Di backend tidak ada transisi keluar dari `DISPUTED`! |

### Alur Pembayaran (*Payment Flow*)
* **Bagaimana PENDING menjadi PAID?**  
  Di backend, perubahan dari `PENDING` ke `PAID` dilakukan murni dengan memotong saldo virtual pembeli yang ada di database. **Tidak ada integrasi payment gateway (Xendit/Midtrans)**, tidak ada penerbitan nomor Virtual Account resmi dari bank, dan tidak ada webhook gateway nyata di Express backend.
* Pada modul Supabase (`backend/supabase/functions/webhook-payment/index.ts`), terdapat kerangka mock webhook payment, namun file ini terisolasi dan tidak dipakai oleh backend Express yang berjalan.

### Alur Top-up dan Withdraw
* **Top-Up**: Di kode mobile (`DetailPembayaranScreen:60`), saat user mengklik tombol "SAYA SUDAH BAYAR", aplikasi langsung menembak `POST /api/wallet/topup`. Backend langsung menambah angka kolom `balance` user. Tidak ada pengecekan mutasi bank atau status tagihan.
* **Withdraw**: Di kode mobile (`TarikDanaScreen:53`), saat user mengklik "TARIK SEKARANG", aplikasi menembak `POST /api/wallet/withdraw`. Backend hanya mengecek `balance >= nominal` lalu mengurangi kolom `balance`. Rekening tujuan yang dipilih di UI tidak pernah dikirim ke backend, tidak ada catatan withdrawal request, dan tidak ada transfer dana keluar.

### Pelepasan Dana saat COMPLETED (*Release of Funds*)
Kode pelepasan dana berada di `backend/src/services/transaction.service.js:217-222`:
```javascript
// When buyer COMPLETES: release funds to seller
if (currentStatus === 'SHIPPED' && newStatus === 'COMPLETED') {
  await tx.user.update({
    where: { id: transaction.sellerId },
    data: { balance: { increment: transaction.amount } },
  });
}
```
* **Atomisitas:** Eksekusi di backend Express sudah **atomik** karena dibungkus di dalam `prisma.$transaction(async (tx) => { ... })`. Jika server mati di tengah proses, seluruh perubahan dibatalkan (*rollback*).
* **Double-spend:** Terlindungi di sisi backend karena transisi status di-lock ke `COMPLETED`, dan status `COMPLETED` memiliki daftar `VALID_TRANSITIONS: []` sehingga tidak dapat di-trigger dua kali.

### Alur Sengketa (*Dispute Flow*)
* **Backend:** Status `DISPUTED` dapat dipicu oleh pembeli saat status `PAID` atau `SHIPPED`. Namun, di `VALID_TRANSITIONS`, `DISPUTED` didefinisikan sebagai terminal state:
  ```javascript
  DISPUTED: [], // Terminal states — no further transitions allowed
  ```
  Artinya, backend **tidak memiliki logika untuk menyelesaikan sengketa** (misalnya melepaskan dana ke seller atau me-refund ke buyer setelah sengketa diputuskan).
* **UI Mobile:** Halaman sengketa admin (`AdminDisputeScreen:297-315`) memiliki tombol "CAIRKAN KE PENJUAL" dan "REFUND KE PEMBELI", tetapi tombol tersebut hanya menampilkan `SnackBar` ("Tindakan Berhasil Diterapkan") dan menutup modal tanpa memanggil API apa pun.

### Fitur Escrow Lainnya
* **Biaya Platform (*Platform Fee*):** Di mobile `KalkulatorScreen` dan `BuatRoomScreen` ada simulasi fee 2%, namun backend Express tidak menyimpan nilai fee di tabel `transactions`.
* **Auto-release (Timer Otomatis):** ❌ **TIDAK ADA**. Tidak ada cron job, queue worker, atau penjadwal yang otomatis menyelesaikan transaksi jika pembeli tidak merespons dalam 2x24 jam.
* **Pembatalan dan Refund:** Hanya didukung jika transaksi masih `PENDING` (batal tanpa dana) atau intervensi admin `PAID → CANCELLED` (refund).
* **Bukti Pengiriman (*Proof of Delivery*):** ❌ **TIDAK ADA** di backend Express.
* **Chat Terintegrasi:** ❌ **TIDAK ADA** di backend Express.
* **Rating & Reputasi:** ❌ **TIDAK ADA** di backend maupun mobile.

---

# 8. Autentikasi dan Keamanan

### Alur Otentikasi End-to-End
1. **Pendaftaran (*Register*)**:  
   Pengguna menginput nama, email, nomor HP, dan password di `RegisterPage`. Mobile membuat akun di Firebase Auth (`createUserWithEmailAndPassword`), kemudian mengirim payload yang sama ke backend Express `POST /api/auth/register`. Backend menyimpan user di PostgreSQL dengan password yang di-hash bcrypt 12 salt rounds.
2. **Masuk (*Login*)**:  
   Pengguna memasukkan email dan password di `LoginPage`. Mobile memverifikasi ke Firebase Auth (dilewati jika email berakhiran `@rekber.com`), lalu memanggil backend `POST /api/auth/login`. Backend memverifikasi hash bcrypt dan menerbitkan token JWT bertanda tangan HMAC-SHA256 dengan masa aktif 7 hari.
3. **Penyimpanan Token**:  
   Token JWT disimpan di memori perangkat mobile menggunakan `FlutterSecureStorage` dengan kunci `jwt_token` (`mobile/lib/core/services/api_service.dart:43`).
4. **Validasi Request**:  
   Setiap request HTTP ke route terproteksi menyertakan header `Authorization: Bearer <jwt_token>`. Middleware `authenticate` mengekstrak dan memverifikasi token sebelum menempelkan payload user ke `req.user`.

### Penegakan Role USER / ADMIN
* Middleware `authorize(...roles)` tersedia di `backend/src/middlewares/auth.middleware.js:76-94`.
* Namun, pada rute Express (`backend/src/routes/`), middleware `authorize('ADMIN')` **hampir tidak pernah digunakan** pada route publik! Seluruh route transaksi hanya menggunakan `authenticate` biasa dan memeriksa role admin secara kondisional di dalam service.
* Pada aplikasi mobile, tidak ada redirect guard GoRouter; pengguna dengan role USER dapat mengetik route `/admin/dashboard` dan UI akan merendernya.

### Evaluasi Middleware Backend
* `helmet`: Terpasang di `src/app.js:26` untuk mengamankan HTTP header dasar.
* `cors`: Dikonfigurasi di `src/app.js:30-34`. Pada mode development (`isDev`), origin dibuka untuk semua (`origin: '*'`).
* `morgan`: Logger aktif (`dev` pada development, `combined` pada production).
* `express.json`: Parser body JSON dibatasi `limit: '10mb'` (`src/app.js:41`).
* `express-validator`: Middleware `validate` (`src/middlewares/validate.middleware.js`) menangkap error dan merespons dengan HTTP 422.
* `errorHandler`: Middleware global (`src/middlewares/error.middleware.js`) menangani error Prisma (`P2002`, `P2025`) dan error custom `ApiError`. Pada mode dev, stack trace dibocorkan ke response JSON.
* **Rate Limiting:** ❌ **TIDAK ADA**. Tidak ada middleware pembatas laju request (`express-rate-limit`).

### Daftar Risiko Keamanan Ditemukan (Diurutkan dari Paling Bahaya)
1. **[KRITIS] Hardcoded Fallback JWT Secret**:  
   Di `backend/src/config/index.js:17`:
   ```javascript
   secret: process.env.JWT_SECRET || 'fallback-secret-change-me',
   ```
   Karena file `.env` tidak ada di repositori, server yang berjalan tanpa env variable akan menggunakan rahasia fallback ini. Penyerang dapat membuat token JWT palsu sendiri dengan role `ADMIN` dan ID user mana pun untuk mengambil alih seluruh akun.
2. **[KRITIS] Manipulasi Saldo Terbuka (*Arbitrary Balance Injection*)**:  
   Endpoint `POST /api/wallet/topup` menerima nilai `amount` mentah dari request body dan langsung meng-increment saldo user di database tanpa bukti pembayaran atau otorisasi admin.
3. **[TINGGI] Race Condition Penarikan Dana (*Double Withdrawal Attack*)**:  
   Pada `POST /api/wallet/withdraw` (`backend/src/routes/wallet.routes.js:44-51`), pengecekan `user.balance < nominal` dan operasi `prisma.user.update` tidak dibungkus dalam transaksi database (`$transaction`) atau row-level locking (`SELECT ... FOR UPDATE`). Penyerang dapat menembakkan 5 request penarikan paralel secara simultan untuk menarik saldo melebihi yang dimiliki.
4. **[TINGGI] Kebocoran Data & Enumerasi Pengguna pada Lupa Email**:  
   Endpoint `POST /api/auth/forgot-email` membandingkan nama dan password lalu mengembalikan alamat email lengkap. Ini dapat dieksploitasi untuk mencocokkan password list terhadap nama pengguna populer.
5. **[SEDANG] Ketiadaan Rate Limiting**:  
   Endpoint `/api/auth/login` dan `/api/auth/register` tidak memiliki proteksi brute-force login atau spam registrasi akun bot.
6. **[SEDANG] Pembocoran Stack Trace di Response**:  
   Di `backend/src/middlewares/error.middleware.js:46-48`, jika `NODE_ENV !== 'production'`, pesan error menyertakan `stack: err.stack`, membuka informasi struktur folder internal server kepada publik.

---

# 9. Mobile: Inventaris Halaman

Berikut adalah inventaris lengkap ke-32 layar yang ada pada aplikasi mobile Flutter:

| No | Nama Halaman / Screen | File Path | Route Path | Fungsi | Sumber Data | BLoC / Provider | Status Kesiapan |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `LoginPage` | `features/auth/presentation/pages/login_page.dart` | `/login` | Masuk ke akun pengguna | API Nyata (`/api/auth/login`) | `AuthBloc` | ✅ **BERFUNGSI** |
| 2 | `RegisterPage` | `features/auth/presentation/pages/register_page.dart` | `/register` | Mendaftar akun baru | API Nyata (Firebase + `/api/auth/register`) | `AuthBloc` | ✅ **BERFUNGSI** |
| 3 | `ForgotEmailPage` | `features/auth/presentation/pages/forgot_email_page.dart` | `/forgot-email` | Mencari email terdaftar via nama & password | API Nyata (`/api/auth/forgot-email`) | None (`ApiService`) | ✅ **BERFUNGSI** |
| 4 | `MainWrapper` | `features/home/presentation/pages/main_wrapper.dart` | `/home` | Shell Bottom Navigation Bar (5 tab) | Lokal Navigasi | None | ✅ **BERFUNGSI** |
| 5 | `HomePage` | `features/home/presentation/pages/home_page.dart` | `/home` (Tab 0) | Dashboard saldo, quick actions, & daftar TRX | API Nyata (`/api/transactions`, `/api/auth/me`) | `AuthBloc` | ✅ **BERFUNGSI** |
| 6 | `NotificationPage` | `features/home/presentation/pages/notification_page.dart` | `/notifications` | Daftar pemberitahuan pengguna | 🧪 Mock Data (Hardcoded list) | None | 🧪 **MOCK/DUMMY** |
| 7 | `TopUpScreen` | `features/wallet/presentation/pages/top_up_screen.dart` | `/topup` | Input nominal & pilih channel top-up | Statis Form (Navigasi ke Detail) | None | ⚠️ **PARSIAL** |
| 8 | `DetailPembayaranScreen` | `features/wallet/presentation/pages/detail_pembayaran_screen.dart` | `/detail-pembayaran` | Instruksi bayar & tombol konfirmasi | API Nyata (`/api/wallet/topup`) | None (`ApiService`) | ⚠️ **PARSIAL** |
| 9 | `TarikDanaScreen` | `features/wallet/presentation/pages/tarik_dana_screen.dart` | `/tarik-dana` | Form penarikan dana ke rekening | API Nyata (`/api/wallet/withdraw`) | `AuthBloc` | ⚠️ **PARSIAL** |
| 10 | `BuatRoomScreen` | `features/transaction/presentation/pages/buat_room_screen.dart` | `/buat-room` (Tab 2) | Pembuatan room escrow baru & generator kode | API Nyata (`/auth/search-opponent`, `/transactions`) | None (`ApiService`) | ✅ **BERFUNGSI** |
| 11 | `InputKodeScreen` | `features/transaction/presentation/pages/input_kode_screen.dart` | `/input-kode` | Bergabung ke transaksi via kode | 🧪 Mock Data (Hardcoded card) | None | 🧪 **MOCK/DUMMY** |
| 12 | `KalkulatorScreen` | `features/transaction/presentation/pages/kalkulator_screen.dart` | `/kalkulator` | Simulasi kalkulator pembagian fee 2% | Kalkulasi Offline | None | ✅ **BERFUNGSI** |
| 13 | `RiwayatScreen` | `features/transaction/presentation/pages/riwayat_screen.dart` | `/riwayat` (Tab 1) | Riwayat daftar transaksi pembeli/penjual | API Nyata (`/api/transactions`) | None (`ApiService`) | ✅ **BERFUNGSI** |
| 14 | `TransactionDetailPage` | `features/transaction/presentation/pages/transaction_detail_page.dart` | `/transaction/:id` | Detail transaksi, timeline status stepper | Extra Data / 🧪 MockDataService | None | 📄 **KERANGKA** |
| 15 | `PaymentSelectionPage` | `features/transaction/presentation/pages/payment_selection_page.dart` | *(Tidak terdaftar)* | Pemilihan metode pembayaran transaksi | 🧪 Mock Data (Mock: 2.500.000) | None | 📄 **KERANGKA (YATIM)** |
| 16 | `ChatRoomPage` | `features/chat/presentation/pages/chat_room_page.dart` | `/chat/:transactionId`, `/chat-room` | Ruang chat pembeli-penjual | 🧪 Mock Data (`_messages` in-memory) | None | 🧪 **MOCK/DUMMY** |
| 17 | `AiAssistantScreen` | `features/chat/presentation/pages/ai_assistant_screen.dart` | `/ai-assistant` (Tab 3) | Chatbot bantuan asisten AI | 🧪 Mock Data (Hardcoded if/else) | None | 🧪 **MOCK/DUMMY** |
| 18 | `SettingsPage` | `features/settings/presentation/pages/settings_page.dart` | Tab 4 (Settings) | Menu pengaturan profil, keamanan, logout | `AuthBloc` State | `AuthBloc` | ✅ **BERFUNGSI** |
| 19 | `EditProfileScreen` | `features/settings/presentation/pages/edit_profile_screen.dart` | `/edit-profile` | Perbarui nama profil pengguna | API Nyata (`/api/auth/profile`) | `AuthBloc` | ⚠️ **PARSIAL** |
| 20 | `KycScreen` | `features/settings/presentation/pages/kyc_screen.dart` | `/kyc` | Pengunggahan foto KTP & selfie | 📄 Kerangka Stub (Tombol no-op) | None | 📄 **KERANGKA** |
| 21 | `HelpCenterScreen` | `features/settings/presentation/pages/help_center_screen.dart` | `/help-center`, `/bantuan` | Accordion FAQ dan bantuan | Teks Statis (Tombol WA no-op) | None | ⚠️ **PARSIAL** |
| 22 | `SecurityScreen` | `features/settings/presentation/pages/security_screen.dart` | `/security` | Form ubah password dan PIN transaksi | 📄 Kerangka Stub (Tanpa API) | None | 📄 **KERANGKA** |
| 23 | `LegalScreen` | `features/settings/presentation/pages/legal_screen.dart` | `/legal` | Syarat, ketentuan & kebijakan privasi | Teks Statis | None | ✅ **BERFUNGSI** |
| 24 | `AdminMainWrapper` | `features/admin/presentation/pages/admin_main_wrapper.dart` | Shell `/admin/*` | Shell navigasi tab panel admin (4 tab) | Lokal Navigasi | None | ✅ **BERFUNGSI** |
| 25 | `AdminDashboardScreen` | `features/admin/presentation/pages/admin_dashboard_screen.dart` | `/admin/dashboard` | Statistik GMV, Escrow, dan aktivitas | 🧪 Mock Data (Hardcoded 450jt, 1.2M) | None | 🧪 **MOCK/DUMMY** |
| 26 | `AdminDisputeScreen` | `features/admin/presentation/pages/admin_dispute_screen.dart` | `/admin/dispute` | Daftar sengketa & tombol resolusi dana | 🧪 Mock Data (Dialog SnackBar) | None | 🧪 **MOCK/DUMMY** |
| 27 | `AdminKycScreen` | `features/admin/presentation/pages/admin_kyc_screen.dart` | `/admin/kyc` | Moderasi persetujuan dokumen identitas | 🧪 Mock Data (Dialog SnackBar) | None | 🧪 **MOCK/DUMMY** |
| 28 | `AdminSettingsScreen` | `features/admin/presentation/pages/admin_settings_screen.dart` | `/admin/settings` | Pengaturan sistem, broadcast, logout | Statis Navigasi & Dialog | None | ⚠️ **PARSIAL** |
| 29 | `AdminFinancialScreen` | `features/admin/presentation/pages/admin_financial_screen.dart` | `/admin/settings/financial` | Form batas transaksi & fee platform | 📄 Kerangka Form (Simpan SnackBar) | None | 📄 **KERANGKA** |
| 30 | `AdminUserManageScreen` | `features/admin/presentation/pages/admin_user_manage_screen.dart` | `/admin/settings/users` | Daftar & aksi pemblokiran user | 🧪 Mock Data (Loop 10 user) | None | 🧪 **MOCK/DUMMY** |
| 31 | `AdminSystemScreen` | `features/admin/presentation/pages/admin_system_screen.dart` | `/admin/settings/system` | Switch mode maintenance & log audit | 🧪 Mock Data (State lokal) | None | 🧪 **MOCK/DUMMY** |
| 32 | `AdminChatRoomScreen` | `features/admin/presentation/pages/admin_chat_room_screen.dart` | `/admin/dispute/chat/:txid` | Intervensi chat sengketa oleh admin | 🧪 Mock Data (`_messages` in-memory) | None | 🧪 **MOCK/DUMMY** |

### Peta Navigasi (`mobile/lib/config/routes/app_router.dart`)
* **Halaman Awal (*Initial Location*):** `/login`
* **Navigasi Shell Pengguna:** Menggunakan `MainWrapper` dengan bottom navigation bar untuk berpindah antara Home, Riwayat, Buat Room (FAB), AI, dan Settings.
* **Navigasi Shell Admin:** Menggunakan `StatefulShellRoute.indexedStack` (`AdminMainWrapper`) untuk berpindah antara Dashboard, Dispute, KYC, dan Settings.
* **Redirect / Auth Guard:** ❌ **TIDAK ADA**. Konfigurasi `GoRouter` tidak memiliki fungsi `redirect: (context, state) { ... }`. Pengguna yang tidak memiliki token atau pengguna biasa dapat mengetik rute `/admin/dashboard` dan UI akan langsung merendernya.

### Alur Pengguna Utama & Titik Terputus (*Broken User Flows*)
1. **Alur Transaksi Pembeli (*Buyer Escrow Flow*)**:  
   Login → Klik FAB (+) Buat Room → Cari Lawan Transaksi → Isi Nominal → Dapatkan Kode Transaksi (✅ Terhubung ke API).  
   *Titik Putus:* Saat membuka detail transaksi (`TransactionDetailPage`), tombol "Buka Chat" tidak membuka chat ID terkait, dan tombol "Konfirmasi Penerimaan Barang" (`TransactionDetailPage:396`) hanya memuat komentar `// TODO: Dispatch state transition`, sehingga dana tidak pernah bisa dilepaskan melalui UI mobile.
2. **Alur Pembayaran (*Payment Flow*)**:  
   Buka Top Up → Pilih Nominal → Buka Detail Pembayaran → Klik "SAYA SUDAH BAYAR" (✅ Terhubung ke API dummy).  
   *Titik Putus:* Tidak ada integrasi transfer bank/QRIS nyata. Halaman `PaymentSelectionPage` yang memiliki desain VA lengkap bahkan tidak didaftarkan di router dan tidak pernah dipanggil dari alur transaksi.
3. **Alur Resolusi Sengketa Admin (*Admin Dispute Flow*)**:  
   Login sebagai Admin → Masuk Dashboard Admin → Tab Dispute → Klik "TINDAKAN" → Pilih "REFUND KE PEMBELI" atau "CAIRKAN KE PENJUAL".  
   *Titik Putus:* Klik konfirmasi hanya menampilkan `SnackBar` ("Tindakan Berhasil Diterapkan"). Tidak ada pemanggilan API ke backend untuk mengubah status transaksi di database.

---

# 10. Mobile: Arsitektur dan Integrasi

### Evaluasi Clean Architecture
Struktur folder proyek membagi fitur ke dalam `data`, `domain`, dan `presentation`. Namun, penerapannya tidak konsisten:

| Feature | Domain Layer (Entity / UseCase) | Data Layer (Model / Datasource / Repo) | Presentation Layer (BLoC / Pages) | Evaluasi Kelengkapan |
| :--- | :--- | :--- | :--- | :--- |
| **Auth** | Ada (`UserEntity`) | Ada (`UserModel`), tanpa Repo | Ada (`AuthBloc`, Pages) | ⚠️ **PARSIAL**: Memiliki BLoC, namun BLoC langsung memanggil `ApiService` tanpa Repository pattern. |
| **Transaction**| Ada (`TransactionEntity`, `EscrowStateMachine`) | Ada (`TransactionModel`), tanpa Repo | Tanpa BLoC (StatefulWidget langsung panggil `ApiService`) | ⚠️ **PARSIAL**: State machine domain diabaikan oleh UI presentation. |
| **Chat** | Ada (`ChatMessageEntity`) | Tidak ada Data layer | Tanpa BLoC (StatefulWidget lokal list) | 📄 **KERANGKA / MOCK** |
| **Wallet** | Ada (`WalletEntity`) | Tidak ada Data layer | Tanpa BLoC (StatefulWidget langsung panggil `ApiService`) | ⚠️ **PARSIAL** |
| **Product** | Ada (`ProductEntity`) | Tidak ada Data layer | Tidak ada Presentation layer | ❌ **TIDAK LENGKAP (DEAD ENTITY)** |
| **Admin** | Tidak ada | Tidak ada | Penuh (9 Screens) langsung mock UI | 🧪 **MOCK / TERISOLASI** |

### Daftar BLoC / Cubit yang Ada
Hanya ada **SATU BLoC** di seluruh aplikasi mobile:
* **`AuthBloc`** (`mobile/lib/features/auth/presentation/bloc/auth_bloc.dart`):
  * *Events:* `AuthCheckRequested`, `AuthLoginRequested`, `AuthRegisterRequested`, `AuthLogoutRequested`, `AuthRoleSwitched`.
  * *States:* `AuthInitial`, `AuthLoading`, `AuthAuthenticated`, `AuthUnauthenticated`, `AuthError`, `AuthRegistrationSuccess`.
  * *Use Cases:* Tidak menggunakan use case classes formal; langsung mengorkestrasi `FirebaseAuth` dan `ApiService`.
* Modul Transaksi, Wallet, Chat, dan Admin **tidak memiliki BLoC**. Seluruh state management-nya ditangani melalui `setState` lokal di masing-masing StatefulWidget.

### Daftar Repository dan Datasource
* **Repository Pattern:** ❌ **TIDAK DIIMPLEMENTASIKAN**. Tidak ada folder `repositories/` di data layer.
* Panggilan API dilakukan langsung dari BLoC atau method `StatefulWidget` menggunakan service locator `sl<ApiService>()`.

### Konfigurasi Base URL & Error Handling
* `ApiService` (`mobile/lib/core/services/api_service.dart:22-31`):
  ```dart
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    return 'http://localhost:5000/api';
  }
  ```
* **Penanganan Error:** Method `_handleResponse` mem-parse `body['message']` atau `body['error']` dan melempar `ApiException(statusCode, message, errors)`.
* **Token Kedaluwarsa (*Token Expiry*):** ❌ **TIDAK ADA REFRESH TOKEN LOGIC**. Jika server merespons 401 Token Expired, `ApiService` tidak memiliki interceptor otomatis untuk me-logout user atau memperbarui token.

### Analisis Integrasi Layanan Pihak Ketiga
* **Firebase Auth:** Terpasang dan aktif saat Login/Register.
* **Firebase Messaging (FCM):** Diinisialisasi di `main.dart:30` via `NotificationService`. Token dikirim ke backend via `/auth/update-fcm`.
* **Supabase:** Terpasang di `pubspec.yaml`, tetapi **tidak diinisialisasi dan tidak digunakan**.
* **QRIS:** Paket `qr_flutter` terpasang, tetapi kode pembuatan QRIS tidak pernah dipanggil; halaman pembayaran hanya memuat teks mockup.
* **Image Picker / Cropper:** Terpasang di `pubspec.yaml`, tetapi event `onTap` pemilihan foto di `KycScreen:114` dan `EditProfileScreen:155` dibiarkan kosong tanpa memanggil library.
* **fl_chart (Grafik):** Terpasang di `pubspec.yaml`, tetapi dashboard admin hanya menggunakan widget teks brutalist kotak statis.

---

# 11. Kesenjangan Backend ↔ Mobile

Tabel berikut menganalisis kecocokan antara fitur pada antarmuka mobile dengan ketersediaan endpoint backend:

| Fitur / Halaman Mobile | Endpoint Backend yang Dibutuhkan | Method | Endpoint Tersedia di Backend? | Kecocokan Format Request / Response | Evaluasi Integrasi |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Login** (`LoginPage`) | `/api/auth/login` | POST | ✅ Ada | ✅ Cocok (`email`, `password`) | ✅ **TERHUBUNG LENGKAP** |
| **Register** (`RegisterPage`) | `/api/auth/register` | POST | ✅ Ada | ✅ Cocok (`name`, `email`, `password`) | ✅ **TERHUBUNG LENGKAP** |
| **Lupa Email** (`ForgotEmailPage`)| `/api/auth/forgot-email`| POST | ✅ Ada | ✅ Cocok (`name`, `password`) | ✅ **TERHUBUNG LENGKAP** |
| **Profil User & Saldo** (`HomePage`)| `/api/auth/me` | GET | ✅ Ada | ✅ Cocok | ✅ **TERHUBUNG LENGKAP** |
| **Update Nama Profil** (`EditProfile`)| `/api/auth/profile` | PUT | ✅ Ada | ⚠️ Parsial (Email & HP diabaikan) | ⚠️ **PARSIAL** |
| **Cari Lawan Transaksi** (`BuatRoom`)| `/api/auth/search-opponent`| GET | ✅ Ada | ✅ Cocok (`?query=...`) | ✅ **TERHUBUNG LENGKAP** |
| **Inisiasi Room Escrow** (`BuatRoom`)| `/api/transactions` | POST | ✅ Ada | ⚠️ Parsial (`feePayer` tidak disimpan) | ✅ **TERHUBUNG LENGKAP** |
| **Daftar Transaksi Aktif** (`HomePage`)| `/api/transactions` | GET | ✅ Ada | ⚠️ Parsial (Status enum beda format) | ⚠️ **PARSIAL** |
| **Riwayat Transaksi** (`RiwayatScreen`)| `/api/transactions` | GET | ✅ Ada | ⚠️ Parsial (Status enum beda format) | ⚠️ **PARSIAL** |
| **Top-up Saldo** (`DetailPembayaran`)| `/api/wallet/topup` | POST | ✅ Ada | ✅ Cocok (`amount`) | ⚠️ **PARSIAL (DUMMY MONEY)** |
| **Penarikan Saldo** (`TarikDanaScreen`)| `/api/wallet/withdraw` | POST | ✅ Ada | ⚠️ Parsial (Data bank tidak dikirim) | ⚠️ **PARSIAL (NO PAYOUT)** |
| **Detail Escrow Stepper** (`TransactionDetail`)| `/api/transactions/:id` | GET | ✅ Ada | ❌ Tidak dipanggil di UI mobile | ❌ **TERPUTUS (UI PAKAI EXTRA/MOCK)** |
| **Konfirmasi Barang Diterima** (`TransactionDetail`)| `/api/transactions/:id/status`| PUT | ✅ Ada | ❌ Tombol UI hanya memuat TODO | ❌ **TERPUTUS (ACTION TIDAK AKTIF)** |
| **Ajukan Sengketa Pembeli** (`TransactionDetail`)| `/api/transactions/:id/status`| PUT | ✅ Ada | ❌ Tombol UI hanya memuat TODO | ❌ **TERPUTUS (ACTION TIDAK AKTIF)** |
| **Cari Transaksi Kode** (`InputKodeScreen`)| `/api/transactions/:code` | GET | ❌ **TIDAK ADA** | ❌ Backend tidak punya endpoint cari kode | ❌ **MOCK DATA ONLY** |
| **Ruang Chat Transaksi** (`ChatRoomPage`)| `/api/chat/:txId` | GET/WS| ❌ **TIDAK ADA** | ❌ Backend tidak punya modul chat | ❌ **MOCK DATA ONLY** |
| **Asisten AI** (`AiAssistantScreen`)| `/api/ai/chat` | POST | ❌ **TIDAK ADA** | ❌ Backend tidak punya modul AI | ❌ **MOCK DATA ONLY** |
| **Verifikasi KYC Identitas** (`KycScreen`)| `/api/kyc/submit` | POST | ❌ **TIDAK ADA** | ❌ Backend tidak punya modul KYC | ❌ **KERANGKA STUB ONLY** |
| **Admin: Statistik Dashboard** (`AdminDashboard`)| `/api/admin/metrics` | GET | ❌ **TIDAK ADA** | ❌ Backend tidak punya endpoint admin | ❌ **MOCK DATA ONLY** |
| **Admin: Daftar Sengketa** (`AdminDispute`)| `/api/admin/disputes`| GET | ❌ **TIDAK ADA** | ❌ Backend tidak punya endpoint admin | ❌ **MOCK DATA ONLY** |
| **Admin: Putusan Sengketa** (`AdminDispute`)| `/api/admin/disputes/:id/resolve`| POST | ❌ **TIDAK ADA** | ❌ Backend tidak punya endpoint admin | ❌ **MOCK DATA ONLY** |
| **Admin: Daftar & Aksi KYC** (`AdminKyc`)| `/api/admin/kyc` | GET/PUT| ❌ **TIDAK ADA** | ❌ Backend tidak punya endpoint admin | ❌ **MOCK DATA ONLY** |
| **Admin: Kontrol Finansial** (`AdminFinancial`)| `/api/admin/settings/fees`| PUT | ❌ **TIDAK ADA** | ❌ Backend tidak punya endpoint admin | ❌ **MOCK DATA ONLY** |
| **Admin: Blokir Pengguna** (`AdminUserManage`)| `/api/admin/users/:id/ban`| POST | ❌ **TIDAK ADA** | ❌ Backend tidak punya endpoint admin | ❌ **MOCK DATA ONLY** |

---

# 12. Kualitas Kode dan Testing

### Unit, Integration, dan Widget Testing
* **Backend:**
  * File unit test formal (Jest/Mocha): **NOL (0)**.
  * `package.json:14`: `"test": "echo \"Error: no test specified\" && exit 1"`.
  * Terdapat skrip PowerShell manual `backend/test-api.ps1` yang melakukan pengujian HTTP terhadap server lokal.
* **Mobile:**
  * File test: Hanya ada 1 file yaitu `mobile/test/widget_test.dart`.
  * **Hasil Uji:** ❌ **GAGAL**. Tes ini merupakan kode boilerplate bawaan inisialisasi Flutter (`Counter increments smoke test`) yang menguji widget counter. Karena aplikasi telah diganti menjadi `RekberApp`, tes mengalami crash dan gagal.

### Komentar TODO / FIXME / HACK dan Stub Ditemukan
1. `mobile/lib/app.dart:19`: `// TODO: Add more BLoC providers as features are built`
2. `mobile/lib/features/transaction/presentation/pages/payment_selection_page.dart:281`: `// TODO: Process payment via Edge Function`
3. `mobile/lib/features/transaction/presentation/pages/transaction_detail_page.dart:347`: `// TODO: Navigate to chat room`
4. `mobile/lib/features/transaction/presentation/pages/transaction_detail_page.dart:396`: `// TODO: Dispatch state transition`
5. `mobile/lib/features/settings/presentation/pages/edit_profile_screen.dart:155`: `// Pick Image Logic` (placeholder tanpa kode).
6. `mobile/lib/features/settings/presentation/pages/help_center_screen.dart:122`: `// WhatsApp logic` (placeholder tanpa kode).
7. `mobile/lib/features/settings/presentation/pages/kyc_screen.dart:133`: `// Submit logic` (placeholder tanpa kode).
8. `mobile/lib/features/settings/presentation/pages/security_screen.dart:117`: `// Change PIN logic` (placeholder tanpa kode).
9. `mobile/lib/features/settings/presentation/pages/security_screen.dart:144`: `// Update security logic` (placeholder tanpa kode).
10. `mobile/lib/features/transaction/presentation/pages/input_kode_screen.dart:155`: `// Action` (placeholder tombol gabung).
11. `mobile/lib/features/admin/presentation/pages/admin_kyc_screen.dart:391`: `// Would toggle selection logic in real app`.

### Kode Duplikat dan File Mati (*Dead Code*)
* **Direktori `backend/supabase/`**: Memuat skema SQL dan 5 Edge Functions Deno yang tidak digunakan sama sekali oleh aplikasi yang sedang aktif.
* **Entity Mati di Mobile**: `ProductEntity` (`mobile/lib/features/product/domain/entities/product_entity.dart`) dan `WalletEntity` (`mobile/lib/features/wallet/domain/entities/wallet_entity.dart`) didefinisikan tetapi tidak terhubung ke datasource atau UI mana pun.
* **Screen Yatim**: `PaymentSelectionPage` (`mobile/lib/features/transaction/presentation/pages/payment_selection_page.dart`) tidak didaftarkan di `app_router.dart` sehingga tidak bisa diakses sama sekali.
* **Kredensial Pengujian Hardcoded**: Tombol cepat login di `mobile/lib/features/auth/presentation/pages/login_page.dart:266-295` secara terang-terangan menempelkan email dan password plaintext pengujian (`buyer@rekber.com` / `buyer123`, `seller@rekber.com` / `seller123`, `admin@rekber.com` / `admin123`) di UI produksi.

### Hasil Analisis Statis / Linter
* **Backend:** Tidak ada konfigurasi ESLint/Prettier di `package.json`.
* **Mobile (`flutter analyze`):**
  * Ditemukan **11 peringatan (*info*)**, seluruhnya terkait pelanggaran aturan `use_build_context_synchronously`:
    * `edit_profile_screen.dart`: baris 62, 64, 70, 72, 79.
    * `buat_room_screen.dart`: baris 111, 118.
    * `detail_pembayaran_screen.dart`: baris 65, 72.
    * `tarik_dana_screen.dart`: baris 59, 66.
  * Peringatan ini menandakan penggunaan `BuildContext` (seperti `Navigator.pop` atau `ScaffoldMessenger`) setelah jeda `await` asynchronous yang berisiko memory leak atau crash jika widget sudah di-dispose saat request selesai.

### Penanganan Error dan Logging
* **Backend:** Menggunakan morgan HTTP logger (`backend/src/app.js:38`). Error penanganan menggunakan middleware terpusat `errorHandler` (`src/middlewares/error.middleware.js`). Cukup baik dalam memetakan error kode Prisma (`P2002` duplicate, `P2025` not found).
* **Mobile:** Menggunakan blok `try-catch` dengan logging manual `if (kDebugMode) print(...)`. Error ditampilkan ke user melalui `SnackBar` berwarna merah `AppColors.error`.

---

# 13. Daftar Masalah Diketahui

Tabel rekapitulasi seluruh temuan isu dan bug pada proyek Rekber, dikelompokkan berdasarkan tingkat keparahan:

| ID Isu | Deskripsi Masalah | Lokasi Bukti (File:Baris) | Tingkat | Dampak terhadap Sistem |
| :--- | :--- | :--- | :---: | :--- |
| **ISSUE-01** | **Manipulasi Saldo Cuma-Cuma**: Endpoint top-up saldo menambah saldo virtual tanpa verifikasi gateway pembayaran. | `backend/src/routes/wallet.routes.js:7-28` | **Kritis** | Pengguna dapat mengisi saldo tak terbatas secara gratis dan menggunakannya untuk menipu penjual. |
| **ISSUE-02** | **Kunci JWT Fallback Hardcoded**: Rahasia JWT memakai string default `'fallback-secret-change-me'` jika env kosong. | `backend/src/config/index.js:17` | **Kritis** | Penyerang dapat memalsukan token JWT sebagai Admin atau user lain dan mengambil alih sistem. |
| **ISSUE-03** | **Crash Database Out-of-the-Box**: File `.env` tidak ada di repositori backend sehingga database gagal koneksi. | `backend/src/config/prisma.js:21` | **Kritis** | Backend tidak bisa dijalankan oleh developer baru tanpa konfigurasi manual mendalam. |
| **ISSUE-04** | **Race Condition Penarikan Saldo**: Pengurangan saldo withdraw tidak atomik dan tidak di-lock dalam transaksi DB. | `backend/src/routes/wallet.routes.js:44-51` | **Kritis** | Penyerang bisa melakukan penarikan dana paralel ganda (*double-spending* / negative balance). |
| **ISSUE-05** | **Ketiadaan Buku Besar Finansial (*Ledger*)**: Saldo uang hanya berupa satu kolom `balance` tanpa tabel histori debit/kredit. | `backend/prisma/schema.prisma:59` | **Kritis** | Kehilangan total jejak audit keuangan, pembukuan escrow tidak dapat dipertanggungjawabkan secara hukum. |
| **ISSUE-06** | **Aksi Detail Transaksi Mobile Terputus**: Tombol "Pesanan Diterima" dan "Ajukan Sengketa" di mobile berupa stub `TODO`. | `mobile/.../transaction_detail_page.dart:347,396` | **Tinggi** | Pembeli tidak bisa menyelesaikan transaksi atau mengajukan sengketa secara nyata dari antarmuka mobile. |
| **ISSUE-07** | **Ketidakcocokan Status Transaksi**: Enum Prisma huruf besar (`PENDING`), mobile state machine snake_case (`escrow`). | `backend/prisma/schema.prisma:38-45` vs `mobile/.../escrow_state_machine.dart:32-90` | **Tinggi** | Status transaksi dari backend akan gagal dikenali oleh state machine mobile dan memicu tampilan default. |
| **ISSUE-08** | **9 Layar Panel Admin 100% Mockup**: Seluruh dashboard dan moderasi admin di mobile tidak memiliki backend API. | `mobile/lib/features/admin/...` | **Tinggi** | Admin tidak bisa memonitor transaksi riil, memblokir user, atau menyelesaikan sengketa dari aplikasi. |
| **ISSUE-09** | **Ketiadaan Route Guard pada Router**: GoRouter di mobile tidak memproteksi rute admin atau rute berotentikasi. | `mobile/lib/config/routes/app_router.dart:41-245` | **Tinggi** | Siapa pun bisa membuka rute `/admin/dashboard` langsung tanpa verifikasi role. |
| **ISSUE-10** | **Ketiadaan Riwayat Migrasi Prisma**: Folder `prisma/migrations` tidak ada di backend. | `backend/prisma/migrations/` | **Tinggi** | Skema database tidak terlacak perubahannya, rentan error sinkronisasi saat deploy multi-environment. |
| **ISSUE-11** | **Eksploitasi Enumerasi Akun pada Lupa Email**: Endpoint mengembalikan email berdasarkan tebakan nama dan password. | `backend/src/services/auth.service.js:119-142` | **Tinggi** | Celah kebocoran privasi data email pengguna. |
| **ISSUE-12** | **Withdrawal Tanpa Rekening Bank Nyata**: Endpoint penarikan memotong saldo tanpa menyimpan detail rekening bank. | `backend/src/routes/wallet.routes.js:48-52` | **Tinggi** | Uang user hangus terpotong di sistem tetapi tidak pernah ada pengiriman dana nyata ke rekening. |
| **ISSUE-13** | **Terminal State Macet pada Sengketa**: Backend tidak memiliki transisi keluar dari status `DISPUTED`. | `backend/src/services/transaction.service.js:39` | **Tinggi** | Transaksi yang disengketakan akan membeku selamanya di database tanpa bisa diselesaikan oleh admin. |
| **ISSUE-14** | **Dual Architecture / Dead Code**: Kode Supabase lengkap tersimpan di backend tetapi tidak terpakai. | `backend/supabase/...` | **Sedang** | Membingungkan pengembang, meningkatkan beban pemeliharaan kode tak terpakai. |
| **ISSUE-15** | **Konflik Otentikasi Ganda**: Firebase Auth di mobile bertabrakan dengan Custom Backend JWT. | `mobile/.../auth_bloc.dart:60-75` | **Sedang** | Akun uji coba seed di-hardcode lolos Firebase, rentan kegagalan sinkronisasi akun baru. |
| **ISSUE-16** | **Unit Test Mobile Rusak / Gagal**: File `widget_test.dart` menguji aplikasi counter bawaan template Flutter. | `mobile/test/widget_test.dart:18` | **Sedang** | Pipeline CI/CD otomatis akan gagal; tidak ada jaminan kualitas kode melalui automated test. |
| **ISSUE-17** | **Ketiadaan Rate Limiting**: Tidak ada proteksi throttling request pada API Express. | `backend/src/app.js` | **Sedang** | Rentan serangan DoS dan brute-force attack pada endpoint login. |
| **ISSUE-18** | **Validasi Input Bolong pada Profil & FCM**: Update profil dan FCM token tidak divalidasi express-validator. | `backend/src/routes/auth.routes.js:33,41` | **Sedang** | Input kotor atau null bisa masuk dan merusak integritas data user. |
| **ISSUE-19** | **Ketiadaan Field Komisi (*Platform Fee*) di DB**: Komisi rekber tidak disimpan di tabel `transactions`. | `backend/prisma/schema.prisma:76-94` | **Sedang** | Platform tidak memiliki catatan akurat berapa pendapatan fee yang didapat dari tiap transaksi. |
| **ISSUE-20** | **Asisten AI Hanyalah Mock Simulasi**: Layar AI Assistant di mobile hanya memakai logika if/else statis sederhana. | `mobile/.../ai_assistant_screen.dart:70-87` | **Sedang** | Pengguna tidak mendapatkan bantuan cerdas nyata; fitur belum siap pakai. |
| **ISSUE-21** | **Ruang Chat Transaksi Hanya Memori Lokal**: Pesan chat transaksi tidak tersimpan di database dan tidak realtime. | `mobile/.../chat_room_page.dart:29-54` | **Sedang** | Pembeli dan penjual tidak bisa saling berkomunikasi secara riil di dalam aplikasi. |
| **ISSUE-22** | **Layar KYC Tanpa Logika Upload**: Tombol kirim dokumen KYC di mobile hanyalah antarmuka kosong (*stub*). | `mobile/.../kyc_screen.dart:133` | **Sedang** | Pengguna tidak dapat mengirim dokumen identitas untuk diverifikasi. |
| **ISSUE-23** | **13 Paket Mobile Tidak Terpakai**: Paket seperti Supabase, QR, Chart, Image Picker, Cropper terpasang sia-sia. | `mobile/pubspec.yaml` | **Rendah** | Memperbesar ukuran APK/bundle aplikasi secara percuma (*bloatware dependencies*). |
| **ISSUE-24** | **11 Peringatan Linter Async Context**: Pelanggaran aturan `use_build_context_synchronously` di mobile. | `mobile/lib/...` (4 file) | **Rendah** | Berpotensi memicu glitch UI atau memory leak saat navigasi cepat. |
| **ISSUE-25** | **Screen Yatim / Orphaned Route**: `PaymentSelectionPage` tidak terdaftar di router mobile. | `mobile/.../payment_selection_page.dart` | **Rendah** | Kode mati di sisi mobile presentation. |
| **ISSUE-26** | **Kredensial Pengujian Menempel di UI**: Tombol quick login memuat password plaintext di antarmuka publik. | `mobile/.../login_page.dart:266-295` | **Rendah** | Buruk secara estetika keamanan dan membocorkan akun demo. |

---

# 14. Pemeriksaan Kebutuhan Escrow

Checklist kepatuhan fitur terhadap standar minimum aplikasi rekening bersama / escrow profesional:

| Kebutuhan Fitur Escrow | Status Kepatuhan | Bukti Kode & Keterangan Teknis |
| :--- | :---: | :--- |
| **1. Pembayaran Terverifikasi Gateway** | ❌ **BELUM ADA** | Tidak ada webhook atau SDK payment gateway aktif di Express backend. Top-up saldo pada `backend/src/routes/wallet.routes.js:17` langsung menambah angka saldo tanpa verifikasi eksternal. |
| **2. Dana Tertahan Aman (*Hold in Escrow*)**| ⚠️ **PARSIAL** | Saldo pembeli dipotong saat status berubah menjadi `PAID` (`backend/src/services/transaction.service.js:197-214`), tetapi dana tidak dialokasikan ke tabel penampung khusus escrow, melainkan hanya berkurang dari saldo user. |
| **3. Rilis Dana ke Penjual (*Release Funds*)** | ⚠️ **PARSIAL** | Logika pelepasan dana ada di backend (`transaction.service.js:217`), tetapi tombol rilis di mobile (`transaction_detail_page.dart:396`) belum terhubung ke API (hanya komentar `// TODO`). |
| **4. Pembatalan dan Pengembalian (*Refund*)** | ⚠️ **PARSIAL** | Refund otomatis hanya ada di backend pada skenario admin membatalkan transaksi yang sudah `PAID` (`transaction.service.js:225`). Belum ada antarmuka bagi pembeli/admin di mobile untuk memicu refund. |
| **5. Sengketa & Keputusan Admin (*Dispute*)** | ❌ **BELUM ADA** | Status `DISPUTED` adalah terminal state di backend tanpa alur penyelesaian (`transaction.service.js:39`). Seluruh tombol putusan sengketa di mobile admin hanya memunculkan `SnackBar` dummy. |
| **6. Auto-Release (Timer Otomatis)** | ❌ **BELUM ADA** | Tidak ditemukan dependensi scheduler (seperti `node-cron`, `bullmq`, atau Cloud Scheduler) di backend untuk otomatis melepas dana setelah X hari masa garansi habis. |
| **7. Ledger / Audit Mutasi Keuangan** | ❌ **BELUM ADA** | Skema Prisma (`backend/prisma/schema.prisma`) hanya memiliki 2 model (`User` dan `Transaction`). Tidak ada tabel `Ledger`, `WalletTransaction`, atau mutasi debit/kredit. |
| **8. Verifikasi Identitas (KYC)** | ❌ **BELUM ADA** | Skema Prisma backend tidak memiliki atribut atau tabel KYC. Layar `KycScreen.dart` di mobile tidak memiliki logika upload file atau integrasi OCR/KTP. |
| **9. Rekening Bank Penarikan (*Payout*)** | ❌ **BELUM ADA** | Skema backend tidak memiliki model `BankAccount`. Endpoint `/api/wallet/withdraw` hanya mengurangi saldo angka tanpa menyimpan data rekening penerima. |
| **10. Notifikasi Push Realtime** | ⚠️ **PARSIAL** | `NotificationService` dan FCM Token sudah disimpan di backend (`/auth/update-fcm`), namun backend Express belum memiliki helper pengirim push notifikasi saat status transaksi berubah. |
| **11. Pembatasan Laju (*Rate Limiting*)** | ❌ **BELUM ADA** | Tidak ada middleware `express-rate-limit` pada `backend/src/app.js`. |
| **12. Backup dan Monitoring** | ❌ **BELUM ADA** | Hanya ada endpoint `/api/health` statis dan `morgan` logging. Tidak ada sentry, prometheus, atau automated backup script. |
| **13. Halaman Admin Terintegrasi** | 🧪 **MOCK/DUMMY** | Antarmuka panel admin lengkap tersedia di mobile (`AdminMainWrapper`), tetapi 100% menggunakan data hardcoded dan tidak terhubung ke backend. |

---

# 15. Pertanyaan Terbuka

Berikut adalah hal-hal penting yang tidak dapat dipastikan hanya dari membaca kode dan membutuhkan klarifikasi dari pemilik proyek atau pemangku kepentingan (*stakeholders*):

1. **Arah Arsitektur Backend Sebenarnya**:  
   Apakah proyek ini bermaksud beralih sepenuhnya ke **Supabase** (dengan memanfaatkan Edge Functions, RLS, Realtime Chat, dan skema SQL 8 tabel di `backend/supabase/`), ATAU ingin melanjutkan arsitektur mandiri **Node.js Express + Prisma**? Keputusan ini krusial karena saat ini kedua arsitektur saling bertolak belakang dan menyebabkan duplikasi.
2. **Mitra Payment Gateway yang Direncanakan**:  
   Di dalam kode terdapat penyebutan Xendit dan Midtrans dalam bentuk komentar. Payment gateway mana yang telah memiliki kontrak/MoU bisnis resmi, dan akun sandbox/production mana yang akan diintegrasikan untuk QRIS, Virtual Account, dan Payout/Disbursement?
3. **Mekanisme Legalitas dan Rekening Penampung Escrow**:  
   Apakah penampungan dana escrow akan menggunakan rekening atas nama PT/badan usaha sendiri, atau memanfaatkan akun penampung (*escrow pool account*) resmi dari payment gateway berlisensi PJP (Penyelenggara Jasa Pembayaran) Bank Indonesia?
4. **Kebijakan Masa Garansi (*Auto-Release Window*)**:  
   Berapa lama batas waktu tunggu default bagi pembeli untuk memeriksa barang sebelum dana otomatis dicairkan ke penjual (misalnya 2x24 jam atau 3x24 jam), dan apakah timer tersebut berlaku sama untuk produk digital vs barang fisik?
5. **Skema Biaya Layanan (*Platform Fee*)**:  
   Di kode mobile terdapat referensi fee 2% dan 2.5%, dengan opsi ditanggung pembeli, penjual, atau dibagi dua (50:50). Bagaimana rumus pasti penetapan fee, berapa batas minimum/maksimum fee per transaksi, dan apakah ada fee penarikan dana (*withdrawal fee*) ke bank?

---

### Verifikasi Akhir Auditor
Laporan ini disusun secara faktual, independen, dan objektif berdasarkan inspeksi baris demi baris pada seluruh basis kode backend dan mobile proyek Rekber per tanggal 21 November 2026. Seluruh klaim disertai bukti nomor baris dan path file yang dapat diverifikasi ulang.
