// =============================================================================
// Platform Settings Service
// =============================================================================
// Provides cached access to platform configuration settings with typed getters.
// In-memory cache TTL: 30 seconds. Automatically invalidated on `set()`.

const prisma = require('../config/prisma');

const CACHE_TTL_MS = 30 * 1000;

const cache = new Map();
let cacheExpiresAt = 0;

const DEFAULTS = {
  fee_percent: '2',
  fee_min: '1000',
  fee_payer_default: 'SPLIT',
  auto_release_hours: '72',
  pending_expire_hours: '24',
  withdraw_min: '50000',
  withdraw_fee: '0',
  withdraw_daily_limit: '10000000',
  max_transaction_amount: '5000000',
  maintenance_mode: 'false',
};

/**
 * Invalidate internal settings cache.
 */
const clearCache = () => {
  cache.clear();
  cacheExpiresAt = 0;
};

/**
 * Load all settings into cache if expired or empty.
 * Returns map of all settings merged with defaults.
 */
const getAll = async () => {
  const now = Date.now();
  if (cache.size > 0 && now < cacheExpiresAt) {
    return Object.fromEntries(cache);
  }

  const rows = await prisma.platformSetting.findMany();
  cache.clear();

  // Seed cache with defaults
  for (const [k, v] of Object.entries(DEFAULTS)) {
    cache.set(k, v);
  }

  // Override with database values
  for (const row of rows) {
    cache.set(row.key, row.value);
  }

  cacheExpiresAt = now + CACHE_TTL_MS;
  return Object.fromEntries(cache);
};

/**
 * Get raw string value of a setting.
 */
const get = async (key, defaultValue = null) => {
  const all = await getAll();
  if (all[key] !== undefined) {
    return all[key];
  }
  return defaultValue !== null ? defaultValue : (DEFAULTS[key] ?? null);
};

/**
 * Get setting as Number.
 */
const getNumber = async (key, defaultValue = null) => {
  const val = await get(key, defaultValue);
  const parsed = Number(val);
  return isNaN(parsed) ? (defaultValue !== null ? defaultValue : 0) : parsed;
};

/**
 * Get setting as Boolean.
 */
const getBoolean = async (key, defaultValue = null) => {
  const val = await get(key, defaultValue);
  if (typeof val === 'boolean') return val;
  const str = String(val).trim().toLowerCase();
  return str === 'true' || str === '1';
};

/**
 * Get setting as String.
 */
const getString = async (key, defaultValue = '') => {
  const val = await get(key, defaultValue);
  return val !== null && val !== undefined ? String(val) : defaultValue;
};

/**
 * Upsert setting in database and invalidate cache.
 */
const set = async (key, value, updatedById = null) => {
  const stringValue = String(value);

  const updated = await prisma.platformSetting.upsert({
    where: { key },
    update: {
      value: stringValue,
      updatedById,
    },
    create: {
      key,
      value: stringValue,
      updatedById,
    },
  });

  clearCache();
  return updated;
};

module.exports = {
  get,
  getAll,
  getNumber,
  getBoolean,
  getString,
  set,
  clearCache,
  DEFAULTS,
  CACHE_TTL_MS,
};
