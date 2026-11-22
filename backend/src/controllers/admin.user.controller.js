// =============================================================================
// Admin User Management Controller
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const auditService = require('../services/audit.service');

/**
 * GET /admin/users
 * Search and filter users by status and keywords with cursor pagination.
 */
const getUsers = async (req, res, next) => {
  try {
    const { search, status, kycStatus, cursor, limit = 20 } = req.query;
    const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

    const where = {};

    if (search && typeof search === 'string' && search.trim() !== '') {
      const q = search.trim();
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
      ];
    }

    if (status) {
      if (status === 'active') where.isActive = true;
      else if (status === 'banned') where.isActive = false;
    }

    if (kycStatus) {
      where.kycStatus = kycStatus;
    }

    const queryOptions = {
      where,
      take: parsedLimit + 1,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        balance: true,
        isActive: true,
        kycStatus: true,
        createdAt: true,
        updatedAt: true,
      },
    };

    if (cursor) {
      queryOptions.cursor = { id: cursor };
      queryOptions.skip = 1;
    }

    const items = await prisma.user.findMany(queryOptions);

    let nextCursor = null;
    let hasMore = false;

    if (items.length > parsedLimit) {
      hasMore = true;
      const extra = items.pop();
      nextCursor = extra.id;
    }

    res.status(200).json({
      success: true,
      data: items,
      nextCursor,
      hasMore,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /admin/users/:id
 * Retrieve detailed summary of a specific user (strictly excluding password).
 */
const getUserById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        balance: true,
        isActive: true,
        kycStatus: true,
        firebaseUid: true,
        createdAt: true,
        updatedAt: true,
        _count: {
          select: {
            buyerTransactions: true,
            sellerTransactions: true,
            bankAccounts: true,
            withdrawals: true,
          },
        },
        kycSubmissions: {
          take: 1,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            fullName: true,
            status: true,
            createdAt: true,
            reviewedAt: true,
          },
        },
      },
    });

    if (!user) {
      throw new ApiError(404, 'Pengguna tidak ditemukan.');
    }

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /admin/users/:id/ban
 * Bans a user account, revokes all refresh tokens, and records audit log.
 * Disallows banning oneself or fellow administrators.
 */
const banUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    if (!reason || typeof reason !== 'string' || reason.trim().length < 3) {
      throw new ApiError(422, 'Alasan pemblokiran (reason) wajib diisi minimal 3 karakter.');
    }

    const targetUser = await prisma.user.findUnique({
      where: { id },
    });

    if (!targetUser) {
      throw new ApiError(404, 'Pengguna tidak ditemukan.');
    }

    // Protection checks
    if (req.user.id === targetUser.id) {
      throw new ApiError(400, 'Tidak dapat memblokir akun Anda sendiri.');
    }

    if (targetUser.role === 'ADMIN') {
      throw new ApiError(400, 'Tidak dapat memblokir akun sesama administrator.');
    }

    // Execute ban and token revocation
    await prisma.$transaction([
      prisma.user.update({
        where: { id },
        data: { isActive: false },
      }),
      prisma.refreshToken.updateMany({
        where: { userId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    // Record audit log
    await auditService.log({
      actorId: req.user.id,
      action: 'USER_BAN',
      targetType: 'USER',
      targetId: id,
      before: { isActive: targetUser.isActive },
      after: { isActive: false, reason: reason.trim() },
      ip: req.ip,
    });

    res.status(200).json({
      success: true,
      message: 'Akun pengguna berhasil diblokir.',
      data: {
        id,
        isActive: false,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /admin/users/:id/unban
 * Unbans a user account and records audit log.
 */
const unbanUser = async (req, res, next) => {
  try {
    const { id } = req.params;

    const targetUser = await prisma.user.findUnique({
      where: { id },
    });

    if (!targetUser) {
      throw new ApiError(404, 'Pengguna tidak ditemukan.');
    }

    if (req.user.id === targetUser.id) {
      throw new ApiError(400, 'Tidak dapat mengubah status pemblokiran akun Anda sendiri.');
    }

    if (targetUser.role === 'ADMIN') {
      throw new ApiError(400, 'Tidak dapat mengubah status akun sesama administrator.');
    }

    await prisma.user.update({
      where: { id },
      data: { isActive: true },
    });

    await auditService.log({
      actorId: req.user.id,
      action: 'USER_UNBAN',
      targetType: 'USER',
      targetId: id,
      before: { isActive: targetUser.isActive },
      after: { isActive: true },
      ip: req.ip,
    });

    res.status(200).json({
      success: true,
      message: 'Pemblokiran akun pengguna berhasil dicabut.',
      data: {
        id,
        isActive: true,
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getUsers,
  getUserById,
  banUser,
  unbanUser,
};
