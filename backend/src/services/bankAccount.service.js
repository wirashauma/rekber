// =============================================================================
// Bank Account Service
// =============================================================================
// Manages user bank account lifecycle with AES-256-GCM encryption and masking.

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { encrypt, decrypt, maskAccountNumber } = require('../utils/encryption');
const { calculateNameMatch } = require('../utils/stringSimilarity');

/**
 * Adds a new bank account for a user.
 * Maximum 3 active bank accounts allowed per user.
 *
 * @param {string} userId
 * @param {Object} data
 * @param {string} data.bankCode
 * @param {string} data.accountNumber
 * @param {string} data.accountName
 * @param {boolean} [data.isDefault]
 * @returns {Promise<Object>} Sanitized bank account object
 */
const createBankAccount = async (
  userId,
  { bankCode, accountNumber, accountName, isDefault = false }
) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true, isActive: true },
  });

  if (!user) {
    throw new ApiError(404, 'Pengguna tidak ditemukan.');
  }

  if (!user.isActive) {
    throw new ApiError(403, 'Akun Anda dinonaktifkan.');
  }

  // Enforce maximum 3 active bank accounts
  const activeCount = await prisma.bankAccount.count({
    where: { userId, deletedAt: null },
  });

  if (activeCount >= 3) {
    throw new ApiError(400, 'Maksimal 3 rekening bank aktif per pengguna.');
  }

  const cleanAccountNumber = accountNumber.replace(/\s+/g, '');
  const accountLast4 = cleanAccountNumber.slice(-4);
  const accountNumberEnc = encrypt(cleanAccountNumber);
  const nameMatch = calculateNameMatch(user.name, accountName);

  // If first account or requested as default, manage isDefault flag
  const shouldBeDefault = isDefault || activeCount === 0;

  return await prisma.$transaction(async (tx) => {
    if (shouldBeDefault) {
      await tx.bankAccount.updateMany({
        where: { userId, deletedAt: null },
        data: { isDefault: false },
      });
    }

    const created = await tx.bankAccount.create({
      data: {
        userId,
        bankCode: bankCode.toUpperCase(),
        accountNumberEnc,
        accountLast4,
        accountName: accountName.trim(),
        isDefault: shouldBeDefault,
      },
    });

    return {
      id: created.id,
      userId: created.userId,
      bankCode: created.bankCode,
      accountLast4: created.accountLast4,
      accountNumberMasked: maskAccountNumber(cleanAccountNumber),
      accountName: created.accountName,
      isDefault: created.isDefault,
      nameMatch,
      createdAt: created.createdAt,
      updatedAt: created.updatedAt,
    };
  });
};

/**
 * Retrieves all active bank accounts for a user with masked account numbers.
 *
 * @param {string} userId
 * @returns {Promise<Array>}
 */
const getBankAccounts = async (userId) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true },
  });

  if (!user) {
    throw new ApiError(404, 'Pengguna tidak ditemukan.');
  }

  const accounts = await prisma.bankAccount.findMany({
    where: { userId, deletedAt: null },
    orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
  });

  return accounts.map((acc) => {
    let plainNumber;
    try {
      plainNumber = decrypt(acc.accountNumberEnc);
    } catch {
      plainNumber = `••••••••${acc.accountLast4}`;
    }

    return {
      id: acc.id,
      userId: acc.userId,
      bankCode: acc.bankCode,
      accountLast4: acc.accountLast4,
      accountNumberMasked: maskAccountNumber(plainNumber),
      accountName: acc.accountName,
      isDefault: acc.isDefault,
      nameMatch: calculateNameMatch(user.name, acc.accountName),
      createdAt: acc.createdAt,
      updatedAt: acc.updatedAt,
    };
  });
};

/**
 * Soft deletes a bank account for a user.
 *
 * @param {string} id - Bank account ID
 * @param {string} userId - Requesting user ID
 * @returns {Promise<{ success: boolean, message: string }>}
 */
const deleteBankAccount = async (id, userId) => {
  const account = await prisma.bankAccount.findFirst({
    where: { id, userId, deletedAt: null },
  });

  if (!account) {
    throw new ApiError(404, 'Rekening bank tidak ditemukan.');
  }

  await prisma.$transaction(async (tx) => {
    await tx.bankAccount.update({
      where: { id },
      data: {
        deletedAt: new Date(),
        isDefault: false,
      },
    });

    // If deleted account was default, designate the next available active account
    if (account.isDefault) {
      const nextActive = await tx.bankAccount.findFirst({
        where: { userId, deletedAt: null },
        orderBy: { createdAt: 'desc' },
      });

      if (nextActive) {
        await tx.bankAccount.update({
          where: { id: nextActive.id },
          data: { isDefault: true },
        });
      }
    }
  });

  return { success: true, message: 'Rekening bank berhasil dihapus.' };
};

module.exports = {
  createBankAccount,
  getBankAccounts,
  deleteBankAccount,
};
