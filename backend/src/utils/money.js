// =============================================================================
// Money & Fee Calculation Utilities
// =============================================================================
// Handles safe BigInt conversions, validation, fee calculation with ceiling,
// and ensures BigInt values serialize properly in JSON responses.

// Enable BigInt JSON serialization automatically
if (!BigInt.prototype.toJSON) {
  BigInt.prototype.toJSON = function () {
    const num = Number(this);
    return Number.isSafeInteger(num) ? num : this.toString();
  };
}

const MAX_SAFE_INTEGER_BIGINT = BigInt(Number.MAX_SAFE_INTEGER);

/**
 * Safely converts BigInt, string, or number to JavaScript Number.
 * Throws RangeError if value exceeds Number.MAX_SAFE_INTEGER.
 *
 * @param {bigint|number|string} val
 * @returns {number}
 */
const toSafeNumber = (val) => {
  if (val === null || val === undefined) {
    return 0;
  }

  if (typeof val === 'bigint') {
    if (val > MAX_SAFE_INTEGER_BIGINT || val < -MAX_SAFE_INTEGER_BIGINT) {
      throw new RangeError('Nilai BigInt melebihi batas aman MAX_SAFE_INTEGER.');
    }
    return Number(val);
  }

  const num = Number(val);
  if (!Number.isSafeInteger(num)) {
    throw new RangeError('Nilai melebihi batas aman safe integer.');
  }
  return num;
};

/**
 * Parses input to BigInt strictly.
 * Rejects floats/decimals, negative values (unless allowed), NaN, and non-numeric inputs.
 *
 * @param {any} val
 * @param {Object} options - { allowNegative: false, min: null, max: null }
 * @returns {bigint}
 */
const parseInteger = (val, options = {}) => {
  const { allowNegative = false, min = null, max = null } = options;

  if (val === null || val === undefined || typeof val === 'boolean' || val === '') {
    throw new TypeError('Input jumlah uang tidak valid.');
  }

  if (typeof val === 'number') {
    if (!Number.isFinite(val) || !Number.isInteger(val)) {
      throw new TypeError('Jumlah uang harus berupa bilangan bulat (tanpa desimal).');
    }
  }

  let bi;
  try {
    const str = String(val).trim();
    if (str.includes('.') || str.includes(',')) {
      throw new TypeError('Jumlah uang harus berupa bilangan bulat (tanpa desimal).');
    }
    bi = BigInt(str);
  } catch (err) {
    if (err instanceof TypeError) throw err;
    throw new TypeError('Format bilangan uang tidak valid.', { cause: err });
  }

  if (!allowNegative && bi < 0n) {
    throw new RangeError('Jumlah uang tidak boleh bernilai negatif.');
  }

  if (min !== null && bi < BigInt(min)) {
    throw new RangeError(`Jumlah uang minimal Rp ${Number(min).toLocaleString('id-ID')}.`);
  }

  if (max !== null && bi > BigInt(max)) {
    throw new RangeError(
      `Jumlah uang melebihi batas maksimal Rp ${Number(max).toLocaleString('id-ID')}.`
    );
  }

  if (bi > MAX_SAFE_INTEGER_BIGINT) {
    throw new RangeError('Nilai uang melebihi batas aman sistem (MAX_SAFE_INTEGER).');
  }

  return bi;
};

/**
 * Calculates platform fee with ceiling (pembulatan ke atas) and splits it.
 *
 * Fee Payer Options:
 *   - 'BUYER': buyer pays 100% of totalFee, seller pays 0.
 *   - 'SELLER': seller pays 100% of totalFee, buyer pays 0.
 *   - 'SPLIT': split 50/50 with ceiling for buyer if odd.
 *
 * @param {Object} params - { amount, feePercent, feeMin, feePayer }
 * @returns {Object} { totalFee: bigint, buyerFee: bigint, sellerFee: bigint }
 */
const calculateFee = ({ amount, feePercent = 2, feeMin = 1000, feePayer = 'SPLIT' } = {}) => {
  const amt = parseInteger(amount, { min: 0 });
  const minFee = parseInteger(feeMin, { min: 0 });
  const percent = Number(feePercent);

  if (isNaN(percent) || percent < 0) {
    throw new RangeError('Persentase fee tidak valid.');
  }

  // Ceiling calculation: ceil(amount * percent / 100)
  const calculated = Math.ceil(toSafeNumber(amt) * (percent / 100));
  let totalFee = BigInt(calculated);
  if (totalFee < minFee) {
    totalFee = minFee;
  }

  let buyerFee;
  let sellerFee;

  const payer = (feePayer || 'SPLIT').toUpperCase();
  switch (payer) {
    case 'BUYER':
      buyerFee = totalFee;
      sellerFee = 0n;
      break;
    case 'SELLER':
      buyerFee = 0n;
      sellerFee = totalFee;
      break;
    case 'SPLIT':
    default:
      // Half rounded up to buyer, rest to seller
      buyerFee = (totalFee + 1n) / 2n;
      sellerFee = totalFee - buyerFee;
      break;
  }

  return {
    totalFee,
    buyerFee,
    sellerFee,
  };
};

module.exports = {
  toSafeNumber,
  parseInteger,
  calculateFee,
  MAX_SAFE_INTEGER_BIGINT,
};
