// =============================================================================
// Admin Platform Settings Controller
// =============================================================================

const settingsService = require('../services/settings.service');
const auditService = require('../services/audit.service');
const { ApiError } = require('../middlewares/error.middleware');

const VALID_SETTING_KEYS = [
  'fee_percent',
  'fee_min',
  'fee_payer_default',
  'auto_release_hours',
  'pending_expire_hours',
  'withdraw_min',
  'withdraw_fee',
  'withdraw_daily_limit',
  'max_transaction_amount',
  'maintenance_mode',
];

/**
 * Validates setting key, data type, and logical business range.
 */
const validateSetting = (key, value) => {
  if (!VALID_SETTING_KEYS.includes(key)) {
    throw new ApiError(400, `Kunci pengaturan '${key}' tidak diizinkan atau tidak valid.`);
  }

  const strVal = String(value).trim();

  switch (key) {
    case 'fee_percent': {
      const num = parseFloat(strVal);
      if (isNaN(num) || num < 0 || num > 50) {
        throw new ApiError(422, 'fee_percent harus berupa angka persentase antara 0 dan 50.');
      }
      return strVal;
    }
    case 'fee_min':
    case 'withdraw_fee': {
      const num = parseInt(strVal, 10);
      if (isNaN(num) || num < 0) {
        throw new ApiError(422, `${key} harus berupa bilangan bulat non-negatif.`);
      }
      return strVal;
    }
    case 'fee_payer_default': {
      if (!['BUYER', 'SELLER', 'SPLIT'].includes(strVal.toUpperCase())) {
        throw new ApiError(422, 'fee_payer_default harus bernilai BUYER, SELLER, atau SPLIT.');
      }
      return strVal.toUpperCase();
    }
    case 'auto_release_hours': {
      const num = parseInt(strVal, 10);
      if (isNaN(num) || num < 1 || num > 720) {
        throw new ApiError(422, 'auto_release_hours harus berupa jam antara 1 dan 720 (30 hari).');
      }
      return strVal;
    }
    case 'pending_expire_hours': {
      const num = parseInt(strVal, 10);
      if (isNaN(num) || num < 1 || num > 168) {
        throw new ApiError(422, 'pending_expire_hours harus berupa jam antara 1 dan 168 (7 hari).');
      }
      return strVal;
    }
    case 'withdraw_min':
    case 'withdraw_daily_limit':
    case 'max_transaction_amount': {
      const num = parseInt(strVal, 10);
      if (isNaN(num) || num < 10000) {
        throw new ApiError(422, `${key} harus berupa nominal rupiah minimal 10.000.`);
      }
      return strVal;
    }
    case 'maintenance_mode': {
      if (!['true', 'false'].includes(strVal.toLowerCase())) {
        throw new ApiError(422, 'maintenance_mode harus bernilai true atau false.');
      }
      return strVal.toLowerCase();
    }
    default:
      return strVal;
  }
};

/**
 * GET /admin/settings
 * Retrieves all runtime platform settings.
 */
const getSettings = async (req, res, next) => {
  try {
    const settings = await settingsService.getAll();

    res.status(200).json({
      success: true,
      data: settings,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /admin/settings
 * Updates platform setting(s) with strict validation and audit log.
 */
const updateSettings = async (req, res, next) => {
  try {
    const currentSettings = await settingsService.getAll();
    let updates = [];

    if (req.body.settings && Array.isArray(req.body.settings)) {
      updates = req.body.settings;
    } else if (req.body.key !== undefined && req.body.value !== undefined) {
      updates = [{ key: req.body.key, value: req.body.value }];
    } else {
      throw new ApiError(
        422,
        'Format request tidak valid. Sertakan { key, value } atau { settings: [...] }.'
      );
    }

    const updatedResults = {};

    for (const item of updates) {
      const validVal = validateSetting(item.key, item.value);
      const prevVal = currentSettings[item.key];

      await settingsService.set(item.key, validVal, req.user.id);
      updatedResults[item.key] = validVal;

      // Record audit log for each setting changed
      await auditService.log({
        actorId: req.user.id,
        action: 'SETTING_UPDATE',
        targetType: 'PLATFORM_SETTING',
        targetId: item.key,
        before: { key: item.key, value: prevVal },
        after: { key: item.key, value: validVal },
        ip: req.ip,
      });
    }

    res.status(200).json({
      success: true,
      message: 'Pengaturan platform berhasil diperbarui.',
      data: updatedResults,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getSettings,
  updateSettings,
};
