# Dokumentasi Proyek Rekber (Rekening Bersama)

## 1. Tentang Aplikasi

**Rekber** adalah platform *Automated Escrow* (Rekening Bersama Otomatis) yang dirancang untuk memfasilitasi dan mengamankan transaksi keuangan antara pembeli dan penjual. Platform ini bertindak sebagai pihak ketiga yang dapat dipercaya untuk menahan dana pembayaran di dalam *escrow*. Dana hanya akan diteruskan ke penjual ketika pembeli telah mengonfirmasi bahwa barang atau jasa telah diterima dengan baik, atau dikembalikan jika transaksi dibatalkan / terdapat sengketa (*dispute*).

Sistem ini terbagi menjadi dua bagian utama:
1. **Backend (API):** Bertugas mengelola logika bisnis, database, dan transaksi.
2. **Mobile (Client):** Aplikasi antarmuka pengguna berbasis Android/iOS.

---

## 2. Fitur Saat Ini

Berdasarkan kondisi *real* kode dan skema database yang ada di repositori saat ini, berikut adalah fitur-fitur yang tersedia:

### 👤 Sistem Pengguna (User Management)
- **Autentikasi & Keamanan:** Sistem login dan registrasi berbasis JWT (JSON Web Token), dilengkapi dengan sinkronisasi Firebase UID untuk integrasi pihak ketiga.
- **Peran Pengguna (Role):** Mendukung pemisahan hak akses antara pengguna biasa (`USER`) dan administrator (`ADMIN`).
- **Dompet Virtual (Wallet):** Setiap pengguna dilengkapi dengan fitur saldo/dompet virtual dalam bentuk Rupiah (IDR) yang digunakan untuk menampung dana hasil transaksi atau pengembalian dana.
- **Push Notification:** Dukungan token FCM (Firebase Cloud Messaging) pada tiap pengguna untuk mengirim notifikasi secara langsung ke perangkat.

### 💼 Manajemen Transaksi Escrow
Fitur utama platform. Transaksi melibatkan Pembeli (*Buyer*), Penjual (*Seller*), nominal jumlah uang (*Amount*), dan deskripsi barang.
Transaksi berjalan mengikuti *State Machine* (Sistem Status) berikut:
1. **`PENDING`**: Transaksi berhasil dibuat, sistem sedang menunggu pembeli melakukan pembayaran.
2. **`PAID`**: Pembeli telah melakukan deposit. Dana saat ini aman tertahan di dalam *escrow* sistem.
3. **`SHIPPED`**: Penjual menandai bahwa barang/jasa sudah mulai dikirim/dikerjakan.
4. **`COMPLETED`**: Pembeli mengonfirmasi barang telah diterima. Sistem otomatis mentransfer dana dari *escrow* ke dompet/saldo penjual.
5. **`CANCELLED`**: Transaksi dibatalkan sebelum selesai.
6. **`DISPUTED`**: Terjadi masalah (sengketa) dalam transaksi yang membutuhkan penanganan lebih lanjut.

### 📱 Kemampuan Aplikasi Mobile
Sistem klien telah dikonfigurasi untuk mendukung fitur antarmuka modern:
- **Navigasi Terstruktur:** Menggunakan sistem *routing* deklaratif modern.
- **Pembayaran QRIS:** Kemampuan untuk me-render kode QR secara lokal untuk memfasilitasi proses pembayaran.
- **Pemrosesan Media:** Mendukung pengambilan gambar dari galeri/kamera, pemotongan gambar (*cropping*), dan penyimpanan lokal.
- **Dashboard & Analitik:** Menyediakan tampilan grafik/chart visual untuk data penjual.
- **Notifikasi *Real-time*:** Terintegrasi dengan Firebase Messaging untuk notifikasi jarak jauh dan notifikasi lokal.
- **Penyimpanan Aman:** Menggunakan penyimpanan terenkripsi untuk menyimpan kredensial pengguna dan token akses di perangkat.

---

## 3. Tech Stack (Teknologi yang Digunakan)

Berikut adalah *tech stack* asli yang saat ini digunakan di dalam *source code*:

### ⚙️ Backend (API Server)
Backend dibangun dengan arsitektur monolitik menggunakan ekosistem Node.js.
- **Lingkungan / Runtime:** Node.js
- **Web Framework:** Express.js (v5)
- **Database:** PostgreSQL
- **ORM (Object Relational Mapping):** Prisma (v7) dengan `@prisma/adapter-pg`
- **Keamanan:** 
  - `bcryptjs` (Hashing kata sandi)
  - `jsonwebtoken` (Manajemen token autentikasi)
  - `helmet` (Perlindungan *header* HTTP)
  - `cors` (Manajemen akses lintas domain)
- **Validasi Data:** `express-validator`
- **Logging & Konfigurasi:** `morgan` (HTTP logger), `dotenv` (Manajemen *environment*)

### 📱 Mobile App (Klien Android / iOS)
Aplikasi mobile dibangun dengan konsep *Clean Architecture* menggunakan kerangka kerja lintas platform dari Google.
- **Framework Utama:** Flutter
- **Bahasa Pemrograman:** Dart (SDK >= 3.2.0)
- **State Management:** BLoC (*Business Logic Component*) melalui `flutter_bloc` & `equatable`.
- **Dependency Injection:** `get_it` & `injectable` (untuk *auto code generation*).
- **Routing:** `go_router`
- **Integrasi Cloud & Backend:**
  - `http` (HTTP Client untuk komunikasi ke API Express)
  - `supabase_flutter` (SDK Supabase)
  - Firebase Services (`firebase_core`, `firebase_auth`, `firebase_messaging`)
- **Functional Programming:** `dartz` (Manajemen *error* yang aman via *Either/Option*).
- **UI & Desain Visual:**
  - `google_fonts` (Tipografi kustom)
  - `flutter_svg` & `lottie` (Ikon vektor & Animasi mulus)
  - `shimmer` (Efek *loading* skeleton)
  - `fl_chart` (Pembuatan grafik data)
- **Utilitas Native:**
  - `qr_flutter` (Generator QR Code)
  - `image_picker` & `image_cropper` (Manajemen foto)
  - `flutter_secure_storage` (Penyimpanan token JWT secara aman)
  - `url_launcher` & `share_plus` (Interaksi ke aplikasi eksternal)

---

## 4. Daftar API dan Endpoint

Berikut adalah daftar rute API (*endpoint*) yang telah dikembangkan di *backend* (terdapat di folder `src/routes/`):

**Auth (`/api/auth`)**
- `POST /register`: Mendaftarkan akun pengguna baru.
- `POST /login`: Autentikasi dan mendapatkan *JWT token*.
- `POST /forgot-email`: Memulihkan informasi email.
- `GET /me`: (*Protected*) Mendapatkan profil pengguna dan detail saldo.
- `PUT /profile`: (*Protected*) Memperbarui detail profil.
- `GET /search-opponent`: (*Protected*) Mencari akun pengguna lain untuk diajak bertransaksi.
- `POST /update-fcm`: (*Protected*) Memperbarui token *Push Notification* (FCM).

**Transactions (`/api/transactions`)**
*(Seluruh rute ini membutuhkan autentikasi JWT)*
- `POST /`: Membuat transaksi *escrow* baru.
- `GET /`: Menampilkan riwayat transaksi pengguna yang sedang *login*.
- `GET /:id`: Melihat detail lengkap sebuah transaksi berdasarkan ID.
- `PUT /:id/status`: Memperbarui status (*state machine*) transaksi.

**Wallet (`/api/wallet`)**
*(Seluruh rute ini membutuhkan autentikasi JWT)*
- `POST /topup`: Melakukan top-up / menambah saldo dompet virtual.
- `POST /withdraw`: Melakukan penarikan saldo (*withdrawal*).

**System**
- `GET /api/health`: Endpoint untuk *health-check* server.

---

## 5. Status Sistem: Database & Tahap Pengembangan

### Konektivitas Database
Secara struktur kode, aplikasi sudah dirancang dengan kokoh untuk terhubung ke PostgreSQL menggunakan **Prisma ORM**. Namun, di *environment* (lingkungan lokal) Anda saat ini:
- **Belum Terhubung Secara Aktif.** Anda belum melakukan instalasi dependensi backend (belum menjalankan `npm install`, terbukti dari tidak adanya `@prisma/client`) dan belum menyediakan file `.env` yang memuat `DATABASE_URL`. Anda perlu melengkapi konfigurasi *environment* agar database benar-benar terhubung.

### Status Keseluruhan Fitur
Aplikasi ini dipastikan masih berada di **Tahap Pengembangan (Development)**.
- Sebagian besar *core logic* atau logika inti (rute API, pengontrol transaksi) dan struktur antar muka klien (UI halaman seperti `buat_room_screen.dart`, `kalkulator_screen.dart`, `transaction_detail_page.dart` di *mobile*) sudah dikodekan.
- Namun, sistem ini belum bisa dikatakan "100% berjalan" secara *end-to-end* tanpa adanya pengaturan environment awal dan pengujian integrasi (API ke UI). Fokus pengembangan selanjutnya yang harus dilakukan adalah melengkapi `.env`, menginstal dependensi (`npm install` & `flutter pub get`), serta melakukan pengujian alur secara menyeluruh.
