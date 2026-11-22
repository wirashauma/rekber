// =============================================================================
// Chat Controller - Request Handlers for Chat Endpoints
// =============================================================================

const chatService = require('../services/chat.service');

/**
 * GET /transactions/:id/messages
 * Retrieves paginated messages for a transaction.
 */
const getMessages = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { limit, cursor } = req.query;

    const result = await chatService.getMessages(id, req.user, { limit, cursor });

    res.status(200).json({
      success: true,
      ...result,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /transactions/:id/messages
 * Sends a new message in a transaction.
 */
const sendMessage = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { type, body, fileId } = req.body;

    const message = await chatService.sendMessage(id, req.user, {
      type,
      body,
      fileId,
    });

    res.status(201).json({
      success: true,
      message: 'Pesan berhasil dikirim.',
      data: message,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /transactions/:id/messages/read
 * Marks transaction messages as read for the authenticated user.
 */
const markAsRead = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user has access to read the transaction chat
    await chatService.verifyChatAccess(id, req.user, { checkTerminalForSend: false });

    const readState = await chatService.markAsRead(id, req.user.id);

    res.status(200).json({
      success: true,
      message: 'Pesan telah ditandai telah dibaca.',
      data: readState,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getMessages,
  sendMessage,
  markAsRead,
};
