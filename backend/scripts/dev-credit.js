#!/usr/bin/env node
// =============================================================================
// dev-credit.js - Local Development Helper to Credit User Balances via Ledger
// =============================================================================

const fs = require('fs');
const path = require('path');
require('dotenv').config();
if (!process.env.DATABASE_URL) {
  const fallbackEnv = fs.existsSync(path.resolve(__dirname, '../.env'))
    ? path.resolve(__dirname, '../.env')
    : path.resolve(__dirname, '../.env.test');
  require('dotenv').config({ path: fallbackEnv });
}
const prisma = require('../src/config/prisma');
const ledgerService = require('../src/services/ledger.service');

const main = async () => {
  if (process.env.NODE_ENV === 'production') {
    console.error('DILARANG: Skrip dev-credit tidak boleh dijalankan di lingkungan production.');
    process.exit(1);
  }

  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.log('Penggunaan: node scripts/dev-credit.js <email_atau_userId> <nominal>');
    console.log('Contoh:     node scripts/dev-credit.js user@example.com 500000');
    process.exit(1);
  }

  const [identifier, amountStr] = args;
  const nominal = parseInt(amountStr, 10);

  if (isNaN(nominal) || nominal <= 0) {
    console.error('Error: Nominal harus berupa bilangan bulat positif.');
    process.exit(1);
  }

  const user = await prisma.user.findFirst({
    where: {
      OR: [{ id: identifier }, { email: identifier }],
    },
  });

  if (!user) {
    console.error(`Error: Pengguna dengan pengenal "${identifier}" tidak ditemukan.`);
    process.exit(1);
  }

  const idempotencyKey = `dev-credit:${user.id}:${Date.now()}`;

  const entry = await prisma.$transaction(async (tx) => {
    return await ledgerService.credit(tx, {
      userId: user.id,
      amount: nominal,
      type: 'ADJUSTMENT',
      idempotencyKey,
      referenceType: 'DEV_TOOL',
      metadata: {
        reason: 'Local development credit',
        timestamp: new Date().toISOString(),
      },
    });
  });

  const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });

  console.log('====================================================');
  console.log('✅ Saldo Berhasil Ditambahkan');
  console.log('====================================================');
  console.log(`User ID       : ${user.id}`);
  console.log(`Email         : ${user.email}`);
  console.log(`Nominal       : Rp ${nominal.toLocaleString('id-ID')}`);
  console.log(`Saldo Baru    : Rp ${Number(updatedUser.balance).toLocaleString('id-ID')}`);
  console.log(`Ledger ID     : ${entry.id}`);
  console.log(`IdempotencyKey: ${idempotencyKey}`);
  console.log('====================================================');
};

main()
  .catch((err) => {
    console.error('Gagal menjalankan dev-credit:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
