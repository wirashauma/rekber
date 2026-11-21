// =============================================================================
// File Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth.middleware');
const { uploadAndSanitize } = require('../middlewares/upload.middleware');
const fileController = require('../controllers/file.controller');

/**
 * GET /api/files/download/{*key}
 * Serves local files validated by HMAC signature and expiration timestamp.
 * Authenticated via signed URL parameters (no Bearer token needed for static asset rendering).
 */
router.get('/download/{*key}', fileController.downloadLocalFile);

/**
 * POST /api/files
 * Uploads an image with specified purpose, strips EXIF, and saves FileAsset.
 */
router.post('/', authenticate, uploadAndSanitize, fileController.uploadFile);

/**
 * GET /api/files/:id/url
 * Returns short-lived signed URL if user satisfies file access policy.
 */
router.get('/:id/url', authenticate, fileController.getFileSignedUrl);

module.exports = router;
