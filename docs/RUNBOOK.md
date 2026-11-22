# =============================================================================
# RUNBOOK OPERASIONAL REKBER
# =============================================================================
Dokumen ini merupakan panduan operasional teknis untuk tim DevOps, SRE, dan Backend Rekber dalam menjalankan, merawat, memantau, dan menangani insiden pada lingkungan produksi.

---

## 1. Prosedur Backup & Restore PostgreSQL

### 1.1 Jadwal Backup Otomatis
- **Snapshot Harian**: Pukul 02:00 WIB (Low-traffic period).
- **WAL Archiving**: Streaming Continuous Archiving (Point-in-Time Recovery / PITR) diaktifkan ke bucket S3 terenkripsi KMS.
- **Retensi**:
  - Harian: 30 hari.
  - Mingguan: 12 minggu.
  - Bulanan: 12 bulan (untuk audit kepatuhan keuangan).

### 1.2 Prosedur Backup Manual (pg_dump)
Jalankan perintah berikut melalui pod bastion atau server manajemen:
```bash
# Backup seluruh skema dan data terkompresi
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d rekber_db \
  -F c -b -v -f "/backups/rekber_db_${TIMESTAMP}.dump"

# Enkripsi arsip backup menggunakan GPG / AWS KMS
gpg --symmetric --cipher-algo AES256 "/backups/rekber_db_${TIMESTAMP}.dump"

# Upload ke Object Storage S3 backup
aws s3 cp "/backups/rekber_db_${TIMESTAMP}.dump.gpg" \
  s3://$BACKUP_BUCKET/postgres/rekber_db_${TIMESTAMP}.dump.gpg \
  --sse aws:kms --sse-kms-key-id $BACKUP_KMS_KEY
```

### 1.3 Prosedur Restore Database
> [!CAUTION]
> Restore data akan menimpa data yang ada. Pastikan aplikasi berada dalam status `maintenance_mode` sebelum melakukan restore.

```bash
# 1. Aktifkan Maintenance Mode via Admin Panel atau Database
UPDATE "PlatformSetting" SET value = 'true' WHERE key = 'maintenance_mode';

# 2. Hentikan traffic backend
# Kubernetes: kubectl scale deployment/rekber-api --replicas=0
# Docker Compose: docker compose stop api worker

# 3. Dekripsi dan restore
gpg --decrypt "/backups/rekber_db_${TIMESTAMP}.dump.gpg" > "/tmp/restore.dump"
pg_restore -h $DB_HOST -p $DB_PORT -U $DB_USER -d rekber_db \
  --clean --if-exists -v "/tmp/restore.dump"

# 4. Verifikasi integritas data ledger
# Jalankan script audit rekonsiliasi manual
node -e "require('./src/services/reconcile.service').reconcile().then(console.log)"

# 5. Jalankan migrasi Prisma jika terdapat pembaruan skema
npx prisma migrate deploy

# 6. Nyalakan kembali backend dan nonaktifkan maintenance mode
```

---

## 2. Prosedur Rotasi Secret & Kunci Kriptografi

### 2.1 Rotasi JWT Secret
Sistem menggunakan `JWT_SECRET` untuk menandatangani access token (masa berlaku 15 menit) dan verifikasi refresh token (7 hari).
1. Siapkan rahasia baru:
   ```bash
   openssl rand -base64 48
   ```
2. **Dual-Key Validation Window (Transisi Mulus)**:
   - Pasang secret baru sebagai primary signer pada backend.
   - Sediakan fallback verifikasi menggunakan secret lama selama masa transisi maksimum 15 menit (agar access token yang sedang aktif tidak langsung invalid).
3. Setelah 15 menit: Hapus secret lama. User dengan refresh token lama akan melakukan rotasi token secara otomatis tanpa logout paksa.

### 2.2 Rotasi `DATA_ENCRYPTION_KEY` (Key Versioning)
`DATA_ENCRYPTION_KEY` digunakan untuk enkripsi data sensitif (seperti NIK pada tabel `KycSubmission`).
- **Skema Key Versioning**:
  Ciphertext disimpan dengan format prefix versi: `v{version}:{iv}:{encryptedData}:{authTag}` (misal: `v1:abc:def:ghi`).
- **Langkah Rotasi**:
  1. Tambahkan environment variable `DATA_ENCRYPTION_KEY_V2=<kunci-baru-32-bytes>`.
  2. Perbarui `CURRENT_KEY_VERSION=2`.
  3. Sistem tetap menggunakan `DATA_ENCRYPTION_KEY_V1` untuk mendekripsi data berawalan `v1:`, namun mengenkripsi data baru dengan `v2:`.
  4. Jalankan script batch re-encryption di latar belakang untuk memperbarui data lama:
     ```bash
     npm run jobs:re-encrypt-kyc
     ```
  5. Setelah seluruh data lama bermigrasi ke `v2:`, hapus kunci `v1`.

---

## 3. Penanganan Insiden Operasional (SOP)

### 3.1 Selisih Rekonsiliasi Saldo (Reconcile Discrepancy)
- **Indikator**: Alert `rekber_reconcile_discrepancies > 0` atau log level ERROR dari `reconcileDaily`.
- **Tingkat Keparahan**: P1 (Kritis).
- **Prosedur**:
  1. Segera aktifkan status investigasi keuangan. Jika selisih > Rp 1.000.000, aktifkan `maintenance_mode`.
  2. Buka log audit harian:
     ```bash
     grep "CRITICAL: DITEMUKAN SELISIH SALDO" /var/log/rekber/worker.log
     ```
  3. Identifikasi User ID atau Transaction ID yang tercatat pada `userDiscrepancies` atau `escrowDiscrepancies`.
  4. Periksa riwayat mutasi pada tabel `LedgerEntry` untuk user terkait:
     ```sql
     SELECT * FROM "LedgerEntry" WHERE "userId" = '<user-id>' ORDER BY "createdAt" DESC LIMIT 20;
     ```
  5. Bandingkan saldo dompet `Wallet.balance` dengan akumulasi `SUM(amount)` mutasi ledger.
  6. Jika terdapat mutasi ganda akibat race condition yang lolos, buat transaksi penyesuaian manual bertipe `ADJUSTMENT` melalui helper finance admin. Jangan pernah mengedit baris ledger yang sudah ada (append-only ledger).

### 3.2 Webhook Payment Gateway (Xendit) Mati / Tertunda
- **Indikator**: Pengguna melapor sudah transfer namun status transaksi masih `PENDING_PAYMENT`.
- **Prosedur**:
  1. Cek dashboard status Xendit (status.xendit.co) untuk memastikan ketersediaan layanan.
  2. Buka menu Admin Dashboard Rekber -> Top-up Intenets.
  3. Cek log server untuk endpoint `/webhooks/payment`:
     ```bash
     grep "/webhooks/payment" /var/log/rekber/api.log | grep -E "400|500"
     ```
  4. Jalankan sinkronisasi status top-up tertunda:
     - Worker `expireStaleIntents` akan memeriksa invoice yang belum terupdate.
     - Admin dapat memicu pemanggilan manual ke API Xendit untuk memverifikasi invoice ID terkait dan memperbarui status secara otomatis.

### 3.3 Penarikan Dana (Payout) Tertahan
- **Indikator**: Status Withdrawal tetap `APPROVED` namun tidak kunjung `COMPLETED`.
- **Prosedur**:
  1. Periksa `Disbursement` status pada dashboard Xendit.
  2. Jika status pada bank tujuan `REJECTED` (nomor rekening salah / nama tidak cocok):
     - Panggil fungsi penolakan / refund penarikan:
       Kembalikan saldo yang ditahan (`heldBalance`) kembali ke `balance` user beserta audit log alasan pembatalan bank.
  3. Kirim notifikasi push ke pengguna mengenai rekening yang tidak valid.

### 3.4 Dugaan Akun Diretas / Fraud
- **Indikator**: Permintaan transaksi atau penarikan tidak wajar dalam jumlah besar.
- **Prosedur**:
  1. Bekukan akun pengguna:
     ```bash
     POST /api/admin/users/:id/ban { "reason": "Dugaan aktivitas penipuan/peretasan" }
     ```
  2. Cabut semua sesi aktif pengguna terkait:
     ```bash
     POST /api/admin/users/:id/revoke-sessions
     ```
  3. Transaksi yang sedang berlangsung (`PAID` atau `SHIPPED`) akan otomatis dicegah dari pencairan otomatis sampai penyelidikan sengketa selesai.

---

## 4. Prosedur Pembekuan Sistem (System Freeze)

Bila terjadi serangan keamanan, anomali finansial massal, atau proses pemeliharaan database terencana:
1. **Aktifkan Mode Pemeliharaan**:
   - Lewat Admin Panel: **Pengaturan Platform** -> Toggle **Maintenance Mode** = `ON`.
   - Atau via Database SQL:
     ```sql
     UPDATE "PlatformSetting" SET value = 'true' WHERE key = 'maintenance_mode';
     ```
2. **Dampak**:
   - Semua request HTTP pengguna akan menerima respons HTTP `503 Service Unavailable`.
   - Endpoint probe `/api/health`, `/api/health/ready`, `/metrics`, serta webhook pembayaran tetap berjalan agar status sistem dapat dipantau dan callback mitra tidak terputus.

---

## 5. Spesifikasi Aturan Alert (Prometheus Alert Rules)

| Nama Alert | Kondisi / PromQL | Durasi | Tingkat | Tindakan |
| :--- | :--- | :--- | :--- | :--- |
| **ApiHigh5xxRate** | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.01` | 5 menit | P1 - Kritis | Periksa log error Sentry, rollback rilis jika disebabkan deployment baru. |
| **ReconcileDiscrepancyDetected** | `rekber_reconcile_discrepancies > 0` | 1 menit | P1 - Kritis | Freeze keuangan / audit ledger segera sesuai SOP 3.1. |
| **WorkerJobFailureRate** | `increase(rekber_job_failures_total[15m]) > 5` | 15 menit | P2 - Tinggi | Periksa koneksi DB worker dan advisory locks. |
| **DatabasePoolSaturated** | `pg_stat_activity_count / pg_settings_max_connections > 0.85` | 5 menit | P2 - Tinggi | Tambah connection pool atau periksa transaksi lambat yang menggantung. |
| **StalePendingTransactions** | `rekber_transactions_total{status="PENDING_PAYMENT"} > 500` | 30 menit | P3 - Menengah | Verifikasi worker expirePending berjalan normal. |

---

## 6. Kontak & Jalur Eskalasi Tim

- **Incident Commander (IC)**: DevOps Lead (+62 812-XXXX-XXXX)
- **Finance & Compliance Escalation**: Head of Finance Ops (finance-ops@rekber.id)
- **Lead Backend Engineer**: backend-oncall@rekber.id
- **Legal & Risk Advisor**: legal@rekber.id
