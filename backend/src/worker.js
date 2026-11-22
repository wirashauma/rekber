// =============================================================================
// Background Worker & Cron Scheduler (Prompt 12)
// =============================================================================
// Runs isolated background jobs with PostgreSQL advisory locks to guarantee
// exactly-once execution across multiple clustered backend/worker instances.

require('./utils/money');
const cron = require('node-cron');
const prisma = require('./config/prisma');
const { logger } = require('./config/logger');
const { releaseEscrow, cancelPending } = require('./services/escrow.service');
const { expireStaleIntents } = require('./services/topup.service');
const { cleanupOrphanFiles } = require('./services/file.service');
const { reconcile } = require('./services/reconcile.service');
const events = require('./notifications/events');
const metricsService = require('./services/metrics.service');

/**
 * 32-bit unique integers for PostgreSQL advisory locks per job
 */
const JOB_LOCKS = {
  AUTO_RELEASE: 777001,
  EXPIRE_PENDING: 777002,
  REMINDER: 777003,
  EXPIRE_STALE_INTENTS: 777004,
  CLEANUP_ORPHAN_FILES: 777005,
  RECONCILE_DAILY: 777006,
};

/**
 * Executes a job wrapped inside a PostgreSQL session advisory lock.
 * If another instance is running the job, pg_try_advisory_lock returns false
 * and the job is cleanly skipped without error.
 *
 * @param {number} lockId
 * @param {string} jobName
 * @param {Function} jobFn
 * @returns {Promise<{ skipped: boolean, result?: any, reason?: string }>}
 */
const withAdvisoryLock = async (lockId, jobName, jobFn) => {
  let acquired;
  try {
    const rawResult = await prisma.$queryRawUnsafe(
      `SELECT pg_try_advisory_lock(${lockId}) as locked;`
    );
    acquired = rawResult[0]?.locked === true;
  } catch (err) {
    logger.warn({ job: jobName, error: err.message }, 'Gagal memeriksa advisory lock');
    return { skipped: true, reason: 'LOCK_CHECK_ERROR' };
  }

  if (!acquired) {
    logger.info({ job: jobName }, 'Job dilewati: Sedang dikerjakan oleh worker lain.');
    return { skipped: true, reason: 'LOCK_HELD_BY_ANOTHER_INSTANCE' };
  }

  try {
    const result = await jobFn();
    return { skipped: false, result };
  } catch (err) {
    logger.error({ job: jobName, error: err.message }, 'Terjadi kesalahan saat mengeksekusi job');
    metricsService.incrementJobFailure(jobName);
    throw err;
  } finally {
    try {
      await prisma.$queryRawUnsafe(`SELECT pg_advisory_unlock(${lockId});`);
    } catch (unlockErr) {
      logger.warn(
        { job: jobName, error: unlockErr.message },
        'Gagal melepaskan pg_advisory_unlock'
      );
    }
  }
};

/**
 * Job (a): Auto-release SHIPPED transactions when autoReleaseAt has elapsed.
 * Batched to 50 items. Strictly ignores DISPUTED transactions.
 */
const runAutoRelease = async () => {
  const transactions = await prisma.transaction.findMany({
    where: {
      status: 'SHIPPED',
      autoReleaseAt: { lte: new Date() },
    },
    take: 50,
    orderBy: { autoReleaseAt: 'asc' },
  });

  let processed = 0;
  let failed = 0;

  for (const tx of transactions) {
    try {
      const updated = await prisma.$transaction(async (dbTx) => {
        return await releaseEscrow(dbTx, tx.id, 'SYSTEM');
      });

      await events.onTransactionCompleted(updated);
      processed += 1;
    } catch (err) {
      failed += 1;
      logger.warn({ txId: tx.id, error: err.message }, 'Gagal mengeksekusi auto-release transaksi');
    }
  }

  logger.info(
    { job: 'autoRelease', total: transactions.length, processed, failed },
    'autoRelease selesai'
  );
  return { total: transactions.length, processed, failed };
};

/**
 * Job (b): Cancel expired PENDING transactions when expiresAt has passed.
 */
const runExpirePending = async () => {
  const transactions = await prisma.transaction.findMany({
    where: {
      status: 'PENDING',
      expiresAt: { lte: new Date() },
    },
    take: 50,
    orderBy: { expiresAt: 'asc' },
  });

  let processed = 0;
  let failed = 0;

  for (const tx of transactions) {
    try {
      await prisma.$transaction(async (dbTx) => {
        await cancelPending(dbTx, tx.id, 'SYSTEM', 'EXPIRED');
      });
      processed += 1;
    } catch (err) {
      failed += 1;
      logger.warn(
        { txId: tx.id, error: err.message },
        'Gagal membatalkan transaksi pending kedaluwarsa'
      );
    }
  }

  logger.info(
    { job: 'expirePending', total: transactions.length, processed, failed },
    'expirePending selesai'
  );
  return { total: transactions.length, processed, failed };
};

/**
 * Job (c): Send auto-release reminder to buyer 24 hours before autoReleaseAt.
 * Uses atomic CAS on reminderSentAt to guarantee exactly-once delivery.
 */
const runReminder = async () => {
  const in24Hours = new Date(Date.now() + 24 * 60 * 60 * 1000);

  const candidates = await prisma.transaction.findMany({
    where: {
      status: 'SHIPPED',
      autoReleaseAt: {
        lte: in24Hours,
        gt: new Date(),
      },
      reminderSentAt: null,
    },
    take: 50,
  });

  let processed = 0;
  let failed = 0;

  for (const tx of candidates) {
    try {
      const updateResult = await prisma.transaction.updateMany({
        where: {
          id: tx.id,
          status: 'SHIPPED',
          reminderSentAt: null,
        },
        data: {
          reminderSentAt: new Date(),
        },
      });

      if (updateResult.count === 1) {
        await events.onAutoReleaseReminder(tx);
        processed += 1;
      }
    } catch (err) {
      failed += 1;
      logger.warn({ txId: tx.id, error: err.message }, 'Gagal mengirimkan pengingat auto-release');
    }
  }

  logger.info({ job: 'reminder', total: candidates.length, processed, failed }, 'reminder selesai');
  return { total: candidates.length, processed, failed };
};

/**
 * Job (d): Expire stale payment intents from payment gateway.
 */
const runExpireStaleIntents = async () => {
  const result = await expireStaleIntents();
  logger.info({ job: 'expireStaleIntents', result }, 'expireStaleIntents selesai');
  return result;
};

/**
 * Job (e): Clean up unreferenced orphan files older than 24 hours.
 */
const runCleanupOrphanFiles = async () => {
  const result = await cleanupOrphanFiles();
  logger.info({ job: 'cleanupOrphanFiles', result }, 'cleanupOrphanFiles selesai');
  return result;
};

/**
 * Job (f): Daily financial balance and escrow reconciliation audit.
 * Logs ERROR if any discrepancies are discovered.
 */
const runReconcileDaily = async () => {
  const auditResult = await reconcile();

  if (
    !auditResult.isReconciled ||
    auditResult.userDiscrepancies.length > 0 ||
    auditResult.escrowDiscrepancies.length > 0
  ) {
    const totalDiscrepancies =
      (auditResult.userDiscrepancies?.length || 0) +
      (auditResult.escrowDiscrepancies?.length || 0);
    metricsService.recordReconcileDiscrepancies(totalDiscrepancies);

    logger.error(
      {
        userDiscrepancies: auditResult.userDiscrepancies,
        escrowDiscrepancies: auditResult.escrowDiscrepancies,
      },
      'CRITICAL: DITEMUKAN SELISIH SALDO PADA AUDIT REKONSILIASI HARIAN!'
    );
  } else {
    metricsService.recordReconcileDiscrepancies(0);
    logger.info(
      { job: 'reconcileDaily', isReconciled: true },
      'reconcileDaily berhasil (100% konsisten)'
    );
  }

  return auditResult;
};

/**
 * Schedule cron jobs with advisory locking.
 *
 * @returns {Array<import('node-cron').ScheduledTask>}
 */
const startScheduler = () => {
  const accelerated = process.env.WORKER_ACCELERATED_INTERVAL === 'true';

  // Schedule definitions: accelerated (dev/test) vs production intervals
  const schedules = {
    autoRelease: accelerated ? '*/2 * * * * *' : '*/5 * * * *', // every 2s or 5m
    expirePending: accelerated ? '*/3 * * * * *' : '*/10 * * * *', // every 3s or 10m
    reminder: accelerated ? '*/2 * * * * *' : '*/15 * * * *', // every 2s or 15m
    expireStaleIntents: accelerated ? '*/5 * * * * *' : '*/10 * * * *', // every 5s or 10m
    cleanupOrphanFiles: accelerated ? '*/10 * * * * *' : '0 * * * *', // every 10s or 1h
    reconcileDaily: accelerated ? '*/15 * * * * *' : '0 0 * * *', // every 15s or daily at midnight
  };

  logger.info({ schedules, accelerated }, 'Memulai scheduler cron worker');

  const tasks = [
    cron.schedule(schedules.autoRelease, () =>
      withAdvisoryLock(JOB_LOCKS.AUTO_RELEASE, 'autoRelease', runAutoRelease)
    ),
    cron.schedule(schedules.expirePending, () =>
      withAdvisoryLock(JOB_LOCKS.EXPIRE_PENDING, 'expirePending', runExpirePending)
    ),
    cron.schedule(schedules.reminder, () =>
      withAdvisoryLock(JOB_LOCKS.REMINDER, 'reminder', runReminder)
    ),
    cron.schedule(schedules.expireStaleIntents, () =>
      withAdvisoryLock(JOB_LOCKS.EXPIRE_STALE_INTENTS, 'expireStaleIntents', runExpireStaleIntents)
    ),
    cron.schedule(schedules.cleanupOrphanFiles, () =>
      withAdvisoryLock(JOB_LOCKS.CLEANUP_ORPHAN_FILES, 'cleanupOrphanFiles', runCleanupOrphanFiles)
    ),
    cron.schedule(schedules.reconcileDaily, () =>
      withAdvisoryLock(JOB_LOCKS.RECONCILE_DAILY, 'reconcileDaily', runReconcileDaily)
    ),
  ];

  return tasks;
};

/**
 * Stops all running cron tasks.
 *
 * @param {Array<import('node-cron').ScheduledTask>} tasks
 */
const stopScheduler = (tasks = []) => {
  tasks.forEach((task) => {
    try {
      task.stop();
    } catch {
      // ignore
    }
  });
};

// If executed directly from command line (npm run worker)
if (require.main === module) {
  logger.info('Worker process dimulai secara terpisah.');
  const tasks = startScheduler();

  const shutdown = async () => {
    logger.info('Menerima sinyal terminasi, menghentikan scheduler...');
    stopScheduler(tasks);
    await prisma.$disconnect();
    logger.info('Worker berhasil dimatikan secara bersih.');
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

module.exports = {
  JOB_LOCKS,
  withAdvisoryLock,
  runAutoRelease,
  runExpirePending,
  runReminder,
  runExpireStaleIntents,
  runCleanupOrphanFiles,
  runReconcileDaily,
  startScheduler,
  stopScheduler,
};
