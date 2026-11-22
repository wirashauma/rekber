// =============================================================================
// Prometheus Metrics Route (Prompt 20)
// =============================================================================
// Serves prometheus-formatted metrics at /metrics and /api/metrics.
// Protected by token verification via X-Metrics-Token header or Bearer token.

const express = require('express');
const router = express.Router();
const { getMetricsData } = require('../services/metrics.service');

router.get('/', async (req, res) => {
  const configuredToken = process.env.METRICS_TOKEN || 'rekber-metrics-token-secret';

  const authHeader = req.headers.authorization;
  const bearerToken =
    authHeader && authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  const customHeaderToken = req.headers['x-metrics-token'];

  const providedToken = customHeaderToken || bearerToken;

  if (!providedToken || providedToken !== configuredToken) {
    return res.status(401).json({
      success: false,
      code: 'UNAUTHORIZED',
      message: 'Akses metrik ditolak. Token metrik tidak valid.',
    });
  }

  try {
    const metrics = await getMetricsData();
    res.setHeader('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    return res.status(200).send(metrics);
  } catch {
    return res.status(500).json({
      success: false,
      code: 'METRICS_ERROR',
      message: 'Gagal menghasilkan metrik sistem.',
    });
  }
});

module.exports = router;
