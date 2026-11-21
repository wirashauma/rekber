// =============================================================================
// File Controller
// =============================================================================

const fs = require('fs');
const fileService = require('../services/file.service');
const { getStorageProvider, LocalStorageProvider } = require('../providers/storage');
const { ApiError } = require('../middlewares/error.middleware');

/**
 * POST /api/files
 * Multipart file upload with purpose specification.
 */
const uploadFile = async (req, res, next) => {
  try {
    const { purpose } = req.body;
    const fileProcessed = req.fileProcessed;

    const fileAsset = await fileService.createFileAsset(req.user.id, {
      purpose,
      fileProcessed,
    });

    res.status(201).json({
      success: true,
      message: 'Berkas berhasil diunggah.',
      data: {
        id: fileAsset.id,
        purpose: fileAsset.purpose,
        mime: fileAsset.mime,
        size: fileAsset.size,
        sha256: fileAsset.sha256,
        createdAt: fileAsset.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/files/:id/url
 * Retrieves short-lived signed download URL.
 */
const getFileSignedUrl = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await fileService.getFileSignedUrl(id, req.user, 300);

    res.status(200).json({
      success: true,
      message: 'URL unduhan berhasil dibuat.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/files/download/:key(*)
 * Serves locally stored files validated by HMAC signature and expiration.
 */
const downloadLocalFile = async (req, res, next) => {
  try {
    const rawKey = req.params[0] || req.params.key;
    const key = decodeURIComponent(rawKey);
    const { expires, signature } = req.query;

    const storage = getStorageProvider();
    if (!(storage instanceof LocalStorageProvider)) {
      throw new ApiError(400, 'Endpoint ini hanya melayani penyimpanan lokal.');
    }

    const isValid = storage.verifySignature({ key, expires, signature });
    if (!isValid) {
      const expTime = parseInt(expires, 10);
      if (!isNaN(expTime) && expTime < Math.floor(Date.now() / 1000)) {
        return res.status(403).json({
          success: false,
          message: 'URL unduhan telah kedaluwarsa.',
          code: 'URL_EXPIRED',
        });
      }
      return res.status(403).json({
        success: false,
        message: 'Tanda tangan URL tidak valid atau URL rusak.',
        code: 'INVALID_SIGNATURE',
      });
    }

    const filePath = storage.getFilePath(key);
    if (!fs.existsSync(filePath)) {
      throw new ApiError(404, 'Berkas fisik tidak ditemukan di penyimpanan.');
    }

    res.sendFile(filePath);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  uploadFile,
  getFileSignedUrl,
  downloadLocalFile,
};
