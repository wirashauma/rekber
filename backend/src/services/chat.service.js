// =============================================================================
// Chat Service - Realtime Messaging, Access Control & System Events
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { getIO, isUserInRoom } = require('../socket');
const { checkMessageRateLimit } = require('../middlewares/chatRateLimit.middleware');
const { logger } = require('../config/logger');

// Throttle map for push notifications: `${transactionId}:${recipientId}` -> timestamp (ms)
const notificationThrottleMap = new Map();
const NOTIFICATION_THROTTLE_MS = 5 * 60 * 1000; // 5 minutes

const TERMINAL_STATUSES = ['COMPLETED', 'CANCELLED', 'REFUNDED'];

/**
 * Checks and records notification throttle window (1 notification per 5 min per transaction).
 *
 * @param {string} transactionId
 * @param {string} recipientId
 * @returns {boolean} true if notification should be dispatched, false if throttled
 */
const shouldSendChatNotification = (transactionId, recipientId) => {
  const key = `${transactionId}:${recipientId}`;
  const now = Date.now();
  const lastSent = notificationThrottleMap.get(key) || 0;

  if (now - lastSent < NOTIFICATION_THROTTLE_MS) {
    return false;
  }

  notificationThrottleMap.set(key, now);
  return true;
};

/**
 * Clears notification throttle map (useful for tests).
 */
const clearNotificationThrottle = () => {
  notificationThrottleMap.clear();
};

/**
 * Verifies whether a user has permission to access the chat room of a transaction.
 *
 * Rules:
 * 1. Participants (buyer or seller) have access.
 * 2. Admin has access ONLY when transaction is in DISPUTED status.
 * 3. Terminal transactions (COMPLETED, CANCELLED, REFUNDED) can be read, but cannot receive new messages.
 *
 * @param {string} transactionId
 * @param {Object} user
 * @param {Object} [options]
 * @param {boolean} [options.checkTerminalForSend=false]
 * @returns {Promise<{ transaction: Object, isBuyer: boolean, isSeller: boolean, isAdmin: boolean }>}
 */
const verifyChatAccess = async (transactionId, user, { checkTerminalForSend = false } = {}) => {
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
    select: {
      id: true,
      code: true,
      amount: true,
      status: true,
      buyerId: true,
      sellerId: true,
      buyer: { select: { id: true, name: true, email: true } },
      seller: { select: { id: true, name: true, email: true } },
    },
  });

  if (!transaction) {
    throw new ApiError(404, 'Transaksi tidak ditemukan.');
  }

  const isBuyer = transaction.buyerId === user.id;
  const isSeller = transaction.sellerId === user.id;
  const isParticipant = isBuyer || isSeller;
  const isAdmin = user.role === 'ADMIN';

  if (!isParticipant && !isAdmin) {
    throw new ApiError(403, 'Anda tidak memiliki akses ke percakapan transaksi ini.');
  }

  // Admin access is strictly restricted to DISPUTED transactions only
  if (isAdmin && !isParticipant && transaction.status !== 'DISPUTED') {
    throw new ApiError(
      403,
      'Admin hanya dapat mengakses ruang percakapan saat transaksi dalam status sengketa (DISPUTED).'
    );
  }

  // Terminal status check for sending messages
  if (checkTerminalForSend && TERMINAL_STATUSES.includes(transaction.status)) {
    throw new ApiError(
      400,
      'Transaksi telah selesai atau dibatalkan. Tidak dapat mengirim pesan baru.'
    );
  }

  return {
    transaction,
    isBuyer,
    isSeller,
    isAdmin,
  };
};

/**
 * Retrieves chat messages for a transaction with cursor pagination.
 *
 * @param {string} transactionId
 * @param {Object} user
 * @param {Object} query
 * @param {number} [query.limit=20]
 * @param {string} [query.cursor]
 * @returns {Promise<{ messages: Array, nextCursor: string|null, hasMore: boolean }>}
 */
const getMessages = async (transactionId, user, { limit = 20, cursor }) => {
  await verifyChatAccess(transactionId, user, { checkTerminalForSend: false });

  const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

  const queryOptions = {
    where: {
      transactionId,
      deletedAt: null,
    },
    take: parsedLimit + 1,
    orderBy: { createdAt: 'desc' },
    include: {
      sender: {
        select: {
          id: true,
          name: true,
          role: true,
        },
      },
      file: {
        select: {
          id: true,
          mime: true,
          size: true,
          storageKey: true,
        },
      },
    },
  };

  if (cursor) {
    queryOptions.cursor = { id: cursor };
    queryOptions.skip = 1;
  }

  const items = await prisma.chatMessage.findMany(queryOptions);

  let nextCursor = null;
  let hasMore = false;

  if (items.length > parsedLimit) {
    hasMore = true;
    const extra = items.pop();
    nextCursor = extra.id;
  }

  return {
    messages: items,
    nextCursor,
    hasMore,
  };
};

/**
 * Sends a new chat message in a transaction.
 *
 * @param {string} transactionId
 * @param {Object} user
 * @param {Object} payload
 * @param {string} [payload.type='TEXT']
 * @param {string} [payload.body]
 * @param {string} [payload.fileId]
 * @returns {Promise<Object>}
 */
const sendMessage = async (transactionId, user, { type = 'TEXT', body, fileId }) => {
  const { transaction, isBuyer, isSeller, isAdmin } = await verifyChatAccess(transactionId, user, {
    checkTerminalForSend: true,
  });

  // Enforce message rate limit (20/min per user)
  if (!checkMessageRateLimit(user.id)) {
    throw new ApiError(
      429,
      'Batas pengiriman pesan tercapai (maksimal 20 pesan per menit). Silakan tunggu sejenak.'
    );
  }

  if (type === 'SYSTEM') {
    throw new ApiError(400, 'Tipe pesan SYSTEM hanya dapat dibuat oleh sistem.');
  }

  if (type === 'TEXT') {
    if (!body || !body.trim()) {
      throw new ApiError(422, 'Isi pesan teks tidak boleh kosong.');
    }
    if (body.length > 2000) {
      throw new ApiError(422, 'Isi pesan teks tidak boleh melebihi 2000 karakter.');
    }
    fileId = null;
  } else if (type === 'IMAGE') {
    if (!fileId) {
      throw new ApiError(422, 'fileId wajib disertakan untuk pesan bertipe IMAGE.');
    }

    const fileAsset = await prisma.fileAsset.findUnique({
      where: { id: fileId },
    });

    if (!fileAsset || fileAsset.deletedAt) {
      throw new ApiError(400, 'Berkas gambar tidak ditemukan.');
    }

    if (fileAsset.ownerId !== user.id) {
      throw new ApiError(403, 'Hanya pemilik berkas yang dapat melampirkan gambar ini.');
    }

    if (fileAsset.purpose !== 'CHAT_IMAGE') {
      throw new ApiError(400, 'Tujuan berkas harus CHAT_IMAGE.');
    }

    if (body && body.length > 2000) {
      throw new ApiError(422, 'Keterangan gambar tidak boleh melebihi 2000 karakter.');
    }
  } else {
    throw new ApiError(400, 'Tipe pesan tidak valid. Pilih antara TEXT atau IMAGE.');
  }

  const message = await prisma.chatMessage.create({
    data: {
      transactionId,
      senderId: user.id,
      type,
      body: body ? body.trim() : null,
      fileId: fileId || null,
    },
    include: {
      sender: {
        select: {
          id: true,
          name: true,
          role: true,
        },
      },
      file: {
        select: {
          id: true,
          mime: true,
          size: true,
          storageKey: true,
        },
      },
    },
  });

  // Automatically update sender's read state
  await markAsRead(transactionId, user.id, { broadcast: false });

  // Broadcast realtime event to room
  const io = getIO();
  if (io) {
    io.to(`tx:${transactionId}`).emit('message:new', message);
  }

  // Dispatch push notification to opponents if not currently in room (with 5 min throttle)
  const recipients = [];
  if (isBuyer) {
    recipients.push(transaction.sellerId);
  } else if (isSeller) {
    recipients.push(transaction.buyerId);
  } else if (isAdmin) {
    recipients.push(transaction.buyerId, transaction.sellerId);
  }

  const notificationService = require('./notification.service');
  for (const recipientId of recipients) {
    const isPresent = isUserInRoom(transactionId, recipientId);
    if (!isPresent && shouldSendChatNotification(transactionId, recipientId)) {
      const bodyPreview = type === 'IMAGE' ? (body ? `[Gambar] ${body}` : '[Gambar]') : body.trim();
      const snippet = bodyPreview.length > 100 ? `${bodyPreview.substring(0, 97)}...` : bodyPreview;

      notificationService
        .notify(recipientId, {
          type: 'CHAT_MESSAGE',
          title: `Pesan Baru: ${transaction.code}`,
          body: `${user.name}: ${snippet}`,
          data: {
            transactionId,
            messageId: message.id,
            type,
          },
        })
        .catch((err) => {
          logger.warn({ err: err.message, recipientId }, 'Gagal mengirim notifikasi chat push');
        });
    }
  }

  return message;
};

/**
 * Updates the lastReadAt timestamp for a user in a transaction and broadcasts event.
 *
 * @param {string} transactionId
 * @param {string} userId
 * @param {Object} [options]
 * @param {boolean} [options.broadcast=true]
 * @returns {Promise<Object>}
 */
const markAsRead = async (transactionId, userId, { broadcast = true } = {}) => {
  const readState = await prisma.chatReadState.upsert({
    where: {
      transactionId_userId: {
        transactionId,
        userId,
      },
    },
    update: {
      lastReadAt: new Date(),
    },
    create: {
      transactionId,
      userId,
      lastReadAt: new Date(),
    },
  });

  if (broadcast) {
    const io = getIO();
    if (io) {
      io.to(`tx:${transactionId}`).emit('message:read', {
        transactionId,
        userId,
        lastReadAt: readState.lastReadAt,
      });
    }
  }

  return readState;
};

/**
 * Creates and broadcasts an automatic SYSTEM message on status changes.
 *
 * @param {string} transactionId
 * @param {string} text
 * @returns {Promise<Object>}
 */
const postSystem = async (transactionId, text) => {
  try {
    const message = await prisma.chatMessage.create({
      data: {
        transactionId,
        senderId: null,
        type: 'SYSTEM',
        body: text,
      },
      include: {
        sender: true,
        file: true,
      },
    });

    const io = getIO();
    if (io) {
      io.to(`tx:${transactionId}`).emit('message:new', message);
    }

    return message;
  } catch (err) {
    logger.warn(
      { err: err.message, transactionId },
      'Gagal membuat pesan SYSTEM otomatis ke ruang chat'
    );
    return null;
  }
};

module.exports = {
  verifyChatAccess,
  getMessages,
  sendMessage,
  markAsRead,
  postSystem,
  shouldSendChatNotification,
  clearNotificationThrottle,
};
