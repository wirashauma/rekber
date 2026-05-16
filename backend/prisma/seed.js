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

  const passwordHash = await bcrypt.hash('admin123', 10);
  const userPasswordHash = await bcrypt.hash('user123', 10);

  // Upsert Admin
  const admin = await prisma.user.upsert({
    where: { email: 'admin@rekber.com' },
    update: {
      password: passwordHash, // Ensure password is correct
    },
    create: {
      email: 'admin@rekber.com',
      name: 'Admin Rekber',
      password: passwordHash,
      role: 'ADMIN',
      balance: 1000000,
    },
  });

  // Upsert Regular User
  const user = await prisma.user.upsert({
    where: { email: 'user@rekber.com' },
    update: {
      password: userPasswordHash, // Ensure password is correct
    },
    create: {
      email: 'user@rekber.com',
      name: 'User Rekber',
      password: userPasswordHash,
      role: 'USER',
      balance: 500000,
    },
  });

  console.log('✅ Seeding completed:');
  console.log(`   - Admin: ${admin.email}`);
  console.log(`   - User : ${user.email}`);
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
