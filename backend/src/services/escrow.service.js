// =============================================================================
// Escrow Service - Atomic State Machine, Transitions & Escrow Logic
// =============================================================================

const prisma = require('../config/prisma');
const settingsService = require('./settings.service');
const ledgerService = require('./ledger.service');
const { ApiError } = require('../middlewares/error.middleware');
const { generateTransactionCode } = require('../utils/code');
const { parseInteger, calculateFee } = require('../utils/money');
const { VALID_TRANSITIONS, TRANSITION_ROLES } = require('../constants/transaction');

/**
 * Helper to ensure a transaction client is present.
 */
const withTx = async (tx, fn) => {
  if (tx) return fn(tx);
  return prisma.$transaction(async (innerTx) => fn(innerTx));
};

/**
 * Create a new escrow transaction.
 *
 * @param {Object} params
 * @param {string} params.buyerId
 * @param {string} params.sellerId
 * @param {number|string|bigint} params.amount
 * @param {string} params.itemDescription
 * @param {string} [params.feePayer] - 'BUYER', 'SELLER', 'SPLIT' (defaults to PlatformSetting)
 * @returns {Promise<Object>} Created transaction
 */
const createTransaction = async ({
  buyerId,
  sellerId,
  amount,
  itemDescription,
  feePayer = null,
}) => {
  // 1. Prevent self-transactions
  if (buyerId === sellerId) {
    throw new ApiError(400, 'Pembeli dan penjual tidak boleh orang yang sama.');
  }

  // 2. Verify seller and buyer exist
  const [seller, buyer] = await Promise.all([
    prisma.user.findUnique({ where: { id: sellerId } }),
    prisma.user.findUnique({ where: { id: buyerId } }),
  ]);

  if (!seller) {
    throw new ApiError(404, 'Penjual tidak ditemukan.');
  }
  if (!buyer) {
    throw new ApiError(404, 'Pembeli tidak ditemukan.');
  }

  // 3. Amount parsing and platform boundaries
  const parsedAmount = parseInteger(amount, { min: 1000 });
  const maxTxAmount = await settingsService.getNumber('max_transaction_amount');
  if (parsedAmount > BigInt(maxTxAmount)) {
    throw new ApiError(
      400,
      `Jumlah transaksi melebihi batas maksimal platform (Rp ${maxTxAmount.toLocaleString('id-ID')}).`
    );
  }

  // 4. Calculate fee from platform settings
  const feePercent = await settingsService.getNumber('fee_percent');
  const feeMin = await settingsService.getNumber('fee_min');
  const defaultFeePayer = await settingsService.getString('fee_payer_default');
  const chosenFeePayer = (feePayer || defaultFeePayer || 'SPLIT').toUpperCase();

  const { buyerFee, sellerFee } = calculateFee({
    amount: parsedAmount,
    feePercent,
    feeMin,
    feePayer: chosenFeePayer,
  });

  // 5. Expiration date (pending_expire_hours)
  const pendingExpireHours = await settingsService.getNumber('pending_expire_hours');
  const expiresAt = new Date(Date.now() + pendingExpireHours * 60 * 60 * 1000);

  // 6. Generate unique 8-character code
  let code = generateTransactionCode();
  let attempts = 0;
  while (attempts < 5) {
    const exists = await prisma.transaction.findUnique({ where: { code } });
    if (!exists) break;
    code = generateTransactionCode();
    attempts += 1;
  }

  // 7. Persist transaction
  const transaction = await prisma.transaction.create({
    data: {
      buyerId,
      sellerId,
      amount: parsedAmount,
      buyerFee,
      sellerFee,
      feePayer: chosenFeePayer,
      heldAmount: 0n,
      itemDescription,
      status: 'PENDING',
      code,
      expiresAt,
    },
    include: {
      buyer: { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
    },
  });

  return transaction;
};

/**
 * Hold escrow funds when transaction moves from PENDING to PAID.
 * Debits buyer (amount + buyerFee) and sets heldAmount.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {string} transactionId
 * @param {string} userId - Initiator (must be buyer or admin)
 * @returns {Promise<Object>} Updated transaction
 */
const holdEscrow = async (tx, transactionId, _userId) => {
  return withTx(tx, async (client) => {
    const transaction = await client.transaction.findUnique({
      where: { id: transactionId },
    });
    if (!transaction) {
      throw new ApiError(404, 'Transaksi tidak ditemukan.');
    }

    if (transaction.status !== 'PENDING') {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    const totalDebit = transaction.amount + transaction.buyerFee;

    // 1. Compare-and-swap status PENDING → PAID first to secure transaction lock
    const updateResult = await client.transaction.updateMany({
      where: { id: transactionId, status: 'PENDING' },
      data: {
        status: 'PAID',
        heldAmount: totalDebit,
        paidAt: new Date(),
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    // 2. Debit buyer (only executed by the winning atomic transition)
    await ledgerService.debit(client, {
      userId: transaction.buyerId,
      amount: totalDebit,
      type: 'ESCROW_HOLD',
      idempotencyKey: `escrow:${transactionId}:hold`,
      transactionId,
      referenceType: 'TRANSACTION',
      referenceId: transactionId,
      metadata: { status: 'PAID', buyerFee: transaction.buyerFee.toString() },
    });

    return await client.transaction.findUnique({
      where: { id: transactionId },
      include: {
        buyer: { select: { id: true, name: true, email: true } },
        seller: { select: { id: true, name: true, email: true } },
      },
    });
  });
};

/**
 * Mark transaction as shipped when seller moves status from PAID to SHIPPED.
 * Sets shippedAt and schedules autoReleaseAt.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {string} transactionId
 * @param {string} userId - Initiator (must be seller or admin)
 * @returns {Promise<Object>} Updated transaction
 */
const markShipped = async (tx, transactionId, _userId) => {
  return withTx(tx, async (client) => {
    const transaction = await client.transaction.findUnique({
      where: { id: transactionId },
    });
    if (!transaction) {
      throw new ApiError(404, 'Transaksi tidak ditemukan.');
    }

    if (transaction.status !== 'PAID') {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    const autoReleaseHours = await settingsService.getNumber('auto_release_hours');
    const autoReleaseAt = new Date(Date.now() + autoReleaseHours * 60 * 60 * 1000);

    // Compare-and-swap status PAID → SHIPPED
    const updateResult = await client.transaction.updateMany({
      where: { id: transactionId, status: 'PAID' },
      data: {
        status: 'SHIPPED',
        shippedAt: new Date(),
        autoReleaseAt,
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    return await client.transaction.findUnique({
      where: { id: transactionId },
      include: {
        buyer: { select: { id: true, name: true, email: true } },
        seller: { select: { id: true, name: true, email: true } },
      },
    });
  });
};

/**
 * Release escrow funds when transaction moves from SHIPPED to COMPLETED.
 * Credits seller (amount - sellerFee), credits platform fee, sets heldAmount to 0.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {string} transactionId
 * @param {string} userId - Initiator (buyer, system, or admin)
 * @returns {Promise<Object>} Updated transaction
 */
const releaseEscrow = async (tx, transactionId, _userId) => {
  return withTx(tx, async (client) => {
    const transaction = await client.transaction.findUnique({
      where: { id: transactionId },
    });
    if (!transaction) {
      throw new ApiError(404, 'Transaksi tidak ditemukan.');
    }

    if (transaction.status !== 'SHIPPED' && transaction.status !== 'DISPUTED') {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    // 1. Compare-and-swap status SHIPPED/DISPUTED → COMPLETED first to secure transaction lock
    const updateResult = await client.transaction.updateMany({
      where: { id: transactionId, status: { in: ['SHIPPED', 'DISPUTED'] } },
      data: {
        status: 'COMPLETED',
        heldAmount: 0n,
        completedAt: new Date(),
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    // 2. Credit seller (amount - sellerFee)
    const sellerAmount = transaction.amount - transaction.sellerFee;
    if (sellerAmount > 0n) {
      await ledgerService.credit(client, {
        userId: transaction.sellerId,
        amount: sellerAmount,
        type: 'ESCROW_RELEASE',
        idempotencyKey: `escrow:${transactionId}:release:seller`,
        transactionId,
        referenceType: 'TRANSACTION',
        referenceId: transactionId,
        metadata: { sellerFee: transaction.sellerFee.toString() },
      });
    }

    // 3. Credit platform fee
    const totalPlatformFee = transaction.buyerFee + transaction.sellerFee;
    if (totalPlatformFee > 0n) {
      await ledgerService.credit(client, {
        userId: null,
        amount: totalPlatformFee,
        type: 'PLATFORM_FEE',
        idempotencyKey: `escrow:${transactionId}:release:fee`,
        transactionId,
        referenceType: 'TRANSACTION',
        referenceId: transactionId,
        metadata: {
          buyerFee: transaction.buyerFee.toString(),
          sellerFee: transaction.sellerFee.toString(),
        },
      });
    }

    return await client.transaction.findUnique({
      where: { id: transactionId },
      include: {
        buyer: { select: { id: true, name: true, email: true } },
        seller: { select: { id: true, name: true, email: true } },
      },
    });
  });
};

/**
 * Refund escrow funds to buyer.
 * Transitions PAID (or DISPUTED) → REFUNDED.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {string} transactionId
 * @param {string} userId - Initiator (seller, admin)
 * @param {string} [reason] - Reason for refund
 * @returns {Promise<Object>} Updated transaction
 */
const refundEscrow = async (tx, transactionId, userId, reason = null) => {
  return withTx(tx, async (client) => {
    const transaction = await client.transaction.findUnique({
      where: { id: transactionId },
    });
    if (!transaction) {
      throw new ApiError(404, 'Transaksi tidak ditemukan.');
    }

    if (transaction.status !== 'PAID' && transaction.status !== 'DISPUTED') {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    // 1. Compare-and-swap first to secure transaction lock
    const updateResult = await client.transaction.updateMany({
      where: { id: transactionId, status: transaction.status },
      data: {
        status: 'REFUNDED',
        heldAmount: 0n,
        cancelledAt: new Date(),
        cancelReason: reason || 'REFUNDED',
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    // 2. Refund full held amount (amount + buyerFee) to buyer (only if CAS won)
    const refundAmount = transaction.amount + transaction.buyerFee;
    if (refundAmount > 0n) {
      await ledgerService.credit(client, {
        userId: transaction.buyerId,
        amount: refundAmount,
        type: 'ESCROW_REFUND',
        idempotencyKey: `escrow:${transactionId}:refund`,
        transactionId,
        referenceType: 'TRANSACTION',
        referenceId: transactionId,
        metadata: { reason: reason || 'REFUNDED' },
      });
    }

    return await client.transaction.findUnique({
      where: { id: transactionId },
      include: {
        buyer: { select: { id: true, name: true, email: true } },
        seller: { select: { id: true, name: true, email: true } },
      },
    });
  });
};

/**
 * Cancel a PENDING transaction.
 * No funds were held, so no ledger mutation occurs.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {string} transactionId
 * @param {string} userId - Initiator (buyer, seller, system, admin)
 * @param {string} [reason] - Reason for cancellation
 * @returns {Promise<Object>} Updated transaction
 */
const cancelPending = async (tx, transactionId, userId, reason = null) => {
  return withTx(tx, async (client) => {
    const transaction = await client.transaction.findUnique({
      where: { id: transactionId },
    });
    if (!transaction) {
      throw new ApiError(404, 'Transaksi tidak ditemukan.');
    }

    if (transaction.status !== 'PENDING') {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    // Compare-and-swap status PENDING → CANCELLED
    const updateResult = await client.transaction.updateMany({
      where: { id: transactionId, status: 'PENDING' },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
        cancelReason: reason || 'CANCELLED',
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status transaksi sudah berubah.');
    }

    return await client.transaction.findUnique({
      where: { id: transactionId },
      include: {
        buyer: { select: { id: true, name: true, email: true } },
        seller: { select: { id: true, name: true, email: true } },
      },
    });
  });
};

/**
 * Orchestrates a state transition based on the escrow state machine.
 *
 * @param {string} transactionId
 * @param {string} targetStatus
 * @param {Object} user - { id, role }
 * @param {string} [reason] - Optional reason (for cancel/refund)
 * @returns {Promise<Object>} Updated transaction
 */
const executeTransition = async (transactionId, targetStatus, user, reason = null) => {
  const userId = user.id;
  const userRole = user.role;

  // 1. Fetch current transaction
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
  });
  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  const currentStatus = transaction.status;

  // If transaction status has already reached the target status (concurrent race condition)
  if (currentStatus === targetStatus) {
    throw new ApiError(409, 'Status transaksi sudah berubah.');
  }

  // 2. Reject transitions from/to DISPUTED in the general endpoint
  if (currentStatus === 'DISPUTED' || targetStatus === 'DISPUTED') {
    throw new ApiError(
      400,
      'Transisi status sengketa (DISPUTED) harus diproses melalui endpoint sengketa.'
    );
  }

  // 2b. Reject transitions to SHIPPED in the general status endpoint
  if (targetStatus === 'SHIPPED') {
    throw new ApiError(
      400,
      'Perubahan status ke SHIPPED harus melalui endpoint pengiriman (POST /transactions/:id/shipment).'
    );
  }

  // 3. Validate transition existence
  const allowedNext = VALID_TRANSITIONS[currentStatus];
  if (!allowedNext || !allowedNext.includes(targetStatus)) {
    throw new ApiError(
      400,
      `Transisi status tidak valid: ${currentStatus} → ${targetStatus}. ` +
        `Status yang diperbolehkan: ${allowedNext?.join(', ') || 'tidak ada'}.`
    );
  }

  // 4. Validate transition authority
  const transitionKey = `${currentStatus}→${targetStatus}`;
  const allowedActors = TRANSITION_ROLES[transitionKey] || [];

  const isBuyer = transaction.buyerId === userId;
  const isSeller = transaction.sellerId === userId;
  const isAdmin = userRole === 'ADMIN';

  let hasAuthority = false;
  if (isAdmin && allowedActors.includes('ADMIN')) {
    hasAuthority = true;
  }
  if (isBuyer && allowedActors.includes('BUYER')) {
    hasAuthority = true;
  }
  if (isSeller && allowedActors.includes('SELLER')) {
    hasAuthority = true;
  }

  if (!hasAuthority) {
    if (!isBuyer && !isSeller && !isAdmin) {
      throw new ApiError(403, 'Anda tidak memiliki akses ke transaksi ini.');
    }
    if (allowedActors.includes('BUYER') && !isBuyer) {
      throw new ApiError(403, 'Hanya pembeli yang dapat melakukan aksi ini.');
    }
    if (allowedActors.includes('SELLER') && !isSeller) {
      throw new ApiError(403, 'Hanya penjual yang dapat melakukan aksi ini.');
    }
    throw new ApiError(403, 'Anda tidak memiliki wewenang untuk melakukan transisi status ini.');
  }

  // 5. Execute atomic transition
  return await prisma.$transaction(async (tx) => {
    switch (targetStatus) {
      case 'PAID':
        return await holdEscrow(tx, transactionId, userId);
      case 'SHIPPED':
        return await markShipped(tx, transactionId, userId);
      case 'COMPLETED':
        return await releaseEscrow(tx, transactionId, userId);
      case 'REFUNDED':
        return await refundEscrow(tx, transactionId, userId, reason);
      case 'CANCELLED':
        return await cancelPending(tx, transactionId, userId, reason);
      default:
        throw new ApiError(400, `Transisi status ${targetStatus} belum didukung.`);
    }
  });
};

/**
 * Submits shipment proof and marks transaction as SHIPPED atomically.
 *
 * @param {string} transactionId
 * @param {string} userId - Initiator (must be seller)
 * @param {Object} proofData - { courier, trackingNumber, note, fileIds }
 * @returns {Promise<Object>} Updated transaction with shipment proof summary
 */
const submitShipmentProof = async (
  transactionId,
  userId,
  { courier, trackingNumber, note, fileIds = [] } = {}
) => {
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  // 1. Only seller can submit shipment proof
  if (transaction.sellerId !== userId) {
    throw new ApiError(403, 'Hanya penjual yang dapat mengirimkan bukti pengiriman.');
  }

  // 2. Status must be PAID
  if (transaction.status !== 'PAID') {
    throw new ApiError(400, 'Bukti pengiriman hanya dapat diserahkan saat status transaksi PAID.');
  }

  // 3. Validate proof existence: fileIds OR (courier + trackingNumber) OR note
  const hasFiles = Array.isArray(fileIds) && fileIds.length > 0;
  const hasCourierAndTracking =
    typeof courier === 'string' &&
    courier.trim() !== '' &&
    typeof trackingNumber === 'string' &&
    trackingNumber.trim() !== '';
  const hasNote = typeof note === 'string' && note.trim() !== '';

  if (!hasFiles && !hasCourierAndTracking && !hasNote) {
    throw new ApiError(
      400,
      'Wajib menyertakan minimal satu bukti pengiriman: berkas bukti (fileIds), kurir & nomor resi, atau catatan pengiriman.'
    );
  }

  // 4. Validate files if provided: must belong to seller, purpose SHIPMENT_PROOF, active
  if (hasFiles) {
    const files = await prisma.fileAsset.findMany({
      where: {
        id: { in: fileIds },
        ownerId: userId,
        purpose: 'SHIPMENT_PROOF',
        deletedAt: null,
      },
    });

    if (files.length !== fileIds.length) {
      throw new ApiError(
        400,
        'Satu atau lebih berkas bukti pengiriman tidak valid atau bukan milik Anda.'
      );
    }
  }

  // 5. Execute atomically in a single Prisma transaction
  return await prisma.$transaction(async (tx) => {
    // a. Create ShipmentProof
    await tx.shipmentProof.create({
      data: {
        transactionId,
        submittedById: userId,
        courier: courier ? courier.trim() : null,
        trackingNumber: trackingNumber ? trackingNumber.trim() : null,
        note: note ? note.trim() : null,
        fileIds: hasFiles ? fileIds : [],
      },
    });

    // b. Mark transaction as SHIPPED
    await markShipped(tx, transactionId, userId);

    // c. Return transaction with shipmentProof summary
    return await tx.transaction.findUnique({
      where: { id: transactionId },
      include: {
        buyer: { select: { id: true, name: true, email: true } },
        seller: { select: { id: true, name: true, email: true } },
        shipmentProof: {
          select: {
            id: true,
            courier: true,
            trackingNumber: true,
            note: true,
            fileIds: true,
            createdAt: true,
          },
        },
      },
    });
  });
};

/**
 * Get a transaction by ID with authorization check.
 */
const getTransactionById = async (transactionId, userId, userRole) => {
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
    include: {
      buyer: { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
      shipmentProof: {
        select: {
          id: true,
          courier: true,
          trackingNumber: true,
          note: true,
          fileIds: true,
          createdAt: true,
        },
      },
      dispute: {
        select: {
          id: true,
          reason: true,
          status: true,
          resolutionNote: true,
          createdAt: true,
          resolvedAt: true,
        },
      },
    },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  const isParticipant = transaction.buyerId === userId || transaction.sellerId === userId;
  const isAdmin = userRole === 'ADMIN';

  if (!isParticipant && !isAdmin) {
    throw new ApiError(403, 'Anda tidak memiliki akses ke transaksi ini.');
  }

  return transaction;
};

/**
 * Get a transaction by unique 8-character code.
 * Non-participants or non-admin users receive 404 to avoid leaking existence.
 */
const getTransactionByCode = async (code, userId, userRole) => {
  const transaction = await prisma.transaction.findUnique({
    where: { code: code.toUpperCase() },
    include: {
      buyer: { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
      shipmentProof: {
        select: {
          id: true,
          courier: true,
          trackingNumber: true,
          note: true,
          fileIds: true,
          createdAt: true,
        },
      },
      dispute: {
        select: {
          id: true,
          reason: true,
          status: true,
          resolutionNote: true,
          createdAt: true,
          resolvedAt: true,
        },
      },
    },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  const isParticipant = transaction.buyerId === userId || transaction.sellerId === userId;
  const isAdmin = userRole === 'ADMIN';

  if (!isParticipant && !isAdmin) {
    // Return 404 instead of 403 to prevent probing codes
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  return transaction;
};

/**
 * Get all transactions for a user.
 */
const getTransactions = async (userId) => {
  return await prisma.transaction.findMany({
    where: {
      OR: [{ buyerId: userId }, { sellerId: userId }],
    },
    include: {
      buyer: { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
      shipmentProof: {
        select: {
          id: true,
          courier: true,
          trackingNumber: true,
          note: true,
          fileIds: true,
          createdAt: true,
        },
      },
      dispute: {
        select: {
          id: true,
          reason: true,
          status: true,
          resolutionNote: true,
          createdAt: true,
          resolvedAt: true,
        },
      },
    },
    orderBy: {
      createdAt: 'desc',
    },
  });
};

module.exports = {
  createTransaction,
  holdEscrow,
  markShipped,
  submitShipmentProof,
  releaseEscrow,
  refundEscrow,
  cancelPending,
  executeTransition,
  getTransactionById,
  getTransactionByCode,
  getTransactions,
};
