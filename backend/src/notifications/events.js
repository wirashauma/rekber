// =============================================================================
// Notification Events - Central Indonesian Notification Text & Triggers
// =============================================================================

const notificationService = require('../services/notification.service');
const chatService = require('../services/chat.service');
const { logger } = require('../config/logger');

const NOTIFICATION_TYPES = {
  TRANSACTION_CREATED: 'TRANSACTION_CREATED',
  TRANSACTION_PAID: 'TRANSACTION_PAID',
  TRANSACTION_SHIPPED: 'TRANSACTION_SHIPPED',
  TRANSACTION_COMPLETED: 'TRANSACTION_COMPLETED',
  TRANSACTION_REFUNDED: 'TRANSACTION_REFUNDED',
  TRANSACTION_DISPUTED: 'TRANSACTION_DISPUTED',
  DISPUTE_RESOLVED: 'DISPUTE_RESOLVED',
  TOPUP_PAID: 'TOPUP_PAID',
  WITHDRAWAL_STATUS_CHANGED: 'WITHDRAWAL_STATUS_CHANGED',
  AUTO_RELEASE_REMINDER: 'AUTO_RELEASE_REMINDER',
};

/**
 * Safely dispatches a notification event. Errors are logged and suppressed.
 */
const safeNotify = async (userId, payload) => {
  try {
    return await notificationService.notify(userId, payload);
  } catch (err) {
    logger.warn(
      { err: err.message, userId, type: payload.type },
      'Gagal mendistribusikan event notifikasi'
    );
    return null;
  }
};

/**
 * Event: Transaksi dibuat. Dikirim ke pihak lawan.
 */
const onTransactionCreated = async (transaction, creatorUserId) => {
  const recipientId =
    creatorUserId === transaction.buyerId ? transaction.sellerId : transaction.buyerId;

  await chatService.postSystem(
    transaction.id,
    'Transaksi dibuat. Menunggu pembayaran dari pembeli.'
  );

  return await safeNotify(recipientId, {
    type: NOTIFICATION_TYPES.TRANSACTION_CREATED,
    title: 'Transaksi Baru Dibuat',
    body: `Transaksi ${transaction.code} senilai Rp ${Number(transaction.amount).toLocaleString('id-ID')} telah dibuat.`,
    data: {
      transactionId: transaction.id,
      code: transaction.code,
    },
  });
};

/**
 * Event: Transaksi dibayar (PAID). Dikirim ke penjual.
 */
const onTransactionPaid = async (transaction) => {
  await chatService.postSystem(
    transaction.id,
    'Pembayaran telah diverifikasi dan dana ditahan di rekening bersama (escrow).'
  );

  return await safeNotify(transaction.sellerId, {
    type: NOTIFICATION_TYPES.TRANSACTION_PAID,
    title: 'Pembayaran Diterima',
    body: `Pembeli telah membayar transaksi ${transaction.code}. Silakan siapkan dan kirimkan barang.`,
    data: {
      transactionId: transaction.id,
      code: transaction.code,
    },
  });
};

/**
 * Event: Transaksi dikirim (SHIPPED). Dikirim ke pembeli.
 */
const onTransactionShipped = async (transaction, shipmentProof = null) => {
  const trackingInfo = shipmentProof?.trackingNumber
    ? ` dengan nomor resi ${shipmentProof.trackingNumber}`
    : '';

  await chatService.postSystem(
    transaction.id,
    `Pesanan telah dikirim oleh penjual${trackingInfo}.`
  );

  return await safeNotify(transaction.buyerId, {
    type: NOTIFICATION_TYPES.TRANSACTION_SHIPPED,
    title: 'Pesanan Telah Dikirim',
    body: `Penjual telah mengirimkan pesanan ${transaction.code}${trackingInfo}.`,
    data: {
      transactionId: transaction.id,
      code: transaction.code,
      courier: shipmentProof?.courier || '',
      trackingNumber: shipmentProof?.trackingNumber || '',
    },
  });
};

/**
 * Event: Transaksi selesai (COMPLETED). Dikirim ke penjual (dana masuk).
 */
const onTransactionCompleted = async (transaction) => {
  const netAmount = Number(transaction.amount - transaction.sellerFee).toLocaleString('id-ID');

  await chatService.postSystem(
    transaction.id,
    'Transaksi telah selesai. Dana telah diteruskan ke saldo penjual.'
  );

  return await safeNotify(transaction.sellerId, {
    type: NOTIFICATION_TYPES.TRANSACTION_COMPLETED,
    title: 'Transaksi Selesai & Dana Masuk',
    body: `Transaksi ${transaction.code} telah selesai. Saldo sebesar Rp ${netAmount} telah masuk ke dompet Anda.`,
    data: {
      transactionId: transaction.id,
      code: transaction.code,
      netAmount,
    },
  });
};

/**
 * Event: Transaksi direfund (REFUNDED). Dikirim ke pembeli.
 */
const onTransactionRefunded = async (transaction) => {
  const refundAmount = Number(transaction.amount + transaction.buyerFee).toLocaleString('id-ID');

  await chatService.postSystem(
    transaction.id,
    'Transaksi telah dibatalkan/direfund. Dana telah dikembalikan ke saldo pembeli.'
  );

  return await safeNotify(transaction.buyerId, {
    type: NOTIFICATION_TYPES.TRANSACTION_REFUNDED,
    title: 'Pengembalian Dana Transaksi',
    body: `Transaksi ${transaction.code} telah dibatalkan/direfund. Saldo sebesar Rp ${refundAmount} telah dikembalikan ke dompet Anda.`,
    data: {
      transactionId: transaction.id,
      code: transaction.code,
      refundAmount,
    },
  });
};

/**
 * Event: Sengketa diajukan (DISPUTED). Dikirim ke penjual.
 */
const onTransactionDisputed = async (transaction, dispute) => {
  await chatService.postSystem(
    transaction.id,
    `Sengketa telah diajukan oleh pembeli (${dispute.reason}). Transaksi ditahan untuk peninjauan admin.`
  );

  return await safeNotify(transaction.sellerId, {
    type: NOTIFICATION_TYPES.TRANSACTION_DISPUTED,
    title: 'Sengketa Diajukan Pembeli',
    body: `Pembeli mengajukan sengketa pada transaksi ${transaction.code}. Alasan: ${dispute.reason}.`,
    data: {
      transactionId: transaction.id,
      disputeId: dispute.id,
      code: transaction.code,
    },
  });
};

/**
 * Event: Sengketa diputuskan admin (RESOLVED). Dikirim ke kedua pihak (pembeli & penjual).
 */
const onDisputeResolved = async (transaction, dispute, decision) => {
  const decisionText =
    decision === 'RELEASE_TO_SELLER'
      ? 'Dana escrow diteruskan ke penjual.'
      : 'Dana escrow dikembalikan penuh ke pembeli.';

  await chatService.postSystem(
    transaction.id,
    `Sengketa telah diputuskan oleh admin: ${decisionText}`
  );

  const payload = {
    type: NOTIFICATION_TYPES.DISPUTE_RESOLVED,
    title: 'Sengketa Telah Diputuskan',
    body: `Sengketa transaksi ${transaction.code} telah diselesaikan oleh admin. ${decisionText}`,
    data: {
      transactionId: transaction.id,
      disputeId: dispute.id,
      code: transaction.code,
      decision,
    },
  };

  // Notifikasi ke kedua belah pihak secara paralel
  await Promise.all([
    safeNotify(transaction.buyerId, payload),
    safeNotify(transaction.sellerId, payload),
  ]);
};

/**
 * Event: Top-up diverifikasi & berhasil (PAID). Dikirim ke user.
 */
const onTopUpPaid = async (paymentIntent) => {
  const amountStr = Number(paymentIntent.amount).toLocaleString('id-ID');

  return await safeNotify(paymentIntent.userId, {
    type: NOTIFICATION_TYPES.TOPUP_PAID,
    title: 'Top-Up Saldo Berhasil',
    body: `Top-up saldo sebesar Rp ${amountStr} telah berhasil diverifikasi dan ditambahkan ke dompet Anda.`,
    data: {
      paymentIntentId: paymentIntent.id,
      amount: paymentIntent.amount.toString(),
    },
  });
};

/**
 * Event: Perubahan status penarikan dana. Dikirim ke user.
 */
const onWithdrawalStatusChanged = async (withdrawal) => {
  const amountStr = Number(withdrawal.amount).toLocaleString('id-ID');

  return await safeNotify(withdrawal.userId, {
    type: NOTIFICATION_TYPES.WITHDRAWAL_STATUS_CHANGED,
    title: `Status Penarikan: ${withdrawal.status}`,
    body: `Permintaan penarikan dana sebesar Rp ${amountStr} kini berstatus ${withdrawal.status}.`,
    data: {
      withdrawalId: withdrawal.id,
      status: withdrawal.status,
    },
  });
};

/**
 * Event: Pengingat auto-release (24 jam sebelum jatuh tempo). Dikirim ke pembeli.
 */
const onAutoReleaseReminder = async (transaction) => {
  return await safeNotify(transaction.buyerId, {
    type: NOTIFICATION_TYPES.AUTO_RELEASE_REMINDER,
    title: 'Pengingat Konfirmasi Penerimaan',
    body: `Transaksi ${transaction.code} akan otomatis selesai dalam 24 jam bila tidak ada konfirmasi penerimaan atau sengketa.`,
    data: {
      transactionId: transaction.id,
      code: transaction.code,
    },
  });
};

module.exports = {
  NOTIFICATION_TYPES,
  onTransactionCreated,
  onTransactionPaid,
  onTransactionShipped,
  onTransactionCompleted,
  onTransactionRefunded,
  onTransactionDisputed,
  onDisputeResolved,
  onTopUpPaid,
  onWithdrawalStatusChanged,
  onAutoReleaseReminder,
};
