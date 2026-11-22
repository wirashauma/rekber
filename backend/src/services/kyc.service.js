// =============================================================================
// KYC Service - User Identity Verification & Admin Review Workflow
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { encrypt, decrypt, maskNik } = require('../utils/encryption');
const { getFileSignedUrl } = require('./file.service');
const auditService = require('./audit.service');
const notificationService = require('./notification.service');

/**
 * Submits user identity verification (KYC).
 *
 * @param {string} userId
 * @param {Object} payload
 * @param {string} payload.fullName
 * @param {string} payload.nik - 16-digit Indonesian NIK
 * @param {string} payload.idFileId - FileAsset ID with purpose KYC_ID
 * @param {string} payload.selfieFileId - FileAsset ID with purpose KYC_SELFIE
 * @returns {Promise<Object>}
 */
const submitKyc = async (userId, { fullName, nik, idFileId, selfieFileId }) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, kycStatus: true, isActive: true },
  });

  if (!user) {
    throw new ApiError(404, 'Pengguna tidak ditemukan.');
  }

  if (user.kycStatus === 'PENDING') {
    throw new ApiError(400, 'Pengajuan KYC Anda sedang ditinjau.');
  }

  if (user.kycStatus === 'APPROVED') {
    throw new ApiError(400, 'Akun Anda sudah terverifikasi KYC (APPROVED).');
  }

  // Validate NIK (16 digits)
  const cleanNik = (nik || '').toString().trim();
  if (!/^\d{16}$/.test(cleanNik)) {
    throw new ApiError(422, 'NIK harus terdiri dari tepat 16 digit angka.');
  }

  if (!fullName || typeof fullName !== 'string' || fullName.trim().length < 3) {
    throw new ApiError(422, 'Nama lengkap wajib diisi minimal 3 karakter.');
  }

  // Validate files
  const idFile = await prisma.fileAsset.findUnique({
    where: { id: idFileId },
  });
  if (!idFile || idFile.deletedAt) {
    throw new ApiError(400, 'Berkas foto KTP (idFileId) tidak ditemukan.');
  }
  if (idFile.ownerId !== userId) {
    throw new ApiError(403, 'Berkas foto KTP harus milik akun Anda sendiri.');
  }
  if (idFile.purpose !== 'KYC_ID') {
    throw new ApiError(400, 'Tujuan berkas foto KTP harus KYC_ID.');
  }

  const selfieFile = await prisma.fileAsset.findUnique({
    where: { id: selfieFileId },
  });
  if (!selfieFile || selfieFile.deletedAt) {
    throw new ApiError(400, 'Berkas foto selfie (selfieFileId) tidak ditemukan.');
  }
  if (selfieFile.ownerId !== userId) {
    throw new ApiError(403, 'Berkas foto selfie harus milik akun Anda sendiri.');
  }
  if (selfieFile.purpose !== 'KYC_SELFIE') {
    throw new ApiError(400, 'Tujuan berkas foto selfie harus KYC_SELFIE.');
  }

  const nikEnc = encrypt(cleanNik);

  const [updatedUser, submission] = await prisma.$transaction([
    prisma.user.update({
      where: { id: userId },
      data: { kycStatus: 'PENDING' },
    }),
    prisma.kycSubmission.create({
      data: {
        userId,
        fullName: fullName.trim(),
        nikEnc,
        idFileId,
        selfieFileId,
        status: 'PENDING',
      },
    }),
  ]);

  return {
    id: submission.id,
    userId: submission.userId,
    fullName: submission.fullName,
    nikMasked: maskNik(cleanNik),
    status: submission.status,
    kycStatus: updatedUser.kycStatus,
    createdAt: submission.createdAt,
  };
};

/**
 * Retrieves current KYC status and latest submission for authenticated user.
 *
 * @param {Object} user
 * @returns {Promise<Object>}
 */
const getMyKyc = async (user) => {
  const freshUser = await prisma.user.findUnique({
    where: { id: user.id },
    select: { id: true, kycStatus: true },
  });

  const latestSubmission = await prisma.kycSubmission.findFirst({
    where: { userId: user.id },
    orderBy: { createdAt: 'desc' },
  });

  const currentKycStatus = freshUser?.kycStatus || user.kycStatus || 'NONE';

  if (!latestSubmission) {
    return {
      kycStatus: currentKycStatus,
      submission: null,
    };
  }

  let nikMasked = '••••••••••••••••';
  try {
    const plainNik = decrypt(latestSubmission.nikEnc);
    nikMasked = maskNik(plainNik);
  } catch {
    // Keep fallback masked
  }

  // Generate signed URLs for preview
  let idFileUrl = null;
  let selfieFileUrl = null;
  try {
    const idRes = await getFileSignedUrl(latestSubmission.idFileId, user);
    idFileUrl = idRes.url;
    const selfieRes = await getFileSignedUrl(latestSubmission.selfieFileId, user);
    selfieFileUrl = selfieRes.url;
  } catch {
    // Suppress file error if storage not ready
  }

  return {
    kycStatus: currentKycStatus,
    submission: {
      id: latestSubmission.id,
      fullName: latestSubmission.fullName,
      nikMasked,
      status: latestSubmission.status,
      rejectionReason: latestSubmission.rejectionReason,
      reviewedAt: latestSubmission.reviewedAt,
      idFileUrl,
      selfieFileUrl,
      createdAt: latestSubmission.createdAt,
    },
  };
};

/**
 * Retrieves list of KYC submissions for admin review with status filter and pagination.
 *
 * @param {Object} query
 * @param {string} [query.status]
 * @param {string} [query.cursor]
 * @param {number} [query.limit=20]
 * @returns {Promise<{ submissions: Array, nextCursor: string|null, hasMore: boolean }>}
 */
const getAdminKycSubmissions = async ({ status, cursor, limit = 20 }) => {
  const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

  const where = {};
  if (status) {
    where.status = status;
  }

  const queryOptions = {
    where,
    take: parsedLimit + 1,
    orderBy: { createdAt: 'desc' },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
  };

  if (cursor) {
    queryOptions.cursor = { id: cursor };
    queryOptions.skip = 1;
  }

  const items = await prisma.kycSubmission.findMany(queryOptions);

  let nextCursor = null;
  let hasMore = false;

  if (items.length > parsedLimit) {
    hasMore = true;
    const extra = items.pop();
    nextCursor = extra.id;
  }

  // Mask NIK on each submission
  const maskedItems = items.map((sub) => {
    let nikMasked = '••••••••••••••••';
    try {
      nikMasked = maskNik(decrypt(sub.nikEnc));
    } catch {
      // fallback
    }
    const { nikEnc: _, ...rest } = sub;
    return {
      ...rest,
      nikMasked,
    };
  });

  return {
    submissions: maskedItems,
    nextCursor,
    hasMore,
  };
};

/**
 * Retrieves full details of a specific KYC submission for admin review.
 *
 * @param {string} id
 * @param {Object} adminUser
 * @returns {Promise<Object>}
 */
const getAdminKycById = async (id, adminUser) => {
  const submission = await prisma.kycSubmission.findUnique({
    where: { id },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          kycStatus: true,
          createdAt: true,
        },
      },
      reviewedBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
  });

  if (!submission) {
    throw new ApiError(404, 'Pengajuan KYC tidak ditemukan.');
  }

  let nikMasked = '••••••••••••••••';
  try {
    nikMasked = maskNik(decrypt(submission.nikEnc));
  } catch {
    // fallback
  }

  let idFileUrl = null;
  let selfieFileUrl = null;
  try {
    const idRes = await getFileSignedUrl(submission.idFileId, adminUser);
    idFileUrl = idRes.url;
    const selfieRes = await getFileSignedUrl(submission.selfieFileId, adminUser);
    selfieFileUrl = selfieRes.url;
  } catch {
    // fallback
  }

  const { nikEnc: _, ...rest } = submission;
  return {
    ...rest,
    nikMasked,
    idFileUrl,
    selfieFileUrl,
  };
};

/**
 * Approves a KYC submission.
 *
 * @param {string} id
 * @param {Object} adminUser
 * @param {string} [ip]
 * @returns {Promise<Object>}
 */
const approveKyc = async (id, adminUser, ip) => {
  const submission = await prisma.kycSubmission.findUnique({
    where: { id },
  });

  if (!submission) {
    throw new ApiError(404, 'Pengajuan KYC tidak ditemukan.');
  }

  if (submission.status !== 'PENDING') {
    throw new ApiError(400, 'Hanya pengajuan berstatus PENDING yang dapat disetujui.');
  }

  const [updatedSubmission] = await prisma.$transaction([
    prisma.kycSubmission.update({
      where: { id },
      data: {
        status: 'APPROVED',
        reviewedById: adminUser.id,
        reviewedAt: new Date(),
        rejectionReason: null,
      },
    }),
    prisma.user.update({
      where: { id: submission.userId },
      data: { kycStatus: 'APPROVED' },
    }),
  ]);

  // Record audit log
  await auditService.log({
    actorId: adminUser.id,
    action: 'KYC_APPROVE',
    targetType: 'KYC_SUBMISSION',
    targetId: id,
    before: { status: 'PENDING' },
    after: { status: 'APPROVED' },
    ip,
  });

  // Notify user
  notificationService
    .notify(submission.userId, {
      type: 'KYC_STATUS_CHANGED',
      title: 'KYC Terverifikasi',
      body: 'Selamat! Pengajuan KYC Anda telah disetujui. Akun Anda kini dapat melakukan penarikan dana.',
      data: { submissionId: id, status: 'APPROVED' },
    })
    .catch(() => {});

  let nikMasked = '••••••••••••••••';
  try {
    nikMasked = maskNik(decrypt(updatedSubmission.nikEnc));
  } catch {
    // fallback
  }

  const { nikEnc: _, ...rest } = updatedSubmission;
  return {
    ...rest,
    nikMasked,
  };
};

/**
 * Rejects a KYC submission with reason.
 *
 * @param {string} id
 * @param {Object} adminUser
 * @param {string} reason
 * @param {string} [ip]
 * @returns {Promise<Object>}
 */
const rejectKyc = async (id, adminUser, reason, ip) => {
  if (!reason || typeof reason !== 'string' || reason.trim().length < 5) {
    throw new ApiError(422, 'Alasan penolakan (reason) wajib diisi minimal 5 karakter.');
  }

  const submission = await prisma.kycSubmission.findUnique({
    where: { id },
  });

  if (!submission) {
    throw new ApiError(404, 'Pengajuan KYC tidak ditemukan.');
  }

  if (submission.status !== 'PENDING') {
    throw new ApiError(400, 'Hanya pengajuan berstatus PENDING yang dapat ditolak.');
  }

  const [updatedSubmission] = await prisma.$transaction([
    prisma.kycSubmission.update({
      where: { id },
      data: {
        status: 'REJECTED',
        rejectionReason: reason.trim(),
        reviewedById: adminUser.id,
        reviewedAt: new Date(),
      },
    }),
    prisma.user.update({
      where: { id: submission.userId },
      data: { kycStatus: 'REJECTED' },
    }),
  ]);

  // Record audit log
  await auditService.log({
    actorId: adminUser.id,
    action: 'KYC_REJECT',
    targetType: 'KYC_SUBMISSION',
    targetId: id,
    before: { status: 'PENDING' },
    after: { status: 'REJECTED', reason: reason.trim() },
    ip,
  });

  // Notify user
  notificationService
    .notify(submission.userId, {
      type: 'KYC_STATUS_CHANGED',
      title: 'KYC Ditolak',
      body: `Pengajuan KYC Anda ditolak: ${reason.trim()}. Silakan perbaiki dan ajukan ulang dokumen Anda.`,
      data: { submissionId: id, status: 'REJECTED', reason: reason.trim() },
    })
    .catch(() => {});

  let nikMasked = '••••••••••••••••';
  try {
    nikMasked = maskNik(decrypt(updatedSubmission.nikEnc));
  } catch {
    // fallback
  }

  const { nikEnc: _, ...rest } = updatedSubmission;
  return {
    ...rest,
    nikMasked,
  };
};

module.exports = {
  submitKyc,
  getMyKyc,
  getAdminKycSubmissions,
  getAdminKycById,
  approveKyc,
  rejectKyc,
};
