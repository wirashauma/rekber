# =============================================================================
# CHECKLIST RILIS & KESIAPAN GO-LIVE REKBER
# =============================================================================
Dokumen ini merangkum seluruh prasyarat teknis, hukum, infrastruktur, dan operasional yang wajib dipenuhi sebelum aplikasi Rekber dirilis ke lingkungan produksi publik.

---

## 1. Status Legalitas & Peninjauan Regulasi

- [ ] **Review Konsultan Hukum (Final T&C & Privacy Policy)**:
  > [!IMPORTANT]
  > Teks Syarat & Ketentuan serta Kebijakan Privasi yang saat ini tertanam pada aplikasi mobile (`LegalScreen`) berstatus **DRAFT / PLACEHOLDER TEKNIS** yang dilengkapi banner penafian (*disclaimer*). Sebelum rilis publik ke Google Play Store dan Apple App Store, dokumen ini wajib digantikan dengan naskah perjanjian hukum final yang telah disetujui oleh konsultan hukum berlisensi Indonesia.
- [ ] **Kepatuhan Perlindungan Data Pribadi (UU PDP No. 27/2022)**:
  - Verifikasi persetujuan (*explicit consent*) pemrosesan data KTP dan swafoto untuk verifikasi identitas (KYC).
  - Kebijakan retensi dan pemusnahan dokumen identitas setelah penutupan akun.
- [ ] **Pemberitahuan / Izin Penyelenggara Jasa Pembayaran (PJP Bank Indonesia)**:
  - Memastikan integrasi escrow telah sesuai dengan model kemitraan *payment aggregator* / PJP berizin (Xendit).

---

## 2. Konfigurasi Payment Gateway & Rekening Escrow

- [ ] **Penyerahan Kunci Produksi Xendit**:
  - Ganti `PAYMENT_PROVIDER=fake` menjadi `PAYMENT_PROVIDER=xendit`.
  - Pasang `XENDIT_SECRET_KEY` produksi (diawali dengan `xnd_production_...`).
  - Pasang `XENDIT_WEBHOOK_VERIFICATION_TOKEN` resmi dari dashboard Xendit produksi.
- [ ] **Konfigurasi Webhook URL**:
  - URL Webhook Pembayaran: `https://api.rekber.id/webhooks/payment`
  - URL Webhook Penarikan (Disbursement): `https://api.rekber.id/webhooks/disbursement`
- [ ] **IP Whitelist**:
  - Pastikan IP server API Rekber telah didaftarkan pada whitelist IP Xendit Dashboard untuk penarikan dana (Disbursements API).
  - Pastikan firewall / reverse proxy Rekber mengizinkan incoming IP dari rentang IP resmi Xendit.

---

## 3. Infrastruktur, Jaringan, dan Keamanan Server

- [ ] **Terminasi TLS / HTTPS**:
  - Pasang sertifikat SSL/TLS valid (Grade A+ Qualys SSL Labs) pada domain `api.rekber.id`.
  - Aktifkan HTTP Strict Transport Security (HSTS) dengan `max-age=31536000; includeSubDomains; preload`.
  - Verifikasi bahwa aplikasi mobile menolak koneksi HTTP non-aman (`usesCleartextTraffic="false"`).
- [ ] **CORS Origin Strict White-listing**:
  - Konfigurasi `CORS_ORIGIN` hanya ke domain resmi admin web/dashboard, misal: `https://admin.rekber.id`. Tolak wildcard `*` pada lingkungan produksi.
- [ ] **Storage S3 Produksi**:
  - Ubah `STORAGE_PROVIDER=local` menjadi `STORAGE_PROVIDER=s3`.
  - Buat bucket S3 privat (Block Public Access 100% aktif).
  - Pasang `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, dan `S3_REGION`.
- [ ] **Kunci Kriptografi Mandiri**:
  - Buat kunci enkripsi 32-byte acak berkekuatan tinggi untuk `DATA_ENCRYPTION_KEY`.
  - Buat secret 64-byte acak untuk `JWT_SECRET`.
  - Buat token rahasia untuk scraping metrik Prometheus `METRICS_TOKEN`.

---

## 4. Konfigurasi Aplikasi Mobile Android

- [ ] **Keystore & Signing Android**:
  - Buat release keystore menggunakan `keytool` dan simpan file `upload-keystore.jks` secara aman.
  - Buat file `mobile/android/key.properties` berdasarkan `key.properties.example`.
  - Pastikan `key.properties` dan file keystore tidak ter-commit ke Git.
- [ ] **Izin Manifest Minimal**:
  - Verifikasi `AndroidManifest.xml` hanya meminta izin yang mutlak diperlukan (`INTERNET`, `POST_NOTIFICATIONS`, `CAMERA`).
- [ ] **Pemberian Nama & Identitas Aplikasi**:
  - Pastikan `applicationId` pada `build.gradle.kts` telah sesuai (misal: `id.rekber.app`).
  - Ganti app icon resolusi tinggi untuk seluruh folder `mipmap-*dpi`.
- [ ] **Build Perintah Android Release**:
  ```bash
  flutter build appbundle --release \
    --dart-define=API_BASE_URL=https://api.rekber.id/api \
    --dart-define=SENTRY_DSN=https://xxx@sentry.io/yyy \
    --dart-define=SUPPORT_WHATSAPP=6281234567890
  ```

---

## 5. Panduan Konfigurasi Rilis iOS (Apple App Store)

Konfigurasi manual yang wajib dilakukan pada direktori `mobile/ios/`:
1. **Info.plist Permission Strings**:
   Tambahkan deskripsi penggunaan izin ramah pengguna dalam bahasa Indonesia:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Rekber membutuhkan akses kamera untuk mengambil foto KTP dan swafoto saat verifikasi identitas (KYC) serta bukti transaksi barang.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Rekber membutuhkan akses galeri untuk mengunggah dokumen identitas dan lampiran bukti transaksi.</string>
   ```
2. **App Transport Security (ATS)**:
   Pastikan ATS aktif tanpa pengecualian `NSAllowsArbitraryLoads`:
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsArbitraryLoads</key>
       <false/>
   </dict>
   ```
3. **Bundle Identifier & Signing**:
   - Buka project di Xcode (`open mobile/ios/Runner.xcworkspace`).
   - Atur Bundle Identifier (misal: `id.rekber.app`).
   - Pilih Team Pengembang Apple Developer Program dan aktifkan Automatically Manage Signing.
4. **Build Archive iOS**:
   ```bash
   flutter build ipa --release \
     --dart-define=API_BASE_URL=https://api.rekber.id/api \
     --dart-define=SENTRY_DSN=https://xxx@sentry.io/yyy \
     --dart-define=SUPPORT_WHATSAPP=6281234567890
   ```

---

## 6. Prosedur Smoke Test Pasca-Rilis (Production Verification)

Setelah deployment selesai di lingkungan produksi, lakukan smoke test berikut secara langsung:
1. **Pemeriksaan Health & Kesiapan Sistem**:
   - Panggil `GET https://api.rekber.id/api/health` -> Wajib return 200 `{ status: "healthy" }`.
   - Panggil `GET https://api.rekber.id/api/health/ready` -> Wajib return 200 `{ status: "ready", database: "connected" }`.
   - Panggil `GET https://api.rekber.id/metrics` dengan `X-Metrics-Token` -> Wajib return metrik teks Prometheus.
2. **Alur Otentikasi & Akun**:
   - Daftarkan satu akun tester baru dan verifikasi penerimaan JWT.
   - Uji ubah password dan pastikan token sesi diperbarui.
3. **Alur Transaksi & Pembayaran Minimal**:
   - Buat transaksi nominal uji coba (misal: Rp 10.000).
   - Buat invoice pembayaran via payment gateway dan bayar melalui QRIS / Virtual Account nyata.
   - Pastikan webhook diterima dan status transaksi beralih ke `PAID`.
   - Konfirmasi pengiriman dan penyelesaian transaksi -> Cek saldo penjual bertambah.
4. **Verifikasi Zero Discrepancy**:
   - Jalankan audit rekonsiliasi manual pasca uji coba untuk memastikan selisih tetap 0.

---

## 7. Batasan Closed Beta & Mitigasi Risiko

Untuk memitigasi risiko finansial pada tahap awal peluncuran publik:
- **Batas Pengguna Tahap Awal**: Maksimum 200 pengguna terdaftar pertama.
- **Batas Nilai Transaksi**:
  - Nilai transaksi maksimum per transaksi: Rp 2.000.000 (diatur via `PlatformSetting` `max_transaction_amount`).
  - Batas penarikan harian per pengguna: Rp 5.000.000 (diatur via `withdraw_daily_limit`).
- **Verifikasi KYC Wajib**: Penarikan dana diwajibkan melewati persetujuan KYC manual oleh admin (`assertCanWithdraw`).

---

## 8. Rencana Rollback (Rollback Plan)

Jika ditemukan anomali kritis pasca deployment (misal: crash loop, kebocoran saldo, kegagalan webhook):
1. **Segera Bekukan Sistem**:
   ```sql
   UPDATE "PlatformSetting" SET value = 'true' WHERE key = 'maintenance_mode';
   ```
2. **Rollback Container Backend**:
   - **Kubernetes**:
     ```bash
     kubectl rollout undo deployment/rekber-api
     kubectl rollout undo deployment/rekber-worker
     ```
   - **Docker / Virtual Machine**:
     Ganti tag image ke versi stabil sebelumnya pada `docker-compose.yml` lalu jalankan:
     ```bash
     docker compose up -d --no-deps api worker
     ```
3. **Rollback Database**:
   - Skema database diupayakan selalu *backward-compatible* (expand and contract pattern).
   - Jika migrasi merusak skema, restore snapshot database sebelum deployment sesuai panduan di `docs/RUNBOOK.md`.
4. **Nonaktifkan Maintenance Mode**:
   Setelah sistem stabil pada versi sebelumnya, kembalikan `maintenance_mode = 'false'`.
