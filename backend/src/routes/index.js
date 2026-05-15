// =============================================================================
// Route Index - Central Route Registry
// =============================================================================
// Aggregates all route modules and mounts them under their base paths.
// This keeps app.js clean and makes it easy to add new route groups.

const express = require('express');
const router = express.Router();

const authRoutes = require('./auth.routes');
const transactionRoutes = require('./transaction.routes');

// Mount route groups
router.use('/auth', authRoutes);               // /api/auth/*
router.use('/transactions', transactionRoutes); // /api/transactions/*

module.exports = router;
