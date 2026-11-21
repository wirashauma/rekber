module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  setupFiles: ['<rootDir>/tests/setup/envSetup.js'],
  setupFilesAfterEnv: ['<rootDir>/tests/setup/testSetup.js'],
  globalSetup: '<rootDir>/tests/setup/globalSetup.js',
  verbose: true,
  testTimeout: 15000,
  forceExit: false,
};
