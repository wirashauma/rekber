// =============================================================================
// Route Index - Central Route Registry
// =============================================================================
// Aggregates all route modules and mounts them under their base paths.
// This keeps app.js clean and makes it easy to add new route groups.

const express = require('express');
const router = express.Router();

const authRoutes = require('./auth.routes');
const transactionRoutes = require('./transaction.routes');
const walletRoutes = require('./wallet.routes');
const configRoutes = require('./config.routes');
const bankAccountRoutes = require('./bankAccount.routes');
const adminWithdrawalRoutes = require('./admin.withdrawal.routes');
const fileRoutes = require('./file.routes');
const disputeRoutes = require('./dispute.routes');
const adminDisputeRoutes = require('./admin.dispute.routes');
const notificationRoutes = require('./notification.routes');
const kycRoutes = require('./kyc.routes');
const adminKycRoutes = require('./admin.kyc.routes');
const adminMetricRoutes = require('./admin.metric.routes');
const adminUserRoutes = require('./admin.user.routes');
const adminSettingRoutes = require('./admin.setting.routes');
const adminTransactionRoutes = require('./admin.transaction.routes');
const adminAuditRoutes = require('./admin.audit.routes');

// Mount route groups
router.use('/auth', authRoutes); // /api/auth/*
router.use('/transactions', transactionRoutes); // /api/transactions/*
router.use('/wallet', walletRoutes); // /api/wallet/*
router.use('/config', configRoutes); // /api/config/*
router.use('/bank-accounts', bankAccountRoutes); // /api/bank-accounts/*
router.use('/admin/withdrawals', adminWithdrawalRoutes); // /api/admin/withdrawals/*
router.use('/files', fileRoutes); // /api/files/*
router.use('/disputes', disputeRoutes); // /api/disputes/*
router.use('/admin/disputes', adminDisputeRoutes); // /api/admin/disputes/*
router.use('/notifications', notificationRoutes); // /api/notifications/*
router.use('/kyc', kycRoutes); // /api/kyc/*
router.use('/admin/kyc', adminKycRoutes); // /api/admin/kyc/*
router.use('/admin/metrics', adminMetricRoutes); // /api/admin/metrics/*
router.use('/admin/users', adminUserRoutes); // /api/admin/users/*
router.use('/admin/settings', adminSettingRoutes); // /api/admin/settings/*
router.use('/admin/transactions', adminTransactionRoutes); // /api/admin/transactions/*
router.use('/admin/audit-logs', adminAuditRoutes); // /api/admin/audit-logs/*

module.exports = router;
