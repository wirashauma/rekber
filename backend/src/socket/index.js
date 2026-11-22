// =============================================================================
// Socket.IO Server & Realtime Chat Handler
// =============================================================================

const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const config = require('../config');
const prisma = require('../config/prisma');
const { logger } = require('../config/logger');

let io = null;

// Map for tracking typing throttle: `${socketId}:${transactionId}` -> lastTimestamp
const typingThrottleMap = new Map();
const TYPING_THROTTLE_MS = 1500;

/**
 * Socket.IO handshake authentication middleware.
 * Verifies JWT access token and user active status.
 */
const socketAuthMiddleware = async (socket, next) => {
  try {
    const rawToken =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace(/^Bearer\s+/i, '');

    if (!rawToken) {
      return next(new Error('Authentication error: Token tidak disertakan.'));
    }

    let decoded;
    try {
      decoded = jwt.verify(rawToken, config.jwt.secret);
    } catch {
      return next(new Error('Authentication error: Token tidak valid atau kedaluwarsa.'));
    }

    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        isActive: true,
      },
    });

    if (!user || !user.isActive) {
      return next(new Error('Authentication error: Akun tidak ditemukan atau tidak aktif.'));
    }

    socket.user = user;
    next();
  } catch (err) {
    logger.warn({ err: err.message }, 'Socket.IO handshake authentication failed');
    next(new Error('Authentication error: Terjadi kesalahan autentikasi.'));
  }
};

/**
 * Initialize Socket.IO with HTTP Server.
 *
 * @param {import('http').Server} httpServer
 * @param {Object} [options]
 * @returns {Server}
 */
const initSocket = (httpServer, options = {}) => {
  if (io) {
    return io;
  }

  io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    ...options,
  });

  io.use(socketAuthMiddleware);

  io.on('connection', (socket) => {
    logger.debug({ socketId: socket.id, userId: socket.user.id }, 'Socket client connected');

    // Join transaction chat room: tx:{id}
    socket.on('join', async (data, callback) => {
      try {
        const transactionId = data?.transactionId || data?.txId;
        if (!transactionId) {
          const errRes = { success: false, message: 'transactionId wajib disertakan.' };
          if (typeof callback === 'function') callback(errRes);
          return socket.emit('error', errRes);
        }

        const chatService = require('../services/chat.service');
        const { transaction } = await chatService.verifyChatAccess(transactionId, socket.user);

        const roomName = `tx:${transactionId}`;
        socket.join(roomName);

        const res = {
          success: true,
          room: roomName,
          transactionId: transaction.id,
          code: transaction.code,
        };

        if (typeof callback === 'function') callback(res);
        socket.emit('joined', res);
        logger.debug(
          { socketId: socket.id, userId: socket.user.id, room: roomName },
          'User joined chat room'
        );
      } catch (err) {
        const errRes = {
          success: false,
          message: err.message || 'Gagal bergabung ke ruang percakapan.',
          statusCode: err.statusCode || 403,
        };
        if (typeof callback === 'function') callback(errRes);
        socket.emit('error', errRes);
      }
    });

    // Leave transaction chat room
    socket.on('leave', (data) => {
      const transactionId = data?.transactionId || data?.txId;
      if (transactionId) {
        socket.leave(`tx:${transactionId}`);
      }
    });

    // Typing event with throttling (relay to opponents in room)
    socket.on('typing', (data) => {
      try {
        const transactionId = data?.transactionId || data?.txId;
        if (!transactionId) return;

        const isTyping = Boolean(data?.isTyping);
        const roomName = `tx:${transactionId}`;

        // Verify socket is inside the room
        if (!socket.rooms.has(roomName)) return;

        const throttleKey = `${socket.id}:${transactionId}`;
        const now = Date.now();
        const lastSent = typingThrottleMap.get(throttleKey) || 0;

        // Allow sending when stopping typing (isTyping = false) or after throttle interval
        if (isTyping && now - lastSent < TYPING_THROTTLE_MS) {
          return;
        }

        typingThrottleMap.set(throttleKey, now);

        // Broadcast to all other sockets in room
        socket.to(roomName).emit('typing', {
          transactionId,
          userId: socket.user.id,
          name: socket.user.name,
          isTyping,
        });
      } catch (err) {
        logger.warn({ err: err.message }, 'Gagal memproses event typing socket');
      }
    });

    // Send message via socket
    socket.on('message:send', async (data, callback) => {
      try {
        const transactionId = data?.transactionId || data?.txId;
        const chatService = require('../services/chat.service');

        const message = await chatService.sendMessage(transactionId, socket.user, {
          type: data?.type || 'TEXT',
          body: data?.body,
          fileId: data?.fileId,
        });

        if (typeof callback === 'function') {
          callback({ success: true, message });
        }
      } catch (err) {
        const errRes = {
          success: false,
          message: err.message || 'Gagal mengirim pesan',
          statusCode: err.statusCode || 400,
        };
        if (typeof callback === 'function') callback(errRes);
        socket.emit('error', errRes);
      }
    });

    // Mark as read via socket
    socket.on('message:read', async (data, callback) => {
      try {
        const transactionId = data?.transactionId || data?.txId;
        const chatService = require('../services/chat.service');

        const result = await chatService.markAsRead(transactionId, socket.user.id);

        if (typeof callback === 'function') {
          callback({ success: true, ...result });
        }
      } catch (err) {
        const errRes = {
          success: false,
          message: err.message || 'Gagal memperbarui status baca',
          statusCode: err.statusCode || 400,
        };
        if (typeof callback === 'function') callback(errRes);
        socket.emit('error', errRes);
      }
    });

    socket.on('disconnect', () => {
      // Clean up typing throttle records for this socket
      for (const key of typingThrottleMap.keys()) {
        if (key.startsWith(`${socket.id}:`)) {
          typingThrottleMap.delete(key);
        }
      }
    });
  });

  return io;
};

/**
 * Returns current Socket.IO instance or null.
 *
 * @returns {Server|null}
 */
const getIO = () => io;

/**
 * Checks whether a specific user has an active socket connection inside room tx:{transactionId}.
 *
 * @param {string} transactionId
 * @param {string} userId
 * @returns {boolean}
 */
const isUserInRoom = (transactionId, userId) => {
  if (!io) return false;
  const roomName = `tx:${transactionId}`;
  const room = io.sockets.adapter.rooms.get(roomName);
  if (!room || room.size === 0) return false;

  for (const socketId of room) {
    const s = io.sockets.sockets.get(socketId);
    if (s && s.user && s.user.id === userId) {
      return true;
    }
  }

  return false;
};

/**
 * Closes the Socket.IO server. Useful for teardown in tests.
 */
const closeSocket = async () => {
  if (io) {
    await new Promise((resolve) => {
      io.close(() => {
        io = null;
        resolve();
      });
    });
  }
};

module.exports = {
  initSocket,
  getIO,
  isUserInRoom,
  closeSocket,
};
