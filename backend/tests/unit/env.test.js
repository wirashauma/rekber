const { spawnSync } = require('child_process');
const path = require('path');

describe('Unit Test: src/config/env.js', () => {
  const envScriptPath = path.resolve(__dirname, '../../src/config/env.js');

  const runWithEnv = (customEnv) => {
    // Run node with isolated environment (overriding process.env)
    return spawnSync(
      process.execPath,
      [
        '-e',
        `try { require('${envScriptPath.replace(/\\/g, '\\\\')}'); console.log('ENV_OK'); } catch(e) { process.exit(1); }`,
      ],
      {
        env: {
          PATH: process.env.PATH,
          SystemRoot: process.env.SystemRoot,
          ...customEnv,
        },
        encoding: 'utf-8',
      }
    );
  };

  test('Gagal dan berhenti jika DATABASE_URL tidak ada', () => {
    const res = runWithEnv({
      JWT_SECRET: 'a_very_secure_jwt_secret_with_32_characters_minimum',
      NODE_ENV: 'development',
      // DATABASE_URL omitted
    });

    expect(res.status).toBe(1);
    const output = (res.stdout || '') + (res.stderr || '');
    expect(output).toContain('DATABASE_URL wajib diisi.');
  });

  test('Gagal dan berhenti jika JWT_SECRET tidak ada', () => {
    const res = runWithEnv({
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/rekber_test?schema=public',
      NODE_ENV: 'development',
      // JWT_SECRET omitted
    });

    expect(res.status).toBe(1);
    const output = (res.stdout || '') + (res.stderr || '');
    expect(output).toContain('JWT_SECRET wajib diisi.');
  });

  test('Gagal dan berhenti jika JWT_SECRET kurang dari 32 karakter', () => {
    const res = runWithEnv({
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/rekber_test?schema=public',
      JWT_SECRET: 'short_secret_under_32',
      NODE_ENV: 'development',
    });

    expect(res.status).toBe(1);
    const output = (res.stdout || '') + (res.stderr || '');
    expect(output).toContain(
      'JWT_SECRET harus memiliki panjang minimal 32 karakter demi keamanan token.'
    );
  });

  test('Gagal dan berhenti jika NODE_ENV=production tetapi CORS_ORIGIN tidak ada', () => {
    const res = runWithEnv({
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/rekber_test?schema=public',
      JWT_SECRET: 'a_very_secure_jwt_secret_with_32_characters_minimum',
      NODE_ENV: 'production',
      // CORS_ORIGIN omitted
    });

    expect(res.status).toBe(1);
    const output = (res.stdout || '') + (res.stderr || '');
    expect(output).toContain('CORS_ORIGIN wajib diisi saat NODE_ENV bernilai "production".');
  });

  test('Sukses jika semua environment variable valid', () => {
    const res = runWithEnv({
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/rekber_test?schema=public',
      JWT_SECRET: 'a_very_secure_jwt_secret_with_32_characters_minimum',
      NODE_ENV: 'development',
      PORT: '5050',
    });

    expect(res.status).toBe(0);
    const output = (res.stdout || '') + (res.stderr || '');
    expect(output).toContain('ENV_OK');
  });
});
