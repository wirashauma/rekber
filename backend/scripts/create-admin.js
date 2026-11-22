// =============================================================================
// CLI Script: Create Initial Platform Administrator
// =============================================================================
// Interactively prompts for admin credentials from terminal and registers
// an administrator account. Password is not saved to files or logs.

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
require('dotenv').config({ path: path.resolve(__dirname, '../.env.test') });
require('../src/utils/money');

const readline = require('readline');
const bcrypt = require('bcryptjs');
const prisma = require('../src/config/prisma');

const promptQuestion = (rl, query) => {
  return new Promise((resolve) => {
    rl.question(query, (answer) => {
      resolve(answer.trim());
    });
  });
};

const createAdmin = async () => {
  console.log('='.repeat(60));
  console.log('🛡️  REKBER - Pembuatan Akun Administrator Pertama');
  console.log('='.repeat(60));

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    let name = process.env.ADMIN_NAME;
    let email = process.env.ADMIN_EMAIL;
    let password = process.env.ADMIN_PASSWORD;

    // Prompt if not provided via env
    if (!name) {
      name = await promptQuestion(rl, 'Masukkan Nama Administrator (default: Super Admin): ');
      if (!name) name = 'Super Admin';
    }

    if (!email) {
      while (!email) {
        const input = await promptQuestion(rl, 'Masukkan Email Administrator: ');
        if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input)) {
          email = input.toLowerCase();
        } else {
          console.log('❌ Format email tidak valid. Silakan coba lagi.');
        }
      }
    }

    if (!password) {
      while (!password) {
        const input = await promptQuestion(
          rl,
          'Masukkan Password Administrator (min 8 karakter): '
        );
        if (input.length >= 8) {
          password = input;
        } else {
          console.log('❌ Password harus terdiri dari minimal 8 karakter.');
        }
      }
    }

    rl.close();

    // Check if user already exists
    const existing = await prisma.user.findUnique({
      where: { email },
    });

    const hashedPassword = await bcrypt.hash(password, 10);

    if (existing) {
      const updated = await prisma.user.update({
        where: { email },
        data: {
          role: 'ADMIN',
          kycStatus: 'APPROVED',
          isActive: true,
          password: hashedPassword,
        },
      });

      console.log('='.repeat(60));
      console.log(`✅ Pengguna yang ada (${updated.email}) berhasil ditingkatkan menjadi ADMIN!`);
      console.log(`🆔 ID Admin: ${updated.id}`);
      console.log('='.repeat(60));
    } else {
      const created = await prisma.user.create({
        data: {
          name,
          email,
          password: hashedPassword,
          role: 'ADMIN',
          kycStatus: 'APPROVED',
          isActive: true,
          balance: 0n,
        },
      });

      console.log('='.repeat(60));
      console.log(`✅ Akun Administrator baru berhasil dibuat!`);
      console.log(`📧 Email   : ${created.email}`);
      console.log(`🆔 ID Admin: ${created.id}`);
      console.log(`👑 Peran   : ${created.role}`);
      console.log('='.repeat(60));
    }
  } catch (err) {
    console.error('❌ Gagal membuat admin:', err.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
};

createAdmin();
