// =============================================================================
// Upload & Image Sanitization Middleware
// =============================================================================
// Validates magic bytes, re-encodes images with sharp (stripping EXIF metadata &
// constraining dimensions), and generates secure random storage keys.

const multer = require('multer');
const sharp = require('sharp');
const crypto = require('crypto');
const { ApiError } = require('./error.middleware');

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5 MB
const MAX_DIMENSION = 2560; // 2560px max width/height

/**
 * Validates magic bytes from file buffer to determine true MIME type.
 *
 * @param {Buffer} buffer
 * @returns {'image/jpeg'|'image/png'|'image/webp'|null}
 */
const detectMagicBytes = (buffer) => {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length < 12) {
    return null;
  }

  // 1. JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return 'image/jpeg';
  }

  // 2. PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return 'image/png';
  }

  // 3. WebP: RIFF (bytes 0-3) and WEBP (bytes 8-11)
  if (
    buffer[0] === 0x52 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x46 &&
    buffer[8] === 0x57 &&
    buffer[9] === 0x45 &&
    buffer[10] === 0x42 &&
    buffer[11] === 0x50
  ) {
    return 'image/webp';
  }

  return null;
};

// Multer memory storage configuration
const multerUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: MAX_FILE_SIZE,
  },
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];
    if (!allowed.includes(file.mimetype.toLowerCase())) {
      return cb(
        new ApiError(400, 'Format berkas tidak didukung. Hanya JPG, PNG, dan WebP yang diizinkan.')
      );
    }
    cb(null, true);
  },
}).single('file');

/**
 * Middleware: Wraps multer and executes deep magic bytes inspection and sharp sanitization.
 */
const uploadAndSanitize = (req, res, next) => {
  multerUpload(req, res, async (err) => {
    if (err) {
      if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
          return next(new ApiError(400, 'Ukuran berkas melebihi batas maksimal 5 MB.'));
        }
        return next(new ApiError(400, `Kesalahan unggah berkas: ${err.message}`));
      }
      return next(err);
    }

    if (!req.file || !req.file.buffer) {
      return next(new ApiError(400, 'Berkas wajib diunggah (field "file").'));
    }

    const detectedMime = detectMagicBytes(req.file.buffer);
    if (!detectedMime) {
      return next(
        new ApiError(
          400,
          'Format berkas tidak valid atau isi berkas tidak cocok dengan format gambar yang diizinkan (Magic Bytes mismatch).'
        )
      );
    }

    try {
      // Re-encode with sharp:
      // - auto-orient based on EXIF rotation
      // - do NOT call .withMetadata() => EXIF metadata is completely stripped
      // - constrain dimensions to max 2560px
      const image = sharp(req.file.buffer).rotate();

      let pipeline = image.resize({
        width: MAX_DIMENSION,
        height: MAX_DIMENSION,
        fit: 'inside',
        withoutEnlargement: true,
      });

      let processedBuffer;
      let ext;

      if (detectedMime === 'image/jpeg') {
        processedBuffer = await pipeline.jpeg({ quality: 85 }).toBuffer();
        ext = 'jpg';
      } else if (detectedMime === 'image/png') {
        processedBuffer = await pipeline.png({ compressionLevel: 8 }).toBuffer();
        ext = 'png';
      } else {
        processedBuffer = await pipeline.webp({ quality: 85 }).toBuffer();
        ext = 'webp';
      }

      // SHA-256 integrity hash of processed image
      const sha256 = crypto.createHash('sha256').update(processedBuffer).digest('hex');

      // Random filename and storage key
      const purpose = (req.body.purpose || 'misc').toLowerCase();
      const randomHex = crypto.randomBytes(16).toString('hex');
      const storageKey = `${purpose}/${Date.now()}_${randomHex}.${ext}`;

      req.fileProcessed = {
        buffer: processedBuffer,
        mime: detectedMime,
        size: processedBuffer.length,
        sha256,
        storageKey,
      };

      next();
    } catch (sharpErr) {
      return next(new ApiError(400, `Gagal memproses gambar: ${sharpErr.message}`));
    }
  });
};

module.exports = {
  uploadAndSanitize,
  detectMagicBytes,
};
