// =============================================================================
// REKBER Backend - Server Entry Point
// =============================================================================
// Starts the Express server and connects to the database.
// Handles graceful shutdown on SIGTERM and SIGINT:
// - Stops accepting new HTTP connections
// - Closes Socket.IO connections
// - Stops active cron scheduler jobs
// - Disconnects Prisma client cleanly

const http = require('http');
const app = require('./app');
const config = require('./config');
const prisma = require('./config/prisma');
const { initSocket, closeSocket } = require('./socket');
const { logger } = require('./config/logger');

let httpServer = null;
let scheduledTasks = null;
let isShuttingDown = false;

// =============================================================================
// START SERVER
// =============================================================================

const startServer = async () => {
  try {
    // 1. Verify database connection
    await prisma.$connect();
    logger.info('Database connected successfully');

    // 2. Create HTTP server and initialize Socket.IO
    httpServer = http.createServer(app);
    initSocket(httpServer);

    // 3. Start listening for requests
    httpServer.listen(config.port, () => {
      logger.info(
        {
          port: config.port,
          environment: config.nodeEnv,
          url: `http://localhost:${config.port}`,
        },
        'Rekber API Server is running'
      );

      // 4. Optionally start background worker scheduler inside API process
      if (process.env.RUN_JOBS_IN_API === 'true') {
        const { startScheduler } = require('./worker');
        scheduledTasks = startScheduler();
        logger.info('In-API Cron Scheduler started (RUN_JOBS_IN_API=true)');
      }
    });
  } catch (error) {
    logger.error({ error: error.message }, 'Failed to start server');
    process.exit(1);
  }
};

// =============================================================================
// GRACEFUL SHUTDOWN
// =============================================================================

const gracefulShutdown = async (signal) => {
  if (isShuttingDown) return;
  isShuttingDown = true;

  logger.info({ signal }, 'Menerima sinyal terminasi. Memulai graceful shutdown...');

  // 1. Stop background scheduler jobs if running
  if (scheduledTasks) {
    try {
      const { stopScheduler } = require('./worker');
      stopScheduler(scheduledTasks);
      logger.info('Background scheduler jobs successfully stopped');
    } catch (err) {
      logger.warn({ error: err.message }, 'Error stopping scheduler');
    }
  }

  // 2. Close HTTP server (stop accepting new requests, finish ongoing ones)
  if (httpServer) {
    try {
      await new Promise((resolve) => {
        httpServer.close((err) => {
          if (err) {
            logger.warn({ error: err.message }, 'Error closing HTTP server');
          }
          resolve();
        });
      });
      logger.info('HTTP server closed');
    } catch (err) {
      logger.warn({ error: err.message }, 'Error closing HTTP server');
    }
  }

  // 3. Close Socket.IO connections
  try {
    await closeSocket();
    logger.info('Socket.IO connections closed');
  } catch (err) {
    logger.warn({ error: err.message }, 'Error closing Socket.IO');
  }

  // 4. Disconnect Prisma DB client
  try {
    await prisma.$disconnect();
    logger.info('Database disconnected cleanly');
  } catch (err) {
    logger.warn({ error: err.message }, 'Error disconnecting Prisma');
  }

  logger.info('Graceful shutdown selesai. Proses keluar.');
  process.exit(0);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Start the server if executed directly
if (require.main === module) {
  startServer();
}

module.exports = {
  startServer,
  gracefulShutdown,
};
