// =============================================================================
// Prisma Client Singleton (with pg Driver Adapter)
// =============================================================================
// Creates and exports a single Prisma Client instance for the entire app.
// Uses @prisma/adapter-pg to connect directly to PostgreSQL.
//
// Prisma v7 uses a "client" engine by default, which requires a driver adapter
// for direct database connections (as opposed to Prisma Accelerate).

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

require('dotenv').config();

// Use a global variable to preserve the Prisma Client across hot reloads
// in development mode. In production, a new instance is always created.
const globalForPrisma = globalThis;

if (!globalForPrisma.prisma) {
  // Create the PostgreSQL adapter with the connection string
  const adapter = new PrismaPg(process.env.DATABASE_URL);

  globalForPrisma.prisma = new PrismaClient({
    adapter,
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });
}

const prisma = globalForPrisma.prisma;

module.exports = prisma;
