const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth.middleware');
const prisma = require('../config/prisma');

// POST /api/wallet/topup
router.post('/topup', authenticate, async (req, res, next) => {
  try {
    const { amount } = req.body;
    const nominal = parseFloat(amount);
    if (isNaN(nominal) || nominal <= 0) {
      return res.status(400).json({ success: false, message: 'Nominal top up tidak valid.' });
    }

    const updatedUser = await prisma.user.update({
      where: { id: req.user.id },
      data: { balance: { increment: nominal } },
    });

    res.status(200).json({
      success: true,
      message: 'Top up berhasil!',
      data: { balance: updatedUser.balance },
    });
  } catch (error) {
    next(error);
  }
});

// POST /api/wallet/withdraw
router.post('/withdraw', authenticate, async (req, res, next) => {
  try {
    const { amount } = req.body;
    const nominal = parseFloat(amount);
    if (isNaN(nominal) || nominal <= 0) {
      return res.status(400).json({ success: false, message: 'Nominal penarikan tidak valid.' });
    }

    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan.' });
    }

    if (user.balance < nominal) {
      return res.status(400).json({ success: false, message: 'Saldo tidak mencukupi untuk penarikan.' });
    }

    const updatedUser = await prisma.user.update({
      where: { id: req.user.id },
      data: { balance: { decrement: nominal } },
    });

    res.status(200).json({
      success: true,
      message: 'Penarikan berhasil!',
      data: { balance: updatedUser.balance },
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
