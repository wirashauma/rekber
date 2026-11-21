// =============================================================================
// Dispute Service - Dispute Lifecycle, Evidence Management & Admin Resolution
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { releaseEscrow, refundEscrow } = require('./escrow.service');
const {
  DISPUTE_REASON,
  DISPUTE_STATUS,
  DISPUTE_DECISION,
  MAX_EVIDENCE_PER_PARTY,
} = require('../constants/dispute');

/**
 * Standard select fields for user references
 */
const USER_SELECT = {
  id: true,
  name: true,
  email: true,
};

/**
 * Open a dispute for a transaction.
 * Only the buyer can open a dispute, and only when status is PAID or SHIPPED.
 * Atomically transitions transaction to DISPUTED, clears autoReleaseAt, and creates Dispute.
 *
 * @param {string} transactionId
 * @param {string} userId - Initiator (must be buyer)
 * @param {Object} params
 * @param {string} params.reason - Enum DisputeReason
 * @param {string} params.description - 20-2000 chars
 * @param {string[]} [params.fileIds] - Optional file asset IDs
 * @returns {Promise<Object>} Created dispute
 */
const openDispute = async (transactionId, userId, { reason, description, fileIds = [] }) => {
  // 1. Validate transaction existence
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  // 2. Only buyer can open dispute
  if (transaction.buyerId !== userId) {
    throw new ApiError(403, 'Hanya pembeli yang dapat mengajukan sengketa.');
  }

  // Check if dispute already exists for this transaction (409 Conflict)
  const existingDispute = await prisma.dispute.findUnique({
    where: { transactionId },
  });

  if (existingDispute || transaction.status === 'DISPUTED') {
    throw new ApiError(409, 'Sengketa untuk transaksi ini sudah ada.');
  }

  // 3. Status must be PAID or SHIPPED
  if (!['PAID', 'SHIPPED'].includes(transaction.status)) {
    throw new ApiError(
      400,
      'Sengketa hanya dapat diajukan untuk transaksi berstatus PAID atau SHIPPED.'
    );
  }

  // 4. Validate reason
  if (!Object.values(DISPUTE_REASON).includes(reason)) {
    throw new ApiError(
      400,
      `Alasan sengketa tidak valid. Pilihan: ${Object.values(DISPUTE_REASON).join(', ')}.`
    );
  }

  // 5. Validate description
  if (
    typeof description !== 'string' ||
    description.trim().length < 20 ||
    description.trim().length > 2000
  ) {
    throw new ApiError(400, 'Deskripsi sengketa harus berupa teks antara 20 hingga 2000 karakter.');
  }

  // 6. Validate files if provided
  const hasFiles = Array.isArray(fileIds) && fileIds.length > 0;
  if (hasFiles) {
    const files = await prisma.fileAsset.findMany({
      where: {
        id: { in: fileIds },
        ownerId: userId,
        purpose: 'DISPUTE_EVIDENCE',
        deletedAt: null,
      },
    });

    if (files.length !== fileIds.length) {
      throw new ApiError(
        400,
        'Satu atau lebih berkas bukti sengketa tidak valid atau bukan milik Anda.'
      );
    }
  }

  // 7. Execute atomically in a single DB transaction
  return await prisma.$transaction(async (tx) => {
    // Check if dispute already exists for this transaction
    const existingDispute = await tx.dispute.findUnique({
      where: { transactionId },
    });

    if (existingDispute) {
      throw new ApiError(409, 'Sengketa untuk transaksi ini sudah ada.');
    }

    // Compare-and-swap status PAID/SHIPPED → DISPUTED and clear autoReleaseAt
    const updateResult = await tx.transaction.updateMany({
      where: {
        id: transactionId,
        status: { in: ['PAID', 'SHIPPED'] },
      },
      data: {
        status: 'DISPUTED',
        autoReleaseAt: null,
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status transaksi sudah berubah atau sudah disengketakan.');
    }

    // Create Dispute record
    const dispute = await tx.dispute.create({
      data: {
        transactionId,
        openedById: userId,
        reason,
        description: description.trim(),
        status: DISPUTE_STATUS.OPEN,
      },
      include: {
        transaction: {
          include: {
            buyer: { select: USER_SELECT },
            seller: { select: USER_SELECT },
            shipmentProof: true,
          },
        },
        openedBy: { select: USER_SELECT },
        evidences: {
          include: {
            submittedBy: { select: USER_SELECT },
          },
        },
      },
    });

    // If initial files were provided, create the first evidence record
    if (hasFiles) {
      const initialEvidence = await tx.disputeEvidence.create({
        data: {
          disputeId: dispute.id,
          submittedById: userId,
          note: 'Bukti awal pembeli',
          fileIds,
        },
        include: {
          submittedBy: { select: USER_SELECT },
        },
      });

      dispute.evidences = [initialEvidence];
    }

    return dispute;
  });
};

/**
 * Submit additional evidence to an open dispute.
 * Allowed for buyer or seller; maximum 10 submissions per party.
 *
 * @param {string} disputeId
 * @param {string} userId
 * @param {Object} params
 * @param {string} [params.note]
 * @param {string[]} [params.fileIds]
 * @returns {Promise<Object>} Created DisputeEvidence
 */
const submitEvidence = async (disputeId, userId, { note, fileIds = [] }) => {
  const dispute = await prisma.dispute.findUnique({
    where: { id: disputeId },
    include: {
      transaction: {
        select: {
          id: true,
          buyerId: true,
          sellerId: true,
          status: true,
        },
      },
    },
  });

  if (!dispute) {
    throw new ApiError(404, 'Sengketa tidak ditemukan.');
  }

  // 1. Only buyer or seller in the disputed transaction can submit evidence
  const isBuyer = dispute.transaction.buyerId === userId;
  const isSeller = dispute.transaction.sellerId === userId;

  if (!isBuyer && !isSeller) {
    throw new ApiError(403, 'Hanya pembeli atau penjual yang dapat menambahkan bukti sengketa.');
  }

  // 2. Dispute must be OPEN or UNDER_REVIEW
  if (![DISPUTE_STATUS.OPEN, DISPUTE_STATUS.UNDER_REVIEW].includes(dispute.status)) {
    throw new ApiError(
      400,
      'Bukti hanya dapat diserahkan saat sengketa berstatus OPEN atau UNDER_REVIEW.'
    );
  }

  // 3. Limit 10 evidence records per party
  const existingCount = await prisma.disputeEvidence.count({
    where: {
      disputeId,
      submittedById: userId,
    },
  });

  if (existingCount >= MAX_EVIDENCE_PER_PARTY) {
    throw new ApiError(
      400,
      `Maksimal ${MAX_EVIDENCE_PER_PARTY} bukti sengketa per pihak telah tercapai.`
    );
  }

  // 4. Must provide either note or fileIds
  const hasNote = typeof note === 'string' && note.trim() !== '';
  const hasFiles = Array.isArray(fileIds) && fileIds.length > 0;

  if (!hasNote && !hasFiles) {
    throw new ApiError(400, 'Wajib menyertakan catatan bukti (note) atau berkas bukti (fileIds).');
  }

  // 5. Validate files if provided
  if (hasFiles) {
    const files = await prisma.fileAsset.findMany({
      where: {
        id: { in: fileIds },
        ownerId: userId,
        purpose: 'DISPUTE_EVIDENCE',
        deletedAt: null,
      },
    });

    if (files.length !== fileIds.length) {
      throw new ApiError(
        400,
        'Satu atau lebih berkas bukti sengketa tidak valid atau bukan milik Anda.'
      );
    }
  }

  // 6. Create evidence entry
  return await prisma.disputeEvidence.create({
    data: {
      disputeId,
      submittedById: userId,
      note: hasNote ? note.trim() : null,
      fileIds: hasFiles ? fileIds : [],
    },
    include: {
      submittedBy: { select: USER_SELECT },
    },
  });
};

/**
 * Get dispute details by dispute ID.
 * Accessible by transaction participants (buyer/seller) and platform admins.
 *
 * @param {string} disputeId
 * @param {Object} user - { id, role }
 * @returns {Promise<Object>}
 */
const getDisputeById = async (disputeId, user) => {
  const dispute = await prisma.dispute.findUnique({
    where: { id: disputeId },
    include: {
      transaction: {
        include: {
          buyer: { select: USER_SELECT },
          seller: { select: USER_SELECT },
          shipmentProof: true,
        },
      },
      openedBy: { select: USER_SELECT },
      resolvedBy: { select: USER_SELECT },
      evidences: {
        include: {
          submittedBy: { select: USER_SELECT },
        },
        orderBy: { createdAt: 'asc' },
      },
    },
  });

  if (!dispute) {
    throw new ApiError(404, 'Sengketa tidak ditemukan.');
  }

  const isBuyer = dispute.transaction.buyerId === user.id;
  const isSeller = dispute.transaction.sellerId === user.id;
  const isAdmin = user.role === 'ADMIN';

  if (!isBuyer && !isSeller && !isAdmin) {
    throw new ApiError(403, 'Anda tidak memiliki akses ke sengketa ini.');
  }

  return dispute;
};

/**
 * Get dispute details by transaction ID.
 * Accessible by transaction participants (buyer/seller) and platform admins.
 *
 * @param {string} transactionId
 * @param {Object} user - { id, role }
 * @returns {Promise<Object>}
 */
const getDisputeByTransactionId = async (transactionId, user) => {
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
    select: { id: true, buyerId: true, sellerId: true },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  const isBuyer = transaction.buyerId === user.id;
  const isSeller = transaction.sellerId === user.id;
  const isAdmin = user.role === 'ADMIN';

  if (!isBuyer && !isSeller && !isAdmin) {
    throw new ApiError(403, 'Anda tidak memiliki akses ke transaksi ini.');
  }

  const dispute = await prisma.dispute.findUnique({
    where: { transactionId },
    include: {
      transaction: {
        include: {
          buyer: { select: USER_SELECT },
          seller: { select: USER_SELECT },
          shipmentProof: true,
        },
      },
      openedBy: { select: USER_SELECT },
      resolvedBy: { select: USER_SELECT },
      evidences: {
        include: {
          submittedBy: { select: USER_SELECT },
        },
        orderBy: { createdAt: 'asc' },
      },
    },
  });

  if (!dispute) {
    throw new ApiError(404, 'Sengketa tidak ditemukan untuk transaksi ini.');
  }

  return dispute;
};

/**
 * Admin: list disputes with optional status filter and pagination.
 *
 * @param {Object} params
 * @param {string} [params.status]
 * @param {number} [params.page=1]
 * @param {number} [params.limit=20]
 * @returns {Promise<Object>}
 */
const getAdminDisputes = async ({ status, page = 1, limit = 20 }) => {
  const parsedPage = Math.max(1, parseInt(page, 10) || 1);
  const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const skip = (parsedPage - 1) * parsedLimit;

  const where = {};
  if (status) {
    const normalizedStatus = status.toUpperCase();
    if (!Object.values(DISPUTE_STATUS).includes(normalizedStatus)) {
      throw new ApiError(
        400,
        `Status filter tidak valid. Pilihan: ${Object.values(DISPUTE_STATUS).join(', ')}.`
      );
    }
    where.status = normalizedStatus;
  }

  const [total, disputes] = await Promise.all([
    prisma.dispute.count({ where }),
    prisma.dispute.findMany({
      where,
      skip,
      take: parsedLimit,
      orderBy: { createdAt: 'desc' },
      include: {
        transaction: {
          select: {
            id: true,
            code: true,
            amount: true,
            status: true,
            buyerId: true,
            sellerId: true,
            buyer: { select: USER_SELECT },
            seller: { select: USER_SELECT },
          },
        },
        openedBy: { select: USER_SELECT },
        resolvedBy: { select: USER_SELECT },
        _count: {
          select: { evidences: true },
        },
      },
    }),
  ]);

  return {
    disputes,
    pagination: {
      total,
      page: parsedPage,
      limit: parsedLimit,
      totalPages: Math.ceil(total / parsedLimit),
    },
  };
};

/**
 * Admin: get full dispute details for review.
 *
 * @param {string} disputeId
 * @returns {Promise<Object>}
 */
const getAdminDisputeById = async (disputeId) => {
  const dispute = await prisma.dispute.findUnique({
    where: { id: disputeId },
    include: {
      transaction: {
        include: {
          buyer: { select: USER_SELECT },
          seller: { select: USER_SELECT },
          shipmentProof: true,
        },
      },
      openedBy: { select: USER_SELECT },
      resolvedBy: { select: USER_SELECT },
      evidences: {
        include: {
          submittedBy: { select: USER_SELECT },
        },
        orderBy: { createdAt: 'asc' },
      },
    },
  });

  if (!dispute) {
    throw new ApiError(404, 'Sengketa tidak ditemukan.');
  }

  return dispute;
};

/**
 * Admin: review dispute, moving status OPEN → UNDER_REVIEW.
 *
 * @param {string} disputeId
 * @param {string} _adminId
 * @returns {Promise<Object>}
 */
const reviewDispute = async (disputeId, _adminId) => {
  const updateResult = await prisma.dispute.updateMany({
    where: { id: disputeId, status: DISPUTE_STATUS.OPEN },
    data: { status: DISPUTE_STATUS.UNDER_REVIEW },
  });

  if (updateResult.count === 0) {
    const existing = await prisma.dispute.findUnique({ where: { id: disputeId } });
    if (!existing) {
      throw new ApiError(404, 'Sengketa tidak ditemukan.');
    }
    throw new ApiError(400, 'Sengketa hanya dapat ditinjau saat berstatus OPEN.');
  }

  return await getAdminDisputeById(disputeId);
};

/**
 * Admin: resolve dispute atomically with escrow movement.
 * Decision RELEASE_TO_SELLER: calls releaseEscrow() and marks RESOLVED_SELLER.
 * Decision REFUND_TO_BUYER: calls refundEscrow() and marks RESOLVED_BUYER.
 * Uses compare-and-swap inside a single database transaction to prevent double resolution.
 *
 * @param {string} disputeId
 * @param {string} adminId
 * @param {Object} params
 * @param {string} params.decision - 'RELEASE_TO_SELLER' or 'REFUND_TO_BUYER'
 * @param {string} params.note - Min 10 chars
 * @returns {Promise<Object>} Resolved dispute
 */
const resolveDispute = async (disputeId, adminId, { decision, note }) => {
  if (![DISPUTE_DECISION.RELEASE_TO_SELLER, DISPUTE_DECISION.REFUND_TO_BUYER].includes(decision)) {
    throw new ApiError(
      400,
      `Keputusan sengketa tidak valid. Pilihan: ${Object.values(DISPUTE_DECISION).join(', ')}.`
    );
  }

  if (typeof note !== 'string' || note.trim().length < 10) {
    throw new ApiError(400, 'Catatan resolusi sengketa minimal 10 karakter.');
  }

  return await prisma.$transaction(async (tx) => {
    // 1. Fetch dispute and check status
    const dispute = await tx.dispute.findUnique({
      where: { id: disputeId },
      include: { transaction: true },
    });

    if (!dispute) {
      throw new ApiError(404, 'Sengketa tidak ditemukan.');
    }

    if (![DISPUTE_STATUS.OPEN, DISPUTE_STATUS.UNDER_REVIEW].includes(dispute.status)) {
      throw new ApiError(409, 'Sengketa sudah diselesaikan sebelumnya.');
    }

    const targetStatus =
      decision === DISPUTE_DECISION.RELEASE_TO_SELLER
        ? DISPUTE_STATUS.RESOLVED_SELLER
        : DISPUTE_STATUS.RESOLVED_BUYER;

    // 2. CAS update dispute status
    const updateResult = await tx.dispute.updateMany({
      where: {
        id: disputeId,
        status: { in: [DISPUTE_STATUS.OPEN, DISPUTE_STATUS.UNDER_REVIEW] },
      },
      data: {
        status: targetStatus,
        resolutionNote: note.trim(),
        resolvedById: adminId,
        resolvedAt: new Date(),
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Sengketa sudah diselesaikan oleh proses lain.');
    }

    // 3. Execute escrow movement in the exact same database transaction
    if (decision === DISPUTE_DECISION.RELEASE_TO_SELLER) {
      await releaseEscrow(tx, dispute.transactionId, adminId);
    } else {
      await refundEscrow(tx, dispute.transactionId, adminId, note.trim());
    }

    // 4. Return full dispute detail
    return await tx.dispute.findUnique({
      where: { id: disputeId },
      include: {
        transaction: {
          include: {
            buyer: { select: USER_SELECT },
            seller: { select: USER_SELECT },
            shipmentProof: true,
          },
        },
        openedBy: { select: USER_SELECT },
        resolvedBy: { select: USER_SELECT },
        evidences: {
          include: {
            submittedBy: { select: USER_SELECT },
          },
        },
      },
    });
  });
};

module.exports = {
  openDispute,
  submitEvidence,
  getDisputeById,
  getDisputeByTransactionId,
  getAdminDisputes,
  getAdminDisputeById,
  reviewDispute,
  resolveDispute,
};
