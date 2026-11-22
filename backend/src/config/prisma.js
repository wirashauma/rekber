// =============================================================================
// Prisma Client Singleton (with pg Driver Adapter)
// =============================================================================
// Creates and exports a single Prisma Client instance for the entire app.
// Uses @prisma/adapter-pg to connect directly to PostgreSQL.
//
// Prisma v7 uses a "client" engine by default, which requires a driver adapter
// for direct database connections (as opposed to Prisma Accelerate).

const { Pool } = require('pg');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const config = require('./index');

// Use a global variable to preserve the Prisma Client across hot reloads
// in development mode. In production, a new instance is always created.
const globalForPrisma = globalThis;

if (!globalForPrisma.prisma) {
  // Connection pool with configurable limits and timeouts via environment variables
  const poolMax = parseInt(process.env.DB_POOL_MAX || '25', 10);
  const poolMin = parseInt(process.env.DB_POOL_MIN || '5', 10);
  const idleTimeoutMillis = parseInt(process.env.DB_IDLE_TIMEOUT_MS || '30000', 10);
  const connectionTimeoutMillis = parseInt(process.env.DB_CONNECTION_TIMEOUT_MS || '5000', 10);

  const pool = new Pool({
    connectionString: config.databaseUrl,
    max: poolMax,
    min: poolMin,
    idleTimeoutMillis,
    connectionTimeoutMillis,
  });

  const adapter = new PrismaPg(pool);

  globalForPrisma.prisma = new PrismaClient({
    adapter,
    log: config.isDev ? ['warn', 'error'] : ['error'],
  });
}

const prisma = globalForPrisma.prisma;

module.exports = prisma;
