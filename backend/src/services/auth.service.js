// =============================================================================
// Auth Service
// =============================================================================
// Handles all business logic for authentication: registration & login.
// This layer is independent of Express (req/res) — it only deals with
// data and throws ApiError for the controller/middleware to handle.

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');
const config = require('../config');
const { ApiError } = require('../middlewares/error.middleware');

/**
 * Register a new user.
 *
 * Steps:
 *   1. Check if email is already registered.
 *   2. Hash the password with bcrypt.
 *   3. Create the user in the database.
 *   4. Return the user data (excluding password).
 *
 * @param {Object} data - { name, email, password }
 * @returns {Object} Created user (without password)
 */
const register = async ({ name, email, password }) => {
  // 1. Check for existing user with the same email
  const existingUser = await prisma.user.findUnique({ where: { email } });

  if (existingUser) {
    throw new ApiError(409, 'Email sudah terdaftar. Gunakan email lain.'); // Email already registered.
  }

  // 2. Hash the password
  const hashedPassword = await bcrypt.hash(password, config.bcrypt.saltRounds);

  // 3. Create the user in the database
  const user = await prisma.user.create({
    data: {
      name,
      email,
      password: hashedPassword,
    },
    // Select only non-sensitive fields to return
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      balance: true,
      createdAt: true,
    },
  });

  return user;
};

/**
 * Login an existing user.
 *
 * Steps:
 *   1. Find the user by email.
 *   2. Compare the provided password with the stored hash.
 *   3. Generate a JWT token.
 *   4. Return the token and user data.
 *
 * @param {Object} data - { email, password }
 * @returns {Object} { token, user }
 */
const login = async ({ email, password }) => {
  // 1. Find user by email
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user) {
    throw new ApiError(401, 'Email atau password salah.'); // Invalid credentials.
  }

  // 2. Compare passwords
  const isPasswordValid = await bcrypt.compare(password, user.password);

  if (!isPasswordValid) {
    throw new ApiError(401, 'Email atau password salah.'); // Invalid credentials.
  }

  // 3. Generate JWT with user payload
  const tokenPayload = {
    id: user.id,
    email: user.email,
    role: user.role,
  };

  const token = jwt.sign(tokenPayload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });

  // 4. Return token and sanitized user object
  const { password: _, ...userWithoutPassword } = user;

  return {
    token,
    user: userWithoutPassword,
  };
};

module.exports = { register, login };
