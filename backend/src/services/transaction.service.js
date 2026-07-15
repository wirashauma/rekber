// =============================================================================
// Transaction (Escrow) Service
// =============================================================================
// Contains all business logic for escrow transactions.
// Implements the escrow state machine with strict transition rules.
//
// STATE MACHINE:
// ┌─────────┐     ┌──────┐     ┌─────────┐     ┌───────────┐
// │ PENDING │────▶│ PAID │────▶│ SHIPPED │────▶│ COMPLETED │
// └─────────┘     └──────┘     └─────────┘     └───────────┘
//      │              │             │
//      ▼              ▼             ▼
// ┌───────────┐  ┌──────────┐  ┌──────────┐
// │ CANCELLED │  │ DISPUTED │  │ DISPUTED │
// └───────────┘  └──────────┘  └──────────┘
//
// WHO CAN CHANGE STATUS:
// - PENDING  → PAID:      Buyer  (buyer deposits funds)
// - PENDING  → CANCELLED: Buyer  (buyer cancels before paying)
// - PAID     → SHIPPED:   Seller (seller ships the item)
// - PAID     → DISPUTED:  Buyer  (buyer raises a dispute after paying)
// - SHIPPED  → COMPLETED: Buyer  (buyer confirms receipt)
// - SHIPPED  → DISPUTED:  Buyer  (buyer raises dispute after shipping)

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');

// =============================================================================
// Valid state transitions map
// Key: current status → Value: array of allowed next statuses
// =============================================================================
const VALID_TRANSITIONS = {
  PENDING:  ['PAID', 'CANCELLED'],
  PAID:     ['SHIPPED', 'DISPUTED'],
  SHIPPED:  ['COMPLETED', 'DISPUTED'],
  // Terminal states — no further transitions allowed
  COMPLETED: [],
  CANCELLED: [],
  DISPUTED:  [],
};

// =============================================================================
// Who is allowed to trigger each transition
// Key: "FROM→TO" → Value: 'buyer' or 'seller'
// =============================================================================
const TRANSITION_AUTHORITY = {
  'PENDING→PAID':       'buyer',   // Buyer deposits money into escrow
  'PENDING→CANCELLED':  'buyer',   // Buyer cancels the order
  'PAID→SHIPPED':       'seller',  // Seller marks as shipped
  'PAID→DISPUTED':      'buyer',   // Buyer disputes after payment
  'SHIPPED→COMPLETED':  'buyer',   // Buyer confirms receipt, funds released
  'SHIPPED→DISPUTED':   'buyer',   // Buyer disputes after shipping
};

/**
 * Create a new escrow transaction.
 *
 * The buyer creates the transaction specifying the seller, amount,
 * and item description. Status starts as PENDING.
 *
 * @param {Object} data - { buyerId, sellerId, amount, itemDescription }
 * @returns {Object} The created transaction with buyer/seller details
 */
const createTransaction = async ({ buyerId, sellerId, amount, itemDescription }) => {
  // Prevent self-transactions
  if (buyerId === sellerId) {
    throw new ApiError(400, 'Pembeli dan penjual tidak boleh orang yang sama.'); // Buyer and seller cannot be the same.
  }

  // Verify seller exists
  const seller = await prisma.user.findUnique({ where: { id: sellerId } });
  if (!seller) {
    throw new ApiError(404, 'Penjual tidak ditemukan.'); // Seller not found.
  }

  // Validate amount
  if (amount <= 0) {
    throw new ApiError(400, 'Jumlah transaksi harus lebih dari 0.'); // Amount must be > 0.
  }

  // Create the transaction in the database
  const transaction = await prisma.transaction.create({
    data: {
      buyerId,
      sellerId,
      amount,
      itemDescription,
      status: 'PENDING',
    },
    include: {
      buyer:  { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
    },
  });

  return transaction;
};

/**
 * Get a transaction by ID.
 *
 * Only the buyer, seller, or admin can view a transaction.
 *
 * @param {string} transactionId - UUID of the transaction
 * @param {string} userId - ID of the requesting user
 * @param {string} userRole - Role of the requesting user
 * @returns {Object} Transaction with buyer/seller details
 */
const getTransactionById = async (transactionId, userId, userRole) => {
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
    include: {
      buyer:  { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
    },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.'); // Transaction not found.
  }

  // Authorization: Only buyer, seller, or admin can view
  const isParticipant = transaction.buyerId === userId || transaction.sellerId === userId;
  const isAdmin = userRole === 'ADMIN';

  if (!isParticipant && !isAdmin) {
    throw new ApiError(403, 'Anda tidak memiliki akses ke transaksi ini.'); // No access.
  }

  return transaction;
};

/**
 * Update the status of a transaction (escrow state machine).
 *
 * This is the CORE of the escrow logic. It enforces:
 *   1. The transition is valid (based on VALID_TRANSITIONS map).
 *   2. The user has authority to make this transition (TRANSITION_AUTHORITY map).
 *   3. Balance operations are performed atomically (within a Prisma transaction).
 *
 * Balance Logic:
 *   - PENDING → PAID:      Deduct `amount` from buyer's balance (escrow deposit).
 *   - SHIPPED → COMPLETED: Add `amount` to seller's balance (escrow release).
 *   - PAID → CANCELLED:    Refund `amount` to buyer's balance (not currently in transitions,
 *                           but could be added for admin-initiated cancellations).
 *
 * @param {string} transactionId - UUID of the transaction
 * @param {string} newStatus - The desired new status
 * @param {string} userId - ID of the requesting user
 * @param {string} userRole - Role of the requesting user
 * @returns {Object} Updated transaction
 */
const updateTransactionStatus = async (transactionId, newStatus, userId, userRole) => {
  // 1. Fetch the current transaction
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.'); // Transaction not found.
  }

  const currentStatus = transaction.status;

  // 2. Validate the transition is allowed
  const allowedStatuses = VALID_TRANSITIONS[currentStatus];

  if (!allowedStatuses || !allowedStatuses.includes(newStatus)) {
    throw new ApiError(
      400,
      `Transisi status tidak valid: ${currentStatus} → ${newStatus}. ` +
      `Status yang diperbolehkan: ${allowedStatuses?.join(', ') || 'tidak ada'}.`
      // Invalid transition. Allowed statuses: ...
    );
  }

  // 3. Check authorization (who can trigger this transition)
  const transitionKey = `${currentStatus}→${newStatus}`;
  const requiredRole = TRANSITION_AUTHORITY[transitionKey];

  if (userRole !== 'ADMIN') {
    // Non-admin users must match the required role for this transition
    if (requiredRole === 'buyer' && transaction.buyerId !== userId) {
      throw new ApiError(403, 'Hanya pembeli yang dapat melakukan aksi ini.'); // Only buyer can do this.
    }
    if (requiredRole === 'seller' && transaction.sellerId !== userId) {
      throw new ApiError(403, 'Hanya penjual yang dapat melakukan aksi ini.'); // Only seller can do this.
    }
  }

  // 4. Execute the status update with balance operations in a DB transaction
  //    This ensures atomicity — either everything succeeds or nothing changes.
  const updatedTransaction = await prisma.$transaction(async (tx) => {
    // --- BALANCE LOGIC ---

    // When buyer PAYS: deduct from buyer's balance (escrow deposit)
    if (currentStatus === 'PENDING' && newStatus === 'PAID') {
      const buyer = await tx.user.findUnique({ where: { id: transaction.buyerId } });

      if (buyer.balance < transaction.amount) {
        throw new ApiError(
          400,
          `Saldo tidak mencukupi. Saldo Anda: Rp ${buyer.balance.toLocaleString('id-ID')}, ` +
          `Jumlah transaksi: Rp ${transaction.amount.toLocaleString('id-ID')}.`
          // Insufficient balance.
        );
      }

      // Deduct from buyer's balance
      await tx.user.update({
        where: { id: transaction.buyerId },
        data: { balance: { decrement: transaction.amount } },
      });
    }

    // When buyer COMPLETES: release funds to seller
    if (currentStatus === 'SHIPPED' && newStatus === 'COMPLETED') {
      await tx.user.update({
        where: { id: transaction.sellerId },
        data: { balance: { increment: transaction.amount } },
      });
    }

    // When CANCELLED after PAID: refund to buyer (admin-only scenario)
    if (currentStatus === 'PAID' && newStatus === 'CANCELLED') {
      await tx.user.update({
        where: { id: transaction.buyerId },
        data: { balance: { increment: transaction.amount } },
      });
    }

    // Update the transaction status
    const updated = await tx.transaction.update({
      where: { id: transactionId },
      data: { status: newStatus },
      include: {
        buyer:  { select: { id: true, name: true, email: true } },
        seller: { select: { id: true, name: true, email: true } },
      },
    });

    return updated;
  });

  return updatedTransaction;
};

/**
 * Get all transactions associated with a user (buyer or seller).
 * @param {string} userId
 * @returns {Promise<Array>} List of transactions
 */
const getTransactions = async (userId) => {
  return await prisma.transaction.findMany({
    where: {
      OR: [
        { buyerId: userId },
        { sellerId: userId },
      ],
    },
    include: {
      buyer:  { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
    },
    orderBy: {
      createdAt: 'desc',
    },
  });
};

module.exports = {
  createTransaction,
  getTransactionById,
  updateTransactionStatus,
  getTransactions,
  VALID_TRANSITIONS,
  TRANSITION_AUTHORITY,
};
