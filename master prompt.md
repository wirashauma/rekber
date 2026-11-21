MASTER PROMPT — PROYEK REKBER
Berlaku untuk SEMUA prompt bernomor. Jika bertentangan dengan prompt bernomor, Master yang menang.

1. KONTEKS
Rekber adalah platform escrow (rekening bersama) untuk Indonesia. Monorepo: backend/ (Node.js, Express 5, Prisma 7 + @prisma/adapter-pg, PostgreSQL) dan mobile/ (Flutter: go_router, get_it, flutter_bloc, dartz). Awalnya prototipe: banyak layar mobile masih mock dan uang masih saldo virtual tanpa gateway. Rangkaian 20 prompt membawanya ke siap produksi secara bertahap. Satu sesi = satu prompt bernomor. Kerjakan HANYA prompt yang diberikan.

2. ATURAN GIT (WAJIB, TANPA PENGECUALIAN)
- DILARANG menjalankan: git add, commit, push, stash, reset, restore, checkout (yang menimpa file), clean, rebase, merge, branch, tag, cherry-pick.
- BOLEH (hanya baca): git status, git diff, git log, git show.
- Biarkan semua perubahan sebagai uncommitted. Pemilik proyek yang me-review dan commit.
- Jangan menghapus file permanen kecuali prompt berkata 'hapus'. Bila file harus dipindah/diarsipkan, pindahkan ke folder _archive/ di root repo.

3. ATURAN LINGKUP
a. Kerjakan hanya yang tertulis di TUGAS. Area milik prompt lain (lihat Peta Kepemilikan) tidak boleh diubah; pakai antarmuka yang sudah ada.
b. Temuan di luar lingkup: catat di laporan (butir 5), JANGAN diperbaiki.
c. Periksa PRASYARAT dulu (cek keberadaan file/model/endpoint yang disebut). Jika tidak terpenuhi: BERHENTI dan laporkan. Jangan mengerjakan prompt sebelumnya.
d. Jangan merombak gaya, struktur folder, atau penamaan yang ada. Ikuti konvensi kode yang ada.
e. Nomor baris/nama file dari laporan audit mungkin sudah bergeser: cari dengan grep, jangan menebak.
f. Jangan menambah dependensi selain yang disebut prompt. Pakai versi stabil terbaru yang kompatibel; sebut setiap dependensi baru di laporan.
g. Jangan mengubah perilaku yang sudah diselesaikan prompt sebelumnya; hanya memakai atau menambah. Bila sebuah prompt SENGAJA mengubah perilaku lama, test lama yang terdampak boleh diperbarui, dengan daftar dan alasannya di laporan.
h. Jangan mengarang detail API pihak ketiga (payment gateway, FCM, S3, dsb.): baca dokumentasi resmi terbaru. Bila tidak dapat diakses, berhenti dan laporkan.

4. KEAMANAN DAN DATA
- Jangan menulis, mencetak, atau menyimpan rahasia (password, API key, token, isi .env) di kode atau laporan. Semua lewat variabel env; tambahkan nama variabel ke .env.example dengan nilai placeholder.
- Jangan membuka atau menimpa file .env asli.
- Jangan menjalankan migrasi/seed/skrip terhadap database selain lokal atau test. Test hanya boleh berjalan bila DATABASE_URL_TEST diset dan nama database berakhiran _test.
- Setelah Prompt 6, SEMUA perubahan saldo harus lewat ledger.service. Dilarang meng-update kolom balance secara langsung.
- Teks untuk pengguna (pesan error, UI) dalam Bahasa Indonesia; kode, nama variabel, dan komentar ikut konvensi yang ada.

5. STANDAR TEST
- Backend: Jest + Supertest (dibuat di Prompt 2). Mobile: flutter_test + bloc_test + mocktail.
- Setiap perubahan logika wajib disertai test: happy path, kasus gagal, dan otorisasi.
- Dilarang menghapus atau melemahkan test agar lulus.
- Jalankan backend: npm test dan npm run lint; mobile: flutter analyze dan flutter test. Laporkan hasil apa adanya, termasuk yang gagal. Jangan menyatakan lulus tanpa menjalankannya; jika perintah tidak dapat dijalankan, katakan alasannya.

6. KEPUTUSAN DEFAULT (pemilik: ubah sebelum dipakai bila berbeda)
- Backend: Express + Prisma + PostgreSQL. Supabase diarsipkan (Prompt 1).
- Auth: JWT sendiri. Access token 15 menit; refresh token berotasi 30 hari, disimpan sebagai hash. Firebase hanya untuk FCM.
- Uang: BigInt rupiah bulat di database; API menerima/mengirim integer. Tanpa desimal.
- Status transaksi (kanonik, huruf besar): PENDING, PAID, SHIPPED, COMPLETED, CANCELLED, DISPUTED, REFUNDED.
- Fee platform: 2% dari harga (dibulatkan ke atas), minimum Rp 1.000; pembayar BUYER/SELLER/SPLIT (default SPLIT). Refund mengembalikan harga + fee pembeli.
- Auto-release: 72 jam setelah SHIPPED. PENDING kedaluwarsa: 24 jam.
- Penarikan: minimum Rp 50.000, biaya Rp 0, batas harian Rp 10.000.000, wajib KYC APPROVED, setiap penarikan perlu persetujuan admin.
- Batas nilai transaksi selama beta: Rp 5.000.000 (setting max_transaction_amount).
- Penyedia pembayaran: Xendit (sandbox dulu) lewat interface PaymentProvider. GANTI nilai ini bila memakai penyedia lain.
- Storage file: interface StorageProvider; lokal untuk dev, S3-compatible untuk production. Gambar jpg/png/webp, maks 5 MB.
- Chat: Socket.IO + REST. Hanya peserta transaksi; admin hanya saat DISPUTED.
- Di luar v1: Asisten AI (disembunyikan, file tidak dihapus) dan PIN transaksi (bagian UI disembunyikan).
- Waktu disimpan UTC, ditampilkan WIB (Asia/Jakarta).

7. PETA KEPEMILIKAN (siapa boleh mengubah apa)
P1 config/env, migrasi baseline, dependensi, lint backend
P2 harness test backend
P3 auth backend, rate limit, error handler, logging, CORS
P4 auth mobile, ApiService (token/baseUrl/401), guard router
P5 skema uang, LedgerEntry, PlatformSetting
P6 ledger.service, escrow.service, rute transactions dan wallet dasar, config publik
P7 test keuangan
P8 provider pembayaran, top-up, webhook
P9 rekening bank, penarikan, payout
P10 storage, upload, bukti pengiriman
P11 sengketa backend
P12 notifikasi, scheduler/worker
P13 chat backend
P14 KYC, API admin, audit log
P15 mobile transaksi dan dompet
P16 mobile sengketa, chat, notifikasi
P17 mobile admin, KYC, keamanan akun
P18 test mobile
P19 E2E, keamanan, beban
P20 deployment, observabilitas, rilis

8. FORMAT LAPORAN AKHIR (wajib)
1) Ringkasan 3-5 kalimat. 2) File dibuat/diubah/dipindah/dihapus. 3) Perintah verifikasi yang dijalankan + hasil ringkas. 4) Keputusan default atau asumsi yang dipakai. 5) Temuan di luar lingkup (tidak diperbaiki). 6) Langkah manual untuk pemilik (env, kunci, review). 7) Konfirmasi: 'Tidak ada perintah git yang mengubah repo dijalankan.'