// =============================================================================
// Manual Flow Verification: Top-Up -> Simulated Webhook -> Ledger Entry
// =============================================================================

require('dotenv').config({ path: '.env.test' });
const request = require('supertest');
const app = require('../src/app');
const prisma = require('../src/config/prisma');
const { createUser, tokenFor, resetDb } = require('../tests/helpers');
const { getPaymentProvider } = require('../src/providers/payment');

const runManualFlowVerification = async () => {
  console.log('--- 1. Reset Database Test ---');
  await resetDb();

  console.log('--- 2. Create User with Initial Balance 0 ---');
  const user = await createUser({
    name: 'Budi Pembeli',
    email: 'budi.pembeli@test.com',
    balance: 0n,
  });
  const token = tokenFor(user);
  console.log(`User created: ${user.name} (${user.id}), Balance: Rp ${user.balance}`);

  console.log('--- 3. Create Top-Up Intent (POST /api/wallet/topups) ---');
  const topUpRes = await request(app)
    .post('/api/wallet/topups')
    .set('Authorization', `Bearer ${token}`)
    .send({
      amount: 50000,
      method: 'QRIS',
    });

  if (topUpRes.status !== 201) {
    throw new Error(`Failed to create topup: ${JSON.stringify(topUpRes.body)}`);
  }

  const intent = topUpRes.body.data;
  console.log(
    `Top-up Intent Created: ID ${intent.id}, Ref: ${intent.referenceId}, Amount: Rp ${intent.amount}, Status: ${intent.status}`
  );
  console.log(`QR String: ${intent.qrString?.substring(0, 40)}...`);

  const userBefore = await prisma.user.findUnique({ where: { id: user.id } });
  console.log(`Balance before webhook: Rp ${userBefore.balance}`);
  if (userBefore.balance !== 0n) throw new Error('Balance should be 0 before webhook');

  console.log('--- 4. Simulate Payment Gateway Webhook (POST /webhooks/payment/fake) ---');
  const fakeProvider = getPaymentProvider('fake');
  const sim = fakeProvider.simulateWebhook({
    referenceId: intent.referenceId,
    amount: 50000,
    status: 'PAID',
  });

  const webhookRes = await request(app)
    .post('/webhooks/payment/fake')
    .set(sim.headers)
    .send(sim.rawBody);

  console.log(
    `Webhook Response Status: ${webhookRes.status}, Body: ${JSON.stringify(webhookRes.body)}`
  );
  if (webhookRes.status !== 200) throw new Error(`Webhook failed with status ${webhookRes.status}`);

  console.log('--- 5. Verify User Balance and Ledger Entry After Webhook ---');
  const userAfter = await prisma.user.findUnique({ where: { id: user.id } });
  console.log(`User Balance after webhook: Rp ${userAfter.balance}`);
  if (userAfter.balance !== 50000n)
    throw new Error(`Expected balance 50000, got ${userAfter.balance}`);

  const ledgerEntry = await prisma.ledgerEntry.findFirst({
    where: { userId: user.id, type: 'TOPUP' },
  });
  console.log(
    `Ledger Entry Created: ID ${ledgerEntry?.id}, Type: ${ledgerEntry?.type}, Amount: Rp ${ledgerEntry?.amount}, BalanceAfter: Rp ${ledgerEntry?.balanceAfter}, IdempotencyKey: ${ledgerEntry?.idempotencyKey}`
  );
  if (!ledgerEntry || ledgerEntry.amount !== 50000n)
    throw new Error('Ledger entry missing or incorrect');

  const intentAfter = await prisma.paymentIntent.findUnique({ where: { id: intent.id } });
  console.log(
    `Payment Intent Status after webhook: ${intentAfter.status}, PaidAt: ${intentAfter.paidAt}`
  );
  if (intentAfter.status !== 'PAID') throw new Error('Intent should be PAID');

  console.log('--- 6. Test Replay Webhook (Idempotency) ---');
  const replayRes = await request(app)
    .post('/webhooks/payment/fake')
    .set(sim.headers)
    .send(sim.rawBody);
  console.log(
    `Replay Webhook Response: ${replayRes.status}, Body: ${JSON.stringify(replayRes.body)}`
  );

  const userReplay = await prisma.user.findUnique({ where: { id: user.id } });
  console.log(`User Balance after replay: Rp ${userReplay.balance} (Must remain Rp 50000)`);
  if (userReplay.balance !== 50000n) throw new Error('Balance doubled on replay!');

  const countLedger = await prisma.ledgerEntry.count({ where: { userId: user.id, type: 'TOPUP' } });
  console.log(`Total TOPUP ledger entries: ${countLedger} (Must be exactly 1)`);
  if (countLedger !== 1) throw new Error('Duplicate ledger entry created on replay!');

  console.log('\n✅ VERIFIKASI ALUR MANUAL BERHASIL 100% TANPA KESALAHAN! ✅\n');
};

runManualFlowVerification()
  .catch((err) => {
    console.error('❌ Verification failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
