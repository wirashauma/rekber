// =============================================================================
// REKBER Backend - Server Entry Point
// =============================================================================
// Starts the Express server and connects to the database.
// Separated from app.js for testing purposes (you can import app without
// starting the server).

const app = require('./app');
const config = require('./config');
const prisma = require('./config/prisma');

// =============================================================================
// START SERVER
// =============================================================================

const startServer = async () => {
  try {
    // 1. Verify database connection
    await prisma.$connect();
    console.log('✅ Database connected successfully');

    // 2. Start listening for requests
    app.listen(config.port, () => {
      console.log('='.repeat(60));
      console.log(`🚀 Rekber API Server is running!`);
      console.log(`📡 Environment : ${config.nodeEnv}`);
      console.log(`🌐 URL         : http://localhost:${config.port}`);
      console.log(`❤️  Health      : http://localhost:${config.port}/api/health`);
      console.log('='.repeat(60));
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error.message);
    process.exit(1);
  }
};

// =============================================================================
// GRACEFUL SHUTDOWN
// =============================================================================
// Ensures database connections are properly closed when the server stops.

const gracefulShutdown = async (signal) => {
  console.log(`\n🛑 Received ${signal}. Shutting down gracefully...`);
  await prisma.$disconnect();
  console.log('✅ Database disconnected');
  process.exit(0);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Start the server
startServer();
