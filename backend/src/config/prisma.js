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
  // Use connection pool with minimum 20 connections for concurrency & finance testing
  const pool = new Pool({
    connectionString: config.databaseUrl,
    max: 25,
  });
  const adapter = new PrismaPg(pool);

  globalForPrisma.prisma = new PrismaClient({
    adapter,
    log: config.isDev ? ['warn', 'error'] : ['error'],
  });
}

const prisma = globalForPrisma.prisma;

module.exports = prisma;
