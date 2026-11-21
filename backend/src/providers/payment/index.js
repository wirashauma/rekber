// =============================================================================
// Payment Provider Registry and Factory
// =============================================================================

const config = require('../../config');
const FakePaymentProvider = require('./fake.provider');
const XenditPaymentProvider = require('./xendit.provider');

const providers = {
  fake: new FakePaymentProvider(),
  xendit: new XenditPaymentProvider(),
};

/**
 * Retrieves a payment provider instance by name.
 *
 * @param {string} [name] - Provider identifier ('fake' or 'xendit')
 * @returns {import('./payment.interface')}
 */
const getPaymentProvider = (name) => {
  const normalized = (name || config.payment.provider || 'fake').toLowerCase();
  const provider = providers[normalized];
  if (!provider) {
    throw new Error(`Penyedia pembayaran "${name}" tidak dikenal atau belum didukung.`);
  }
  return provider;
};

// Default provider instance configured via environment
const defaultProvider = getPaymentProvider();

module.exports = defaultProvider;
module.exports.getPaymentProvider = getPaymentProvider;
module.exports.FakePaymentProvider = FakePaymentProvider;
module.exports.XenditPaymentProvider = XenditPaymentProvider;
