// =============================================================================
// Auth Service
// =============================================================================
// Handles all business logic for authentication, rotating refresh tokens,
// password resets, and session management.

const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');
const config = require('../config');
const { ApiError } = require('../middlewares/error.middleware');
const mailProvider = require('../providers/mail.provider');

/**
 * Computes a SHA-256 hash of a plain token string.
 */
const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

/**
 * Generates an access token with a 15-minute lifespan.
 */
const generateAccessToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
    },
    config.jwt.secret,
    {
      expiresIn: '15m',
    }
  );
};

/**
 * Creates and persists a random 32-byte refresh token with 30 days validity.
 */
const createAndSaveRefreshToken = async (userId, { userAgent, ip } = {}) => {
  const rawToken = crypto.randomBytes(32).toString('hex');
  const tokenHash = hashToken(rawToken);
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash,
      expiresAt,
      userAgent: userAgent || null,
      ip: ip || null,
    },
  });

  return rawToken;
};

/**
 * Register a new user.
 */
const register = async ({ name, email, password, userAgent, ip }) => {
  const existingUser = await prisma.user.findUnique({ where: { email } });

  if (existingUser) {
    throw new ApiError(409, 'Email sudah terdaftar. Gunakan email lain.', [], 'EMAIL_EXISTS');
  }

  const hashedPassword = await bcrypt.hash(password, config.bcrypt.saltRounds);

  const user = await prisma.user.create({
    data: {
      name,
      email,
      password: hashedPassword,
      isActive: true,
    },
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      balance: true,
      isActive: true,
      createdAt: true,
    },
  });

  const accessToken = generateAccessToken(user);
  const refreshToken = await createAndSaveRefreshToken(user.id, { userAgent, ip });

  return {
    accessToken,
    refreshToken,
    token: accessToken, // Retained for backwards compatibility until Prompt 4
    user,
  };
};

/**
 * Authenticate an existing user.
 */
const login = async ({ email, password, userAgent, ip }) => {
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user) {
    throw new ApiError(401, 'Email atau password salah.', [], 'INVALID_CREDENTIALS');
  }

  if (!user.isActive) {
    throw new ApiError(
      403,
      'Akun Anda telah dinonaktifkan. Hubungi admin.',
      [],
      'ACCOUNT_INACTIVE'
    );
  }

  const isPasswordValid = await bcrypt.compare(password, user.password);

  if (!isPasswordValid) {
    throw new ApiError(401, 'Email atau password salah.', [], 'INVALID_CREDENTIALS');
  }

  const accessToken = generateAccessToken(user);
  const refreshToken = await createAndSaveRefreshToken(user.id, { userAgent, ip });

  const { password: _, ...userWithoutPassword } = user;

  return {
    accessToken,
    refreshToken,
    token: accessToken, // Retained for backwards compatibility until Prompt 4
    user: userWithoutPassword,
  };
};

/**
 * Rotate refresh token with theft detection.
 */
const refresh = async ({ refreshToken, userAgent, ip }) => {
  if (!refreshToken) {
    throw new ApiError(400, 'Refresh token wajib disertakan.', [], 'BAD_REQUEST');
  }

  const tokenHash = hashToken(refreshToken);
  const existingToken = await prisma.refreshToken.findUnique({
    where: { tokenHash },
    include: { user: true },
  });

  if (!existingToken) {
    throw new ApiError(401, 'Refresh token tidak valid.', [], 'INVALID_REFRESH_TOKEN');
  }

  // Theft detection: if revoked token is used again, revoke ALL tokens for this user
  if (existingToken.revokedAt) {
    await prisma.refreshToken.updateMany({
      where: { userId: existingToken.userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    throw new ApiError(
      401,
      'Keamanan terdeteksi dikompromikan: Token telah dicabut sebelumnya. Semua sesi dihentikan demi keamanan.',
      [],
      'TOKEN_THEFT_DETECTED'
    );
  }

  // Expiration check
  if (existingToken.expiresAt < new Date()) {
    throw new ApiError(
      401,
      'Refresh token sudah kedaluwarsa. Silakan login kembali.',
      [],
      'REFRESH_TOKEN_EXPIRED'
    );
  }

  // Check user active status
  if (!existingToken.user || !existingToken.user.isActive) {
    throw new ApiError(403, 'Akun Anda dinonaktifkan.', [], 'ACCOUNT_INACTIVE');
  }

  const newRefreshToken = crypto.randomBytes(32).toString('hex');
  const newHash = hashToken(newRefreshToken);
  const newExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  const newAccessToken = generateAccessToken(existingToken.user);

  await prisma.$transaction(async (tx) => {
    const created = await tx.refreshToken.create({
      data: {
        userId: existingToken.userId,
        tokenHash: newHash,
        expiresAt: newExpiresAt,
        userAgent: userAgent || null,
        ip: ip || null,
      },
    });

    await tx.refreshToken.update({
      where: { id: existingToken.id },
      data: {
        revokedAt: new Date(),
        replacedById: created.id,
      },
    });
  });

  return {
    accessToken: newAccessToken,
    refreshToken: newRefreshToken,
    token: newAccessToken,
  };
};

/**
 * Logout single session by revoking the refresh token.
 */
const logout = async ({ refreshToken }) => {
  if (refreshToken) {
    const tokenHash = hashToken(refreshToken);
    await prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
  return true;
};

/**
 * Logout all active sessions for a user.
 */
const logoutAll = async (userId) => {
  await prisma.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
  return true;
};

/**
 * Change user password and revoke all active refresh tokens.
 */
const changePassword = async (userId, { oldPassword, newPassword }) => {
  const user = await prisma.user.findUnique({ where: { id: userId } });

  if (!user) {
    throw new ApiError(404, 'User tidak ditemukan.', [], 'USER_NOT_FOUND');
  }

  const isMatch = await bcrypt.compare(oldPassword, user.password);
  if (!isMatch) {
    throw new ApiError(400, 'Password lama salah.', [], 'INVALID_OLD_PASSWORD');
  }

  if (oldPassword === newPassword) {
    throw new ApiError(
      400,
      'Password baru tidak boleh sama dengan password lama.',
      [],
      'SAME_PASSWORD'
    );
  }

  const hashedPassword = await bcrypt.hash(newPassword, config.bcrypt.saltRounds);

  await prisma.$transaction(async (tx) => {
    await tx.user.update({
      where: { id: userId },
      data: { password: hashedPassword },
    });

    // Revoke all refresh tokens
    await tx.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  });

  return true;
};

/**
 * Initiate password reset. Response is ALWAYS generic to prevent user enumeration.
 */
const forgotPassword = async ({ email }) => {
  const user = await prisma.user.findUnique({ where: { email } });

  if (user && user.isActive) {
    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = hashToken(rawToken);
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000); // 30 minutes

    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });

    await mailProvider.sendPasswordResetEmail(user.email, rawToken);
  }

  return 'Jika email terdaftar, instruksi reset password telah dikirimkan.';
};

/**
 * Reset password using a valid reset token.
 */
const resetPassword = async ({ token, newPassword }) => {
  const tokenHash = hashToken(token);
  const resetRecord = await prisma.passwordResetToken.findUnique({
    where: { tokenHash },
    include: { user: true },
  });

  if (!resetRecord) {
    throw new ApiError(400, 'Token reset password tidak valid.', [], 'INVALID_TOKEN');
  }

  if (resetRecord.usedAt) {
    throw new ApiError(400, 'Token reset password sudah digunakan.', [], 'TOKEN_ALREADY_USED');
  }

  if (resetRecord.expiresAt < new Date()) {
    throw new ApiError(400, 'Token reset password sudah kedaluwarsa.', [], 'TOKEN_EXPIRED');
  }

  const hashedPassword = await bcrypt.hash(newPassword, config.bcrypt.saltRounds);

  await prisma.$transaction(async (tx) => {
    await tx.user.update({
      where: { id: resetRecord.userId },
      data: { password: hashedPassword },
    });

    await tx.passwordResetToken.update({
      where: { id: resetRecord.id },
      data: { usedAt: new Date() },
    });

    // Revoke all refresh tokens on password reset
    await tx.refreshToken.updateMany({
      where: { userId: resetRecord.userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  });

  return true;
};

/**
 * Get current user data.
 */
const me = async (userId) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      balance: true,
      isActive: true,
      firebaseUid: true,
      fcmToken: true,
      createdAt: true,
    },
  });

  if (!user) {
    throw new ApiError(404, 'User tidak ditemukan.', [], 'USER_NOT_FOUND');
  }

  return user;
};

/**
 * Update user profile details.
 */
const updateProfile = async (userId, { name }) => {
  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: { name },
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      balance: true,
      isActive: true,
      firebaseUid: true,
      fcmToken: true,
      createdAt: true,
    },
  });

  return updatedUser;
};

/**
 * Update FCM token for notifications.
 */
const updateFcm = async (userId, fcmToken) => {
  return await prisma.user.update({
    where: { id: userId },
    data: { fcmToken },
  });
};

/**
 * Search other users by email or name for transactions.
 */
const searchOpponent = async (currentUserId, query) => {
  const users = await prisma.user.findMany({
    where: {
      id: { not: currentUserId },
      isActive: true,
      OR: [
        { email: { contains: query.trim(), mode: 'insensitive' } },
        { name: { contains: query.trim(), mode: 'insensitive' } },
      ],
    },
    select: {
      id: true,
      name: true,
      email: true,
    },
    take: 5,
  });

  return users;
};

module.exports = {
  register,
  login,
  refresh,
  logout,
  logoutAll,
  changePassword,
  forgotPassword,
  resetPassword,
  me,
  updateProfile,
  updateFcm,
  searchOpponent,
  hashToken,
};
