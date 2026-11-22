// =============================================================================
// Prometheus Metrics Service (Prompt 20)
// =============================================================================
// Exposes operational and business metrics formatted for Prometheus scrapers:
// - rekber_transactions_total (by status)
// - rekber_topups_total (by status)
// - rekber_withdrawals_total (by status)
// - rekber_disputes_total (by status)
// - rekber_job_failures_total (by job)
// - rekber_reconcile_discrepancies (gauge)
// - Node.js process health (uptime, memory)

const prisma = require('../config/prisma');

// In-memory counters for worker failures and reconciliation gauge
const jobFailures = new Map();
let reconcileDiscrepanciesCount = 0;

/**
 * Increment failure counter for a background job.
 * @param {string} jobName
 */
const incrementJobFailure = (jobName) => {
  const current = jobFailures.get(jobName) || 0;
  jobFailures.set(jobName, current + 1);
};

/**
 * Record discrepancy count from the most recent reconciliation run.
 * @param {number} count
 */
const recordReconcileDiscrepancies = (count) => {
  reconcileDiscrepanciesCount = count;
};

/**
 * Generate Prometheus text exposition format (version 0.0.4)
 * @returns {Promise<string>}
 */
const getMetricsData = async () => {
  let txStats = [];
  let topupStats = [];
  let withdrawStats = [];
  let disputeStats = [];

  try {
    [txStats, topupStats, withdrawStats, disputeStats] = await Promise.all([
      prisma.transaction.groupBy({ by: ['status'], _count: { id: true } }),
      prisma.topUpIntent.groupBy({ by: ['status'], _count: { id: true } }),
      prisma.withdrawal.groupBy({ by: ['status'], _count: { id: true } }),
      prisma.dispute.groupBy({ by: ['status'], _count: { id: true } }),
    ]);
  } catch {
    // If DB is temporarily unreachable, proceed with in-memory metrics
  }

  const lines = [];

  // 1. Transactions Total
  lines.push('# HELP rekber_transactions_total Total transactions grouped by status');
  lines.push('# TYPE rekber_transactions_total counter');
  if (txStats.length === 0) {
    lines.push('rekber_transactions_total{status="TOTAL"} 0');
  } else {
    for (const item of txStats) {
      lines.push(`rekber_transactions_total{status="${item.status}"} ${item._count.id}`);
    }
  }

  // 2. Topups Total
  lines.push('# HELP rekber_topups_total Total topups grouped by status');
  lines.push('# TYPE rekber_topups_total counter');
  if (topupStats.length === 0) {
    lines.push('rekber_topups_total{status="TOTAL"} 0');
  } else {
    for (const item of topupStats) {
      lines.push(`rekber_topups_total{status="${item.status}"} ${item._count.id}`);
    }
  }

  // 3. Withdrawals Total
  lines.push('# HELP rekber_withdrawals_total Total withdrawals grouped by status');
  lines.push('# TYPE rekber_withdrawals_total counter');
  if (withdrawStats.length === 0) {
    lines.push('rekber_withdrawals_total{status="TOTAL"} 0');
  } else {
    for (const item of withdrawStats) {
      lines.push(`rekber_withdrawals_total{status="${item.status}"} ${item._count.id}`);
    }
  }

  // 4. Disputes Total
  lines.push('# HELP rekber_disputes_total Total disputes grouped by status');
  lines.push('# TYPE rekber_disputes_total counter');
  if (disputeStats.length === 0) {
    lines.push('rekber_disputes_total{status="TOTAL"} 0');
  } else {
    for (const item of disputeStats) {
      lines.push(`rekber_disputes_total{status="${item.status}"} ${item._count.id}`);
    }
  }

  // 5. Job Failures Total
  lines.push('# HELP rekber_job_failures_total Total background worker job failures');
  lines.push('# TYPE rekber_job_failures_total counter');
  if (jobFailures.size === 0) {
    lines.push('rekber_job_failures_total 0');
  } else {
    for (const [job, count] of jobFailures.entries()) {
      lines.push(`rekber_job_failures_total{job="${job}"} ${count}`);
    }
  }

  // 6. Reconciliation Discrepancies
  lines.push('# HELP rekber_reconcile_discrepancies Current ledger reconciliation discrepancy count');
  lines.push('# TYPE rekber_reconcile_discrepancies gauge');
  lines.push(`rekber_reconcile_discrepancies ${reconcileDiscrepanciesCount}`);

  // 7. System & Process Metrics
  lines.push('# HELP process_uptime_seconds Process uptime in seconds');
  lines.push('# TYPE process_uptime_seconds gauge');
  lines.push(`process_uptime_seconds ${Math.floor(process.uptime())}`);

  const mem = process.memoryUsage();
  lines.push('# HELP process_resident_memory_bytes Resident memory size in bytes');
  lines.push('# TYPE process_resident_memory_bytes gauge');
  lines.push(`process_resident_memory_bytes ${mem.rss}`);

  lines.push('# HELP nodejs_heap_size_used_bytes Process heap memory used in bytes');
  lines.push('# TYPE nodejs_heap_size_used_bytes gauge');
  lines.push(`nodejs_heap_size_used_bytes ${mem.heapUsed}`);

  lines.push('');
  return lines.join('\n');
};

module.exports = {
  incrementJobFailure,
  recordReconcileDiscrepancies,
  getMetricsData,
};
