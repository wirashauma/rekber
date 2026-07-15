const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const bcrypt = require('bcryptjs');
require('dotenv').config();

// Replicating the initialization logic from src/config/prisma.js
const adapter = new PrismaPg(process.env.DATABASE_URL);
const prisma = new PrismaClient({
  adapter,
});

async function main() {
  console.log('🌱 Seeding database...');

  const adminPasswordHash = await bcrypt.hash('admin123', 10);
  const buyerPasswordHash = await bcrypt.hash('buyer123', 10);
  const sellerPasswordHash = await bcrypt.hash('seller123', 10);
  const userPasswordHash = await bcrypt.hash('user123', 10);

  // Upsert Admin
  const admin = await prisma.user.upsert({
    where: { email: 'admin@rekber.com' },
    update: {
      password: adminPasswordHash,
    },
    create: {
      email: 'admin@rekber.com',
      name: 'Admin Rekber',
      password: adminPasswordHash,
      role: 'ADMIN',
      balance: 1000000,
    },
  });

  // Upsert Buyer
  const buyer = await prisma.user.upsert({
    where: { email: 'buyer@rekber.com' },
    update: {
      password: buyerPasswordHash,
    },
    create: {
      email: 'buyer@rekber.com',
      name: 'Buyer Rekber',
      password: buyerPasswordHash,
      role: 'USER',
      balance: 500000,
    },
  });

  // Upsert Seller
  const seller = await prisma.user.upsert({
    where: { email: 'seller@rekber.com' },
    update: {
      password: sellerPasswordHash,
    },
    create: {
      email: 'seller@rekber.com',
      name: 'Seller Rekber',
      password: sellerPasswordHash,
      role: 'USER',
      balance: 250000,
    },
  });

  // Upsert Regular User
  const user = await prisma.user.upsert({
    where: { email: 'user@rekber.com' },
    update: {
      password: userPasswordHash,
    },
    create: {
      email: 'user@rekber.com',
      name: 'User Rekber',
      password: userPasswordHash,
      role: 'USER',
      balance: 100000,
    },
  });

  console.log('✅ Seeding completed:');
  console.log(`   - Admin : ${admin.email}`);
  console.log(`   - Buyer : ${buyer.email}`);
  console.log(`   - Seller: ${seller.email}`);
  console.log(`   - User  : ${user.email}`);
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
