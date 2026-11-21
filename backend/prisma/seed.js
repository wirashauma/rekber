const fs = require('fs');
const path = require('path');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const bcrypt = require('bcryptjs');
require('dotenv').config();

if (!process.env.DATABASE_URL) {
  const fallbackEnv = fs.existsSync(path.resolve(__dirname, '../.env'))
    ? path.resolve(__dirname, '../.env')
    : path.resolve(__dirname, '../.env.test');
  require('dotenv').config({ path: fallbackEnv });
}

// Enforce guard: seeding must never run in production
if (process.env.NODE_ENV === 'production') {
  console.error('❌ Seeding tidak diizinkan pada environment production.');
  process.exit(1);
}

if (!process.env.DATABASE_URL) {
  console.error('❌ DATABASE_URL wajib diisi untuk menjalankan seeding.');
  process.exit(1);
}

// Replicating the initialization logic from src/config/prisma.js
const adapter = new PrismaPg(process.env.DATABASE_URL);
const prisma = new PrismaClient({
  adapter,
});

async function main() {
  console.log('🌱 Menjalankan seed database...');

  const adminPasswordHash = await bcrypt.hash('admin123', 10);
  const buyerPasswordHash = await bcrypt.hash('buyer123', 10);
  const sellerPasswordHash = await bcrypt.hash('seller123', 10);
  const userPasswordHash = await bcrypt.hash('user123', 10);

  // Upsert Admin (idempotent)
  const admin = await prisma.user.upsert({
    where: { email: 'admin@rekber.com' },
    update: {
      password: adminPasswordHash,
      balance: 1000000n,
    },
    create: {
      email: 'admin@rekber.com',
      name: 'Admin Rekber',
      password: adminPasswordHash,
      role: 'ADMIN',
      balance: 1000000n,
    },
  });

  // Upsert Buyer (idempotent)
  const buyer = await prisma.user.upsert({
    where: { email: 'buyer@rekber.com' },
    update: {
      password: buyerPasswordHash,
      balance: 500000n,
    },
    create: {
      email: 'buyer@rekber.com',
      name: 'Buyer Rekber',
      password: buyerPasswordHash,
      role: 'USER',
      balance: 500000n,
    },
  });

  // Upsert Seller (idempotent)
  const seller = await prisma.user.upsert({
    where: { email: 'seller@rekber.com' },
    update: {
      password: sellerPasswordHash,
      balance: 250000n,
    },
    create: {
      email: 'seller@rekber.com',
      name: 'Seller Rekber',
      password: sellerPasswordHash,
      role: 'USER',
      balance: 250000n,
    },
  });

  // Upsert Regular User (idempotent)
  const user = await prisma.user.upsert({
    where: { email: 'user@rekber.com' },
    update: {
      password: userPasswordHash,
      balance: 100000n,
    },
    create: {
      email: 'user@rekber.com',
      name: 'User Rekber',
      password: userPasswordHash,
      role: 'USER',
      balance: 100000n,
    },
  });

  // Seed initial ledger entries for users with balance so double-entry books reconcile
  const seededUsers = [admin, buyer, seller, user];
  for (const u of seededUsers) {
    if (u.balance > 0n) {
      await prisma.ledgerEntry.upsert({
        where: { idempotencyKey: `seed:user:${u.id}:initial` },
        update: {
          amount: u.balance,
          balanceAfter: u.balance,
        },
        create: {
          userId: u.id,
          type: 'ADJUSTMENT',
          direction: 'CREDIT',
          amount: u.balance,
          balanceAfter: u.balance,
          idempotencyKey: `seed:user:${u.id}:initial`,
          referenceType: 'SEED',
          metadata: { note: 'Initial seed balance' },
        },
      });
    }
  }

  // Seed default platform settings
  const defaultSettings = [
    { key: 'fee_percent', value: '2' },
    { key: 'fee_min', value: '1000' },
    { key: 'fee_payer_default', value: 'SPLIT' },
    { key: 'auto_release_hours', value: '72' },
    { key: 'pending_expire_hours', value: '24' },
    { key: 'withdraw_min', value: '50000' },
    { key: 'withdraw_fee', value: '0' },
    { key: 'withdraw_daily_limit', value: '10000000' },
    { key: 'max_transaction_amount', value: '5000000' },
    { key: 'maintenance_mode', value: 'false' },
  ];

  for (const s of defaultSettings) {
    await prisma.platformSetting.upsert({
      where: { key: s.key },
      update: { value: s.value },
      create: { key: s.key, value: s.value },
    });
  }

  console.log('✅ Seeding berhasil diselesaikan:');
  console.log(`   - Admin : ${admin.email}`);
  console.log(`   - Buyer : ${buyer.email}`);
  console.log(`   - Seller: ${seller.email}`);
  console.log(`   - User  : ${user.email}`);
  console.log(`   - Platform Settings: ${defaultSettings.length} konfigurasi di-seed`);
}

main()
  .catch((e) => {
    console.error('❌ Gagal menjalankan seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
