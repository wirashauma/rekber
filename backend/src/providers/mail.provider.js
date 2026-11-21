// =============================================================================
// Mail Provider Abstraction
// =============================================================================
// Provides email sending capabilities. In production, uses SMTP via nodemailer.
// In development and test environments, logs messages or saves them in-memory
// for test inspection without sending actual network requests.

const nodemailer = require('nodemailer');
const config = require('../config');

// In-memory inbox for testing assertions
const testInbox = [];

let transporter = null;

if (process.env.SMTP_HOST && !config.isTest) {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT, 10) || 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

/**
 * Sends a password reset email containing the reset token.
 *
 * @param {string} to - Recipient email address
 * @param {string} token - 32-byte plain reset token
 */
const sendPasswordResetEmail = async (to, token) => {
  const subject = 'Instruksi Reset Password Akun Rekber';
  const text = `Halo,\n\nAnda meminta reset password untuk akun Rekber Anda. Gunakan token berikut untuk mengatur ulang password Anda:\n\n${token}\n\nToken ini hanya berlaku selama 30 menit. Jika Anda tidak merasa meminta ini, abaikan email ini.\n\nTim Rekber`;

  if (config.isTest) {
    testInbox.push({ to, token, subject, text, sentAt: new Date() });
    return true;
  }

  if (transporter) {
    try {
      await transporter.sendMail({
        from: process.env.SMTP_FROM || 'Rekber <no-reply@rekber.com>',
        to,
        subject,
        text,
      });
      return true;
    } catch (err) {
      console.error('Gagal mengirim email reset password via SMTP:', err.message);
      return false;
    }
  }

  // Development fallback: log to console
  console.log('='.repeat(60));
  console.log('📧 [MOCK EMAIL] Password Reset Email');
  console.log(`To     : ${to}`);
  console.log(`Subject: ${subject}`);
  console.log(`Token  : ${token}`);
  console.log('='.repeat(60));
  return true;
};

const getTestInbox = () => testInbox;
const clearTestInbox = () => {
  testInbox.length = 0;
};

module.exports = {
  sendPasswordResetEmail,
  getTestInbox,
  clearTestInbox,
};
