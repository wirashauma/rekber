// =============================================================================
// Manual Verification Script: Bank Accounts, Withdrawals & Payout Lifecycle
// =============================================================================

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env.test') });
require('../src/utils/money');
const prisma = require('../src/config/prisma');
const { getPaymentProvider } = require('../src/providers/payment');
const bankAccountService = require('../src/services/bankAccount.service');
const withdrawalService = require('../src/services/withdrawal.service');
const { reconcile } = require('../src/services/reconcile.service');
const { decrypt } = require('../src/utils/encryption');

const runVerification = async () => {
  console.log('--- [PROMPT 9] Verifikasi Alur Penarikan & Payout Dimulai ---');

  // 1. Setup Platform Settings
  await prisma.platformSetting.upsert({
    where: { key: 'withdraw_min' },
    update: { value: '50000' },
    create: { key: 'withdraw_min', value: '50000' },
  });
  await prisma.platformSetting.upsert({
    where: { key: 'withdraw_fee' },
    update: { value: '4500' },
    create: { key: 'withdraw_fee', value: '4500' },
  });
  await prisma.platformSetting.upsert({
    where: { key: 'withdraw_daily_limit' },
    update: { value: '10000000' },
    create: { key: 'withdraw_daily_limit', value: '10000000' },
  });

  // 2. Setup User & Admin
  const unique = Date.now();
  const user = await prisma.user.create({
    data: {
      name: 'Rian Pratama',
      email: `rian_${unique}@example.com`,
      password: 'HashedPasswordTest123',
      role: 'USER',
      balance: 1000000n, // Rp 1.000.000
    },
  });

  const admin = await prisma.user.create({
    data: {
      name: 'Admin Rekber',
      email: `admin_${unique}@example.com`,
      password: 'HashedPasswordTest123',
      role: 'ADMIN',
      balance: 0n,
    },
  });

  // Record initial ledger entry for user seed balance
  await prisma.ledgerEntry.create({
    data: {
      userId: user.id,
      type: 'TOPUP',
      direction: 'CREDIT',
      amount: 1000000n,
      balanceAfter: 1000000n,
      idempotencyKey: `verify:seed:${user.id}`,
    },
  });

  console.log(`✓ Pengguna & Admin berhasil dibuat. Saldo awal pengguna: Rp ${user.balance}`);

  // 3. User registers a bank account
  const bankAcc = await bankAccountService.createBankAccount(user.id, {
    bankCode: 'BCA',
    accountNumber: '5412345678',
    accountName: 'Rian Pratama',
    isDefault: true,
  });

  console.log(
    `✓ Rekening bank terdaftar: ${bankAcc.bankCode} ${bankAcc.accountNumberMasked} (${bankAcc.accountName})`
  );

  // Verify encryption in DB
  const rawDbAcc = await prisma.bankAccount.findUnique({ where: { id: bankAcc.id } });
  if (rawDbAcc.accountNumberEnc === '5412345678') {
    throw new Error('FATAL: Nomor rekening tersimpan dalam bentuk plaintext di database!');
  }
  const decrypted = decrypt(rawDbAcc.accountNumberEnc);
  if (decrypted !== '5412345678') {
    throw new Error(`FATAL: Dekripsi nomor rekening tidak cocok: ${decrypted}`);
  }
  console.log('✓ Enkripsi AES-256-GCM nomor rekening terverifikasi di level basis data.');

  // 4. User initiates withdrawal (Rp 200.000 + Rp 4.500 fee = Rp 204.500)
  const withdrawRes = await withdrawalService.createWithdrawal(user.id, {
    bankAccountId: bankAcc.id,
    amount: 200000,
    idempotencyKey: `verify_withdraw_key_${unique}`,
  });

  const userAfterWithdraw = await prisma.user.findUnique({ where: { id: user.id } });
  console.log(`✓ Permintaan penarikan dibuat: ID=${withdrawRes.id}, Status=${withdrawRes.status}`);
  console.log(
    `✓ Saldo langsung terpotong WITHDRAWAL_RESERVE: Rp ${userAfterWithdraw.balance} (Sisa: 795.500)`
  );
  if (userAfterWithdraw.balance !== 795500n) {
    throw new Error(`Mismatch saldo: diharapkan 795500n, aktual ${userAfterWithdraw.balance}`);
  }

  // 5. Admin lists withdrawals and inspects nameMatch
  const adminList = await withdrawalService.getAdminWithdrawals({ status: 'PENDING_REVIEW' });
  const pendingItem = adminList.items.find((i) => i.id === withdrawRes.id);
  console.log(
    `✓ Admin melihat permintaan penarikan: nameMatch=${JSON.stringify(pendingItem.nameMatch)}`
  );

  // 6. Admin approves withdrawal
  const approvedItem = await withdrawalService.approveWithdrawal(withdrawRes.id, admin.id);
  console.log(`✓ Admin menyetujui penarikan: Status baru=${approvedItem.status}`);

  // 7. Payment Provider Webhook: Payout COMPLETED
  const fakeProvider = getPaymentProvider('fake');
  const simCompleted = fakeProvider.simulatePayoutWebhook({
    referenceId: withdrawRes.id,
    amount: 200000,
    status: 'COMPLETED',
    eventId: `verify_payout_evt_${unique}`,
  });

  // Process webhook atomically via topupService (which handles all payment webhooks)
  const topupService = require('../src/services/topup.service');
  const webhookResult = await topupService.processWebhook({
    providerName: 'fake',
    headers: simCompleted.headers,
    rawBody: simCompleted.rawBody,
  });

  console.log(`✓ Webhook payout COMPLETED diproses: ${JSON.stringify(webhookResult)}`);

  const finalWithdrawal = await prisma.withdrawalRequest.findUnique({
    where: { id: withdrawRes.id },
  });
  console.log(`✓ Status akhir penarikan di basis data: ${finalWithdrawal.status}`);
  if (finalWithdrawal.status !== 'COMPLETED') {
    throw new Error(`Status tidak COMPLETED: ${finalWithdrawal.status}`);
  }

  // 8. Reconcile Audit Check
  console.log('--- Menjalankan Audit Rekonsiliasi Buku Besar & Saldo ---');
  const audit = await reconcile();
  console.log(`✓ Total pengguna diaudit: ${audit.stats.totalUsersAudited}`);
  console.log(`✓ Total transaksi diaudit: ${audit.stats.totalTransactionsAudited}`);
  console.log(
    `✓ Status rekonsiliasi: ${audit.isReconciled ? 'SEIMBANG (0 Discrepancy)' : 'GAGAL'}`
  );
  if (!audit.isReconciled) {
    console.error('Ketidaksesuaian audit user:', audit.userDiscrepancies);
    console.error('Ketidaksesuaian audit escrow:', audit.escrowDiscrepancies);
    throw new Error('Audit rekonsiliasi menemukan anomali integritas uang!');
  }

  console.log('=== SEMUA VERIFIKASI ALUR PENARIKAN (PROMPT 9) BERHASIL 100% ===');
};

runVerification()
  .catch((err) => {
    console.error('Verifikasi Gagal:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
