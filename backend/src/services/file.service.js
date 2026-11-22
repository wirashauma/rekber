// =============================================================================
// File Service - File Assets, Access Policies & Orphan Cleanup
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { getStorageProvider } = require('../providers/storage');

/**
 * Access policy registry per file purpose.
 * Defines who is authorized to view or generate signed download URLs.
 */
const fileAccessPolicies = {
  SHIPMENT_PROOF: async (file, user) => {
    // 1. Owner can always access
    if (file.ownerId === user.id) return true;

    // 2. Platform Admin can always access
    if (user.role === 'ADMIN') return true;

    // 3. Buyer or Seller in the associated transaction
    const proof = await prisma.shipmentProof.findFirst({
      where: {
        fileIds: {
          has: file.id,
        },
      },
      include: {
        transaction: {
          select: { buyerId: true, sellerId: true },
        },
      },
    });

    if (proof && proof.transaction) {
      if (proof.transaction.buyerId === user.id || proof.transaction.sellerId === user.id) {
        return true;
      }
    }

    return false;
  },

  DISPUTE_EVIDENCE: async (file, user) => {
    // 1. Owner can always access
    if (file.ownerId === user.id) return true;

    // 2. Platform Admin can always access
    if (user.role === 'ADMIN') return true;

    // 3. Buyer or Seller in the associated disputed transaction
    const evidence = await prisma.disputeEvidence.findFirst({
      where: {
        fileIds: {
          has: file.id,
        },
      },
      include: {
        dispute: {
          include: {
            transaction: {
              select: { buyerId: true, sellerId: true },
            },
          },
        },
      },
    });

    if (evidence && evidence.dispute && evidence.dispute.transaction) {
      const tx = evidence.dispute.transaction;
      if (tx.buyerId === user.id || tx.sellerId === user.id) {
        return true;
      }
    }

    return false;
  },

  KYC_ID: async (file, user) => {
    // Default: owner + admin (expanded in Prompt 14)
    return file.ownerId === user.id || user.role === 'ADMIN';
  },

  KYC_SELFIE: async (file, user) => {
    // Default: owner + admin (expanded in Prompt 14)
    return file.ownerId === user.id || user.role === 'ADMIN';
  },

  CHAT_IMAGE: async (file, user) => {
    // 1. Owner can always access
    if (file.ownerId === user.id) return true;

    // 2. Find associated chat message and its transaction
    const message = await prisma.chatMessage.findFirst({
      where: {
        fileId: file.id,
      },
      include: {
        transaction: {
          select: { buyerId: true, sellerId: true, status: true },
        },
      },
    });

    if (message && message.transaction) {
      const tx = message.transaction;
      // 3. Buyer or Seller in the associated transaction
      if (tx.buyerId === user.id || tx.sellerId === user.id) {
        return true;
      }

      // 4. Admin ONLY when transaction is in DISPUTED status
      if (user.role === 'ADMIN' && tx.status === 'DISPUTED') {
        return true;
      }
    }

    return false;
  },
};

/**
 * Creates and persists a new FileAsset in storage and database.
 *
 * @param {string} userId
 * @param {Object} params
 * @param {string} params.purpose
 * @param {Object} params.fileProcessed - From uploadAndSanitize middleware
 * @returns {Promise<Object>}
 */
const createFileAsset = async (userId, { purpose, fileProcessed }) => {
  const validPurposes = [
    'SHIPMENT_PROOF',
    'DISPUTE_EVIDENCE',
    'KYC_ID',
    'KYC_SELFIE',
    'CHAT_IMAGE',
  ];

  if (!purpose || !validPurposes.includes(purpose.toUpperCase())) {
    throw new ApiError(
      400,
      `Tujuan berkas (purpose) tidak valid. Pilihan: ${validPurposes.join(', ')}.`
    );
  }

  const normalizedPurpose = purpose.toUpperCase();
  const storage = getStorageProvider();

  // 1. Upload to storage provider
  await storage.put({
    key: fileProcessed.storageKey,
    buffer: fileProcessed.buffer,
    mime: fileProcessed.mime,
  });

  // 2. Persist in database
  const fileAsset = await prisma.fileAsset.create({
    data: {
      ownerId: userId,
      purpose: normalizedPurpose,
      storageKey: fileProcessed.storageKey,
      mime: fileProcessed.mime,
      size: fileProcessed.size,
      sha256: fileProcessed.sha256,
    },
  });

  return fileAsset;
};

/**
 * Generates a short-lived signed URL for downloading a file asset.
 * Enforces fileAccessPolicies.
 *
 * @param {string} fileId
 * @param {Object} user - { id, role }
 * @param {number} [expiresInSeconds=300]
 * @returns {Promise<{ url: string, expiresIn: number }>}
 */
const getFileSignedUrl = async (fileId, user, expiresInSeconds = 300) => {
  const file = await prisma.fileAsset.findFirst({
    where: { id: fileId, deletedAt: null },
  });

  if (!file) {
    throw new ApiError(404, 'Berkas tidak ditemukan.');
  }

  const policy = fileAccessPolicies[file.purpose];
  const canAccess = policy
    ? await policy(file, user)
    : file.ownerId === user.id || user.role === 'ADMIN';

  if (!canAccess) {
    throw new ApiError(403, 'Akses ditolak. Anda tidak memiliki izin untuk melihat berkas ini.');
  }

  const storage = getStorageProvider();
  const url = await storage.getSignedUrl({
    key: file.storageKey,
    expiresInSeconds,
  });

  return {
    url,
    expiresIn: expiresInSeconds,
  };
};

/**
 * Cleans up unreferenced orphan files created > 24 hours ago.
 * Function only (scheduled background invocation in Prompt 12).
 *
 * @returns {Promise<{ cleanedCount: number, orphanIds: string[] }>}
 */
const cleanupOrphanFiles = async () => {
  const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  // Find candidate files created > 24h ago with no deletedAt
  const candidates = await prisma.fileAsset.findMany({
    where: {
      createdAt: { lt: twentyFourHoursAgo },
      deletedAt: null,
    },
  });

  const storage = getStorageProvider();
  const orphanIds = [];

  for (const candidate of candidates) {
    let isReferenced = false;

    if (candidate.purpose === 'SHIPMENT_PROOF') {
      const count = await prisma.shipmentProof.count({
        where: {
          fileIds: { has: candidate.id },
        },
      });
      isReferenced = count > 0;
    } else if (candidate.purpose === 'DISPUTE_EVIDENCE') {
      const count = await prisma.disputeEvidence.count({
        where: {
          fileIds: { has: candidate.id },
        },
      });
      isReferenced = count > 0;
    }

    if (!isReferenced) {
      try {
        await storage.delete({ key: candidate.storageKey });
      } catch {
        // continue even if file already missing from storage
      }

      await prisma.fileAsset.update({
        where: { id: candidate.id },
        data: { deletedAt: new Date() },
      });

      orphanIds.push(candidate.id);
    }
  }

  return {
    cleanedCount: orphanIds.length,
    orphanIds,
  };
};

module.exports = {
  fileAccessPolicies,
  createFileAsset,
  getFileSignedUrl,
  cleanupOrphanFiles,
};
