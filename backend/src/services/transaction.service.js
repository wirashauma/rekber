// =============================================================================
// Transaction Service (Facade for Escrow Service)
// =============================================================================

const escrowService = require('./escrow.service');
const { VALID_TRANSITIONS, TRANSITION_ROLES } = require('../constants/transaction');

module.exports = {
  createTransaction: escrowService.createTransaction,
  getTransactionById: escrowService.getTransactionById,
  getTransactionByCode: escrowService.getTransactionByCode,
  submitShipmentProof: escrowService.submitShipmentProof,
  updateTransactionStatus: (transactionId, newStatus, userId, userRole, reason) =>
    escrowService.executeTransition(
      transactionId,
      newStatus,
      { id: userId, role: userRole },
      reason
    ),
  getTransactions: escrowService.getTransactions,
  VALID_TRANSITIONS,
  TRANSITION_AUTHORITY: TRANSITION_ROLES,
};
