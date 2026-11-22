const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const prisma = require('../../src/config/prisma');
const config = require('../../src/config');
const { generateTransactionCode } = require('../../src/utils/code');

let counter = 0;

/**
 * Creates a user directly in the database using Prisma.
 * Bypasses auth service to insulate tests from service refactorings.
 */
const createUser = async ({
  name = 'User Test',
  email,
  password = 'Password123',
  role = 'USER',
  balance = 0,
  isActive = true,
  kycStatus = 'APPROVED',
  firebaseUid,
  fcmToken,
} = {}) => {
  counter += 1;
  const uniqueEmail =
    email || `user_${Date.now()}_${counter}_${Math.random().toString(36).substring(7)}@test.com`;
  const hashedPassword = bcrypt.hashSync(password, 4);

  const user = await prisma.user.create({
    data: {
      name,
      email: uniqueEmail,
      password: hashedPassword,
      role,
      balance: BigInt(balance),
      isActive,
      kycStatus,
      firebaseUid,
      fcmToken,
    },
  });

  if (balance > 0) {
    await prisma.ledgerEntry.create({
      data: {
        userId: user.id,
        type: 'ADJUSTMENT',
        direction: 'CREDIT',
        amount: BigInt(balance),
        balanceAfter: BigInt(balance),
        idempotencyKey: `helper:create_user:${user.id}:${Date.now()}_${counter}`,
        metadata: { source: 'test_helper' },
      },
    });
  }

  return user;
};

/**
 * Generates a valid JWT token for the given user.
 */
const tokenFor = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
    },
    config.jwt.secret,
    {
      expiresIn: config.jwt.expiresIn,
    }
  );
};

/**
 * Creates an escrow transaction directly in the database using Prisma.
 * Bypasses transaction service to insulate tests from service refactorings.
 */
const createTransaction = async ({
  buyerId,
  sellerId,
  amount = 100000,
  buyerFee = 0,
  sellerFee = 0,
  feePayer = 'SPLIT',
  heldAmount = null,
  itemDescription = 'Item Test Escrow',
  status = 'PENDING',
  code,
} = {}) => {
  let resolvedBuyerId = buyerId;
  let resolvedSellerId = sellerId;

  if (!resolvedBuyerId) {
    const buyer = await createUser({ name: 'Buyer Helper', balance: 500000 });
    resolvedBuyerId = buyer.id;
  }

  if (!resolvedSellerId) {
    const seller = await createUser({ name: 'Seller Helper', balance: 100000 });
    resolvedSellerId = seller.id;
  }

  const resolvedCode = code || generateTransactionCode();
  const biAmount = BigInt(amount);
  const biBuyerFee = BigInt(buyerFee);
  const biSellerFee = BigInt(sellerFee);

  let resolvedHeldAmount = heldAmount !== null ? BigInt(heldAmount) : 0n;
  if (heldAmount === null && ['PAID', 'SHIPPED', 'DISPUTED'].includes(status)) {
    resolvedHeldAmount = biAmount + biBuyerFee;
  }

  return await prisma.transaction.create({
    data: {
      buyerId: resolvedBuyerId,
      sellerId: resolvedSellerId,
      amount: biAmount,
      buyerFee: biBuyerFee,
      sellerFee: biSellerFee,
      feePayer,
      heldAmount: resolvedHeldAmount,
      itemDescription,
      status,
      code: resolvedCode,
    },
    include: {
      buyer: { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
    },
  });
};

/**
 * Creates a dispute directly in the database using Prisma.
 * Bypasses service to insulate tests from refactorings.
 */
const createDispute = async ({
  transactionId,
  openedById,
  reason = 'NOT_RECEIVED',
  description = 'Barang belum saya terima sampai batas waktu pengiriman.',
  status = 'OPEN',
  resolutionNote = null,
  resolvedById = null,
  resolvedAt = null,
} = {}) => {
  return await prisma.dispute.create({
    data: {
      transactionId,
      openedById,
      reason,
      description,
      status,
      resolutionNote,
      resolvedById,
      resolvedAt,
    },
    include: {
      transaction: true,
      openedBy: { select: { id: true, name: true, email: true } },
      resolvedBy: { select: { id: true, name: true, email: true } },
      evidences: true,
    },
  });
};

/**
 * Creates a dispute evidence entry directly in the database using Prisma.
 */
const createDisputeEvidence = async ({
  disputeId,
  submittedById,
  note = 'Bukti foto resi dan chat',
  fileIds = [],
} = {}) => {
  return await prisma.disputeEvidence.create({
    data: {
      disputeId,
      submittedById,
      note,
      fileIds,
    },
    include: {
      submittedBy: { select: { id: true, name: true, email: true } },
    },
  });
};

/**
 * Resets database tables atomically using TRUNCATE CASCADE.
 */
const resetDb = async () => {
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE "audit_logs", "kyc_submissions", "chat_read_states", "chat_messages", "notifications", "dispute_evidences", "disputes", "shipment_proofs", "file_assets", "platform_settings", "withdrawal_requests", "bank_accounts", "webhook_events", "payment_intents", "ledger_entries", "refresh_tokens", "password_reset_tokens", "transactions", "users" RESTART IDENTITY CASCADE;'
  );
};

/**
 * Closes the Prisma connection.
 */
const disconnectDb = async () => {
  await prisma.$disconnect();
};

module.exports = {
  createUser,
  tokenFor,
  createTransaction,
  createDispute,
  createDisputeEvidence,
  resetDb,
  disconnectDb,
  prisma,
};
