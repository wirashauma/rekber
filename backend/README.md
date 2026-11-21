# REKBER Backend API

Layanan backend REST API untuk platform Rekening Bersama (Escrow) Rekber, dibangun menggunakan **Node.js**, **Express 5**, **Prisma ORM 7** (dengan `@prisma/adapter-pg`), dan **PostgreSQL**.

---

## 1. Prasyarat Sistem

Sebelum menjalankan backend, pastikan perangkat Anda telah terpasang:

- **Node.js**: versi `20.x` atau lebih baru (direkomendasikan `22.x`)
- **npm**: versi `10.x` atau lebih baru
- **PostgreSQL**: versi `14.x` atau lebih baru yang sedang berjalan secara lokal atau remote

---

## 2. Instalasi Dependensi

Jalankan perintah berikut di dalam direktori `backend/`:

```bash
npm install
```

---

## 3. Konfigurasi Environment (`.env`)

Backend menerapkan prinsip **fail-fast** melalui `src/config/env.js`. Server akan menolak berjalan jika variabel wajib belum dikonfigurasi dengan benar.

1. Salin template environment dari `.env.example`:

   ```bash
   cp .env.example .env
   # Pada Windows PowerShell:
   Copy-Item .env.example .env
   ```

2. Buka file `.env` dan sesuaikan nilainya:

| Variabel             |      Wajib?      |    Default     | Keterangan & Validasi                                                                                                                       |
| :------------------- | :--------------: | :------------: | :------------------------------------------------------------------------------------------------------------------------------------------ |
| `DATABASE_URL`       |      **Ya**      |       -        | URL koneksi PostgreSQL (contoh: `postgresql://postgres:postgres@localhost:5432/rekber?schema=public`)                                       |
| `DATABASE_URL_TEST`  |  **Ya (test)**   |       -        | URL koneksi database test. **Wajib berakhiran `_test`** (contoh: `postgresql://postgres:postgres@localhost:5432/rekber_test?schema=public`) |
| `JWT_SECRET`         |      **Ya**      |       -        | Kunci rahasia JWT. **Wajib minimal 32 karakter** demi keamanan token                                                                        |
| `JWT_EXPIRES_IN`     |      Tidak       |      `7d`      | Masa berlaku token JWT (contoh: `7d`, `15m`, `24h`)                                                                                         |
| `PORT`               |      Tidak       |     `5000`     | Port listening server Express (1 - 65535)                                                                                                   |
| `NODE_ENV`           |      Tidak       | `development`  | Environment runtime: `development`, `production`, atau `test`                                                                               |
| `CORS_ORIGIN`        | **Ya jika prod** | `*` (saat dev) | Origin yang diizinkan untuk CORS (contoh: `http://localhost:3000`)                                                                          |
| `BCRYPT_SALT_ROUNDS` |      Tidak       |      `12`      | Jumlah putaran hashing bcrypt                                                                                                               |

> **Catatan Keamanan**: Jangan pernah melakukan commit file `.env` ke repositori git. File `.env` dan variasinya telah diabaikan oleh `.gitignore`.

---

## 4. Migrasi Database (Prisma)

Skema database dikelola melalui Prisma ORM.

### a. Menjalankan Migrasi Lokal

Untuk menerapkan migrasi pada database lokal saat masa pengembangan:

```bash
npm run db:migrate
```

_(Menjalankan `npx prisma migrate dev`)_

### b. Menjalankan Migrasi di Staging/Production

Untuk menerapkan migrasi yang sudah tercatat tanpa membuat migrasi baru:

```bash
npm run db:deploy
```

_(Menjalankan `npx prisma migrate deploy`)_

### c. Menandai Baseline Migration (`migrate resolve`)

Jika database lokal Anda sudah memiliki tabel sebelumnya dari masa prototipe:

```bash
npx prisma migrate resolve --applied 20261121000000_init
```

### d. Validasi & Regenerasi Client

Jika ada perubahan pada `prisma/schema.prisma`:

```bash
npx prisma validate
npm run prisma:generate
```

---

## 5. Seeding Data Awal

Untuk mengisi data awal berupa akun pengujian (Admin, Buyer, Seller, Regular User):

```bash
npm run db:seed
```

> **Perhatian**:
>
> - Skrip seed bersifat **idempotent** (menggunakan operasi `upsert`). Menjalankannya berulang kali tidak akan menduplikasi data atau menyebabkan error.
> - Skrip seed **menolak berjalan** pada environment `NODE_ENV=production` demi keamanan data riil.

Akun default yang dibuat oleh seeder:

- **Admin**: `admin@rekber.com` (password: `admin123`)
- **Buyer**: `buyer@rekber.com` (password: `buyer123`)
- **Seller**: `seller@rekber.com` (password: `seller123`)
- **User**: `user@rekber.com` (password: `user123`)

---

## 6. Menjalankan Server

### Mode Pengembangan (Development)

Menjalankan server dengan `nodemon` untuk auto-reload saat kode diubah:

```bash
npm run dev
```

### Mode Produksi (Production)

Menjalankan server langsung dengan `node`:

```bash
npm start
```

---

## 7. Verifikasi Health Check

Setelah server berjalan, periksa ketersediaan API melalui endpoint health check:

```bash
curl http://localhost:5000/api/health
```

Contoh respon sukses:

```json
{
  "success": true,
  "message": "Rekber API is running! 🚀",
  "environment": "development",
  "timestamp": "2026-11-21T12:00:00.000Z"
}
```

---

## 8. Ringkasan Perintah (`npm scripts`)

| Perintah                  | Deskripsi                                               |
| :------------------------ | :------------------------------------------------------ |
| `npm run dev`             | Menjalankan server Express dengan hot-reload nodemon    |
| `npm start`               | Menjalankan server Express dengan Node.js               |
| `npm run db:migrate`      | Menjalankan migrasi Prisma untuk development            |
| `npm run db:deploy`       | Menerapkan migrasi tertunda untuk deployment/production |
| `npm run db:seed`         | Menjalankan seeder akun pengujian ke database           |
| `npm run lint`            | Memeriksa kepatuhan kode menggunakan ESLint             |
| `npm run lint:fix`        | Memperbaiki masalah linting otomatis dengan ESLint      |
| `npm run format`          | Memformat kode secara otomatis menggunakan Prettier     |
| `npm run format:check`    | Memeriksa kepatuhan format kode tanpa mengubah file     |
| `npm run prisma:generate` | Menghasilkan Prisma Client terbaru                      |
| `npm run prisma:studio`   | Membuka antarmuka grafis Prisma Studio di browser       |
| `npm test`                | Menjalankan suite pengujian Jest + Supertest            |
| `npm run test:watch`      | Menjalankan Jest dalam mode watch                       |
| `npm run test:coverage`   | Menjalankan Jest dan menghasilkan laporan cakupan kode  |
| `npm run test:ci`         | Menjalankan pengujian untuk pipeline CI/CD              |

---

## 9. Pengujian (Testing)

Harness pengujian backend menggunakan **Jest** dan **Supertest**. Pengujian terisolasi penuh dan menguji endpoint secara nyata tanpa membuka port HTTP server jaringan.

```bash
# Menjalankan seluruh test suite
npm test

# Menjalankan test dengan laporan code coverage
npm run test:coverage
```

> **Aturan Keamanan Database Test**:
> Runner pengujian secara otomatis menolak eksekusi jika `DATABASE_URL_TEST` tidak diset atau nama database tidak berakhiran `_test`. Hal ini mencegah terhapusnya data penting pada database pengembangan maupun produksi secara tidak sengaja.
