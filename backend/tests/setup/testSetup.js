const { resetDb, disconnectDb } = require('../helpers');

// Enforce test database validation in worker threads
const testDbUrl = process.env.DATABASE_URL_TEST;
if (!testDbUrl) {
  throw new Error('DATABASE_URL_TEST wajib diset dan nama database harus berakhiran _test.');
}

let dbName;
try {
  const url = new URL(testDbUrl);
  dbName = url.pathname.replace(/^\//, '').split('?')[0];
} catch (err) {
  throw new Error('DATABASE_URL_TEST bukan URL PostgreSQL yang valid.', { cause: err });
}

if (!dbName || !dbName.endsWith('_test')) {
  throw new Error(
    `DITOLAK: Database name "${dbName}" tidak berakhiran _test. Test hanya boleh dijalankan pada database test!`
  );
}

// Reset database state before each test case
beforeEach(async () => {
  await resetDb();
});

// Disconnect Prisma after all tests in the file complete
afterAll(async () => {
  await disconnectDb();
});
