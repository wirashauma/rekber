const path = require('path');
const dotenv = require('dotenv');

// Load environment variables for test worker processes
dotenv.config({ path: path.resolve(__dirname, '../../.env.test') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

if (process.env.DATABASE_URL_TEST) {
  process.env.DATABASE_URL = process.env.DATABASE_URL_TEST;
}
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET =
  process.env.JWT_SECRET || 'test_jwt_secret_with_more_than_32_characters_for_unit_tests';
process.env.JWT_EXPIRES_IN = '1h';
process.env.BCRYPT_SALT_ROUNDS = '4';
process.env.PORT = '5001';
