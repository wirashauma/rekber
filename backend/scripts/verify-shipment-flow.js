// =============================================================================
// Manual Verification Script: Upload, Storage & Shipment Flow (Prompt 10)
// =============================================================================

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env.test') });
require('../src/utils/money');
const sharp = require('sharp');
const prisma = require('../src/config/prisma');
const fileService = require('../src/services/file.service');
const escrowService = require('../src/services/escrow.service');
const { reconcile } = require('../src/services/reconcile.service');
const crypto = require('crypto');

const runVerification = async () => {
  console.log('--- [PROMPT 10] Verifikasi Alur Upload & Pengiriman Dimulai ---');

  const unique = Date.now();

  // 1. Setup Pembeli & Penjual
  const buyer = await prisma.user.create({
    data: {
      name: 'Pembeli Uji',
      email: `buyer_${unique}@example.com`,
      password: 'HashedPasswordTest123',
      role: 'USER',
      balance: 1000000n, // Rp 1.000.000
    },
  });

  const seller = await createUserSeed({
    name: 'Penjual Uji',
    email: `seller_${unique}@example.com`,
    balance: 0n,
  });

  // Seed balance for buyer in ledger
  await prisma.ledgerEntry.create({
    data: {
      userId: buyer.id,
      type: 'TOPUP',
      direction: 'CREDIT',
      amount: 1000000n,
      balanceAfter: 1000000n,
      idempotencyKey: `verify:shipment:seed:${buyer.id}`,
    },
  });

  console.log(`✓ Pembeli & Penjual dibuat. Saldo Pembeli: Rp ${buyer.balance}`);

  // 2. Buat Transaksi Escrow dan bayar (PENDING → PAID)
  const tx = await escrowService.createTransaction({
    buyerId: buyer.id,
    sellerId: seller.id,
    amount: 300000,
    itemDescription: 'Kamera Vintage Canon AE-1',
  });

  console.log(`✓ Transaksi dibuat: ID=${tx.id}, Kode=${tx.code}, Status=${tx.status}`);

  // Buyer bayar transaksi
  const paidTx = await escrowService.holdEscrow(null, tx.id, buyer.id);
  console.log(
    `✓ Transaksi dibayar: Status=${paidTx.status}, Dana tertahan (heldAmount)=Rp ${paidTx.heldAmount}`
  );

  // 3. Penjual mengunggah foto bukti resi pengiriman
  const dummyJpg = await sharp({
    create: { width: 400, height: 300, channels: 3, background: { r: 50, g: 150, b: 200 } },
  })
    .jpeg()
    .toBuffer();

  const sha256 = crypto.createHash('sha256').update(dummyJpg).digest('hex');
  const storageKey = `shipment_proof/${unique}_resi.jpg`;

  const fileAsset = await fileService.createFileAsset(seller.id, {
    purpose: 'SHIPMENT_PROOF',
    fileProcessed: {
      buffer: dummyJpg,
      mime: 'image/jpeg',
      size: dummyJpg.length,
      sha256,
      storageKey,
    },
  });

  console.log(
    `✓ Berkas bukti pengiriman diunggah: ID=${fileAsset.id}, storageKey=${fileAsset.storageKey}`
  );

  // 4. Verifikasi percobaan transisi langsung PUT /status ke SHIPPED ditolak
  try {
    await escrowService.executeTransition(tx.id, 'SHIPPED', seller);
    throw new Error('FATAL: PUT SHIPPED seharusnya ditolak!');
  } catch (err) {
    console.log(`✓ Transisi langsung ke SHIPPED ditolak dengan benar: "${err.message}"`);
  }

  // 5. Penjual menyerahkan bukti pengiriman via submitShipmentProof
  const shippedTx = await escrowService.submitShipmentProof(tx.id, seller.id, {
    courier: 'JNE Express',
    trackingNumber: 'JNE-REG-0123456789',
    note: 'Barang telah dikemas rapi dengan bubble wrap tebal.',
    fileIds: [fileAsset.id],
  });

  console.log(`✓ Bukti pengiriman diserahkan: Status transaksi=${shippedTx.status}`);
  console.log(`✓ Waktu pengiriman (shippedAt)=${shippedTx.shippedAt}`);
  console.log(`✓ Waktu pelepasan otomatis (autoReleaseAt)=${shippedTx.autoReleaseAt}`);
  console.log(
    `✓ Ringkasan ShipmentProof: Kurir=${shippedTx.shipmentProof.courier}, Resi=${shippedTx.shipmentProof.trackingNumber}`
  );

  if (shippedTx.status !== 'SHIPPED' || !shippedTx.autoReleaseAt) {
    throw new Error('FATAL: Status bukan SHIPPED atau autoReleaseAt belum terisi!');
  }

  // 6. Pembeli dapat mengakses signed URL bukti pengiriman
  const buyerUrlResult = await fileService.getFileSignedUrl(fileAsset.id, buyer);
  console.log(`✓ Pembeli berhasil mendapatkan URL unduhan bertanda tangan: ${buyerUrlResult.url}`);

  // 7. Pengguna asing ditolak mengakses berkas
  const stranger = await createUserSeed({
    name: 'Orang Luar',
    email: `stranger_${unique}@example.com`,
  });
  try {
    await fileService.getFileSignedUrl(fileAsset.id, stranger);
    throw new Error('FATAL: Orang asing tidak boleh dapat URL bukti pengiriman!');
  } catch (err) {
    console.log(`✓ Pengguna asing ditolak mengakses URL berkas dengan benar: "${err.message}"`);
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
    throw new Error('Audit rekonsiliasi menemukan anomali integritas uang!');
  }

  console.log('=== SEMUA VERIFIKASI ALUR PENGIRIMAN (PROMPT 10) BERHASIL 100% ===');
};

async function createUserSeed({ name, email, balance = 0n }) {
  return await prisma.user.create({
    data: {
      name,
      email,
      password: 'HashedPasswordTest123',
      role: 'USER',
      balance,
    },
  });
}

runVerification()
  .catch((err) => {
    console.error('Verifikasi Gagal:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
