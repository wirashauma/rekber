const path = require('path');
const { execSync } = require('child_process');
const dotenv = require('dotenv');

module.exports = async () => {
  dotenv.config({ path: path.resolve(__dirname, '../../.env.test') });
  dotenv.config({ path: path.resolve(__dirname, '../../.env') });

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

  // Run migrations against test database
  try {
    execSync('npx prisma migrate deploy', {
      cwd: path.resolve(__dirname, '../../'),
      stdio: 'pipe',
      env: {
        ...process.env,
        DATABASE_URL: testDbUrl,
      },
    });
  } catch (error) {
    console.error('Gagal menjalankan migrasi pada test database:', error.message);
    throw error;
  }
};
