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

module.exports = router;
