// =============================================================================
// Admin Audit Log Controller
// =============================================================================

const auditService = require('../services/audit.service');

const getAuditLogs = async (req, res, next) => {
  try {
    const result = await auditService.getAuditLogs(req.query);

    res.status(200).json({
      success: true,
      data: result.logs,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getAuditLogs,
};
